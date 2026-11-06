class_name TurnProcedure
extends RefCounted
## Turns, steps and priority from the first turn on (CR 500, CR 117).

enum Stage { START_TURN, START_STEP, TURN_BASED_ACTIONS, AWAIT_DISCARD, PRIORITY, END_STEP }

var _state: MmGameState
var _stage: Stage = Stage.START_TURN
## This turn's steps, after any skipped for the whole turn.
var _steps: Array[MmTurn.Step] = []
var _step_index: int = 0
var _priority_player_id: int = MmGameState.NO_PLAYER
var _passes_in_succession: int = 0
var _attackers_declared: bool = false


func _init(state: MmGameState) -> void:
	_state = state


## Runs every automatic step until a player must decide, and returns that decision.
## A turn always leads to another, so this never returns null.
func next_decision() -> MmPendingDecision:
	while true:
		match _stage:
			Stage.START_TURN:
				_start_turn()
			Stage.START_STEP:
				_state.perform(StepStartedEvent.new(_current_step()))
				_stage = Stage.TURN_BASED_ACTIONS
			Stage.TURN_BASED_ACTIONS:
				var decision: MmPendingDecision = _perform_turn_based_actions()
				if decision != null:
					_stage = Stage.AWAIT_DISCARD
					return decision
				_begin_priority_or_end_step()
			Stage.AWAIT_DISCARD:
				assert(false, "The discard decision has not been answered.")
				return null
			Stage.PRIORITY:
				return PriorityDecision.new(_priority_player_id, _legal_actions(_priority_player_id))
			Stage.END_STEP:
				_end_step()
	return null


## Applies an already-validated [param answer] to [param decision].
func apply_answer(decision: MmPendingDecision, answer: Variant) -> void:
	if decision is PriorityDecision:
		var index: int = answer
		var action: MmAction = (decision as PriorityDecision).actions[index]
		if action is PassAction:
			_pass_priority()
		elif action is PlayLandAction:
			_play_land(action as PlayLandAction)
		elif action is ActivateAbilityAction:
			_activate_mana_ability(action as ActivateAbilityAction)
		else:
			assert(false, "Unknown action: %s" % action.describe())
	elif decision is ChooseCardsToDiscardDecision:
		var discarding: MmPlayer = _state.player(decision.player_id)
		for id: int in answer:
			_state.perform(ZoneChangeEvent.new(_state.object(id), discarding.graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.DISCARD))
		_begin_priority_or_end_step()
	else:
		assert(false, "The turn procedure cannot answer %s." % decision.describe())


func _start_turn() -> void:
	var next_active_id: int = _state.starting_player_id
	if _state.game_turn > 0:
		next_active_id = _state.opponent_of(_state.active_player_id).id
	_state.perform(TurnStartedEvent.new(next_active_id))
	_steps = MmTurn.STEPS.duplicate()
	if _state.game_turn == 1:
		# CR 103.8a: in a two-player game the starting player skips their first draw step.
		_steps.erase(MmTurn.Step.DRAW)
	_step_index = 0
	_attackers_declared = false
	_stage = Stage.START_STEP


## Performs the current step's turn-based actions (CR 703). Returns a decision when one of
## them needs a player's choice.
func _perform_turn_based_actions() -> MmPendingDecision:
	var active: MmPlayer = _state.player(_state.active_player_id)
	match _current_step():
		MmTurn.Step.UNTAP:
			# CR 502.3: the active player untaps all their permanents.
			for permanent: MmGameObject in _state.battlefield.objects():
				if permanent.controller_id == active.id and permanent.is_tapped:
					_state.perform(UntapEvent.new(permanent.id))
		MmTurn.Step.DRAW:
			_state.draw_cards(active.id, 1)  # CR 504.1
		MmTurn.Step.DECLARE_ATTACKERS:
			# Later (milestone 6): the active player declares attackers (CR 508.1).
			_attackers_declared = false
		MmTurn.Step.CLEANUP:
			var excess: int = active.cards_over_maximum_hand_size()
			if excess > 0:
				return ChooseCardsToDiscardDecision.new(active.id, excess, active.hand.object_ids())  # CR 514.1
	return null


func _begin_priority_or_end_step() -> void:
	if MmTurn.grants_priority(_current_step()):
		# CR 117.3a: the active player receives priority first in each step.
		_priority_player_id = _state.active_player_id
		_passes_in_succession = 0
		_stage = Stage.PRIORITY
	else:
		_stage = Stage.END_STEP


## CR 117.3d and 117.4: priority passes to the next player; once every player has passed
## in succession with an empty stack, the step ends.
func _pass_priority() -> void:
	_passes_in_succession += 1
	if _passes_in_succession >= _state.players.size() and _state.stack.is_empty():
		_priority_player_id = MmGameState.NO_PLAYER
		_stage = Stage.END_STEP
	else:
		_priority_player_id = _state.opponent_of(_priority_player_id).id


func _end_step() -> void:
	# CR 500.4: unspent mana empties from each pool at the end of each step and phase.
	for player: MmPlayer in _state.turn_order():
		if not player.mana_pool().is_empty():
			_state.perform(ManaEmptiedEvent.new(player.id))
	_step_index += 1
	if not _attackers_declared:
		# CR 508.8: without attackers, the declare blockers and combat damage steps are skipped.
		while _step_index < _steps.size() and _current_step() in [MmTurn.Step.DECLARE_BLOCKERS, MmTurn.Step.COMBAT_DAMAGE]:
			_step_index += 1
	_stage = Stage.START_TURN if _step_index >= _steps.size() else Stage.START_STEP


func _current_step() -> MmTurn.Step:
	return _steps[_step_index]


## The actions [param player_id] may take while holding priority, in a deterministic order
## (ADR 0012): Pass, then land plays by object ID, then abilities by object ID and order.
func _legal_actions(player_id: int) -> Array[MmAction]:
	# Later (milestone 5): casting spells and activating abilities that use the stack.
	var actions: Array[MmAction] = [PassAction.new()]
	var player: MmPlayer = _state.player(player_id)
	if _may_play_land(player):
		for card: MmGameObject in _sorted_by_id(player.hand.objects()):
			if _state.characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND):
				actions.append(PlayLandAction.new(card.id))
	for permanent: MmGameObject in _sorted_by_id(_state.battlefield.objects()):
		if permanent.controller_id != player_id:
			continue
		var abilities: Array[MmAbility] = _state.characteristics_of(permanent).abilities
		for index: int in abilities.size():
			var ability: ActivatedAbility = abilities[index] as ActivatedAbility
			if ability != null and ability.is_mana_ability() and ability.can_pay_costs(_state, permanent):
				actions.append(ActivateAbilityAction.new(permanent.id, index))
	return actions


## CR 305.2 and 505.6b: in your own main phase, with an empty stack, while you have a land
## play left this turn.
func _may_play_land(player: MmPlayer) -> bool:
	var in_main_phase: bool = _current_step() in [MmTurn.Step.PRECOMBAT_MAIN, MmTurn.Step.POSTCOMBAT_MAIN]
	return (player.id == _state.active_player_id and in_main_phase and _state.stack.is_empty()
		and player.lands_played_this_turn < _land_plays_allowed(player))


func _land_plays_allowed(_player: MmPlayer) -> int:
	# Later (milestone 9): static abilities and Emblems that grant extra land plays.
	return 1


## CR 305.1: the land moves straight to the battlefield. The player keeps priority, and
## taking an action means everyone must pass again before the step ends (CR 117.4).
func _play_land(action: PlayLandAction) -> void:
	var land: MmGameObject = _state.object(action.object_id)
	_state.perform(ZoneChangeEvent.new(land, _state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.PLAY_LAND))
	_passes_in_succession = 0


## CR 605.3: a mana ability resolves immediately without using the stack, and the player
## keeps priority.
func _activate_mana_ability(action: ActivateAbilityAction) -> void:
	var source: MmGameObject = _state.object(action.object_id)
	var ability: ActivatedAbility = _state.characteristics_of(source).abilities[action.ability_index] as ActivatedAbility
	assert(ability != null and ability.is_mana_ability(), "Only mana abilities can be activated so far.")
	ability.pay_costs(_state, source)
	ability.resolve_effects(_state, MmEffectContext.new(source.controller_id, source.id))
	_passes_in_succession = 0


func _sorted_by_id(objects: Array[MmGameObject]) -> Array[MmGameObject]:
	var sorted: Array[MmGameObject] = objects.duplicate()
	sorted.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return sorted
