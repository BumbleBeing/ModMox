class_name TurnProcedure
extends RefCounted
## Turns, steps, priority and the stack, from the first turn on (CR 500, 117, 405, 608).

enum Stage { START_TURN, START_STEP, TURN_BASED_ACTIONS, AWAIT_DISCARD, PRIORITY, END_STEP }

var _state: MmGameState
var _stage: Stage = Stage.START_TURN
## This turn's steps, after any skipped for the whole turn.
var _steps: Array[MmTurn.Step] = []
var _step_index: int = 0
var _priority_player_id: int = MmGameState.NO_PLAYER
var _passes_in_succession: int = 0
## The spell being cast or ability being activated, while its choices are being made.
var _cast: CastProcedure = null
## The combat step's turn-based actions, while their choices are being made.
var _combat_step: CombatProcedure = null
## Pending triggers being put on the stack, while their order and targets are chosen.
var _stacking: TriggerProcedure = null
var _needs_rewind: bool = false


func _init(state: MmGameState) -> void:
	_state = state


## A copy of this procedure working on [param state], a copy of the original state.
func copy_for(state: MmGameState) -> TurnProcedure:
	var copy: TurnProcedure = TurnProcedure.new(state)
	copy._stage = _stage
	copy._steps = _steps.duplicate()
	copy._step_index = _step_index
	copy._priority_player_id = _priority_player_id
	copy._passes_in_succession = _passes_in_succession
	copy._cast = null if _cast == null else _cast.copy_for(state)
	copy._combat_step = null if _combat_step == null else _combat_step.copy_for(state)
	copy._stacking = null if _stacking == null else _stacking.copy_for(state)
	copy._needs_rewind = _needs_rewind
	return copy


## Whether a spell is being cast, or an ability activated, right now.
func is_casting() -> bool:
	return _cast != null


## Whether the spell or ability being cast can no longer be paid for, so the engine must
## rewind it (CR 728).
func needs_rewind() -> bool:
	return _needs_rewind


## Runs every automatic step until a player must decide, and returns that decision.
## Returns null when a cast must be rewound or the encounter is over.
func next_decision() -> MmPendingDecision:
	while true:
		if _cast != null:
			var casting: MmPendingDecision = _cast.next_decision()
			if casting != null:
				return casting
			if _cast.is_stuck():
				_needs_rewind = true
				return null
			# CR 117.3c: after casting or activating, that player receives priority.
			_cast = null
			_passes_in_succession = 0
			_stage = Stage.PRIORITY
		if _stacking != null:
			var stacking_decision: MmPendingDecision = _stacking.next_decision()
			if stacking_decision != null:
				return stacking_decision
			_stacking = null
			# CR 117.4: the stack changed, so every player must pass again.
			_passes_in_succession = 0
		if _combat_step != null:
			var combat_decision: MmPendingDecision = _combat_step.next_decision()
			if combat_decision != null:
				return combat_decision
			_combat_step = null
			_begin_priority_or_end_step()
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
				if _combat_step == null:
					_begin_priority_or_end_step()
			Stage.AWAIT_DISCARD:
				assert(false, "The discard decision has not been answered.")
				return null
			Stage.PRIORITY:
				# CR 704.3: state-based actions are checked whenever a player would receive priority.
				StateBasedActions.check(_state)
				if _state.is_over:
					return null
				if _state.pending_triggers.is_empty():
					return PriorityDecision.new(_priority_player_id, _legal_actions(_priority_player_id))
				# CR 603.3: triggers go on the stack after state-based actions, and both are
				# checked again before the player finally receives priority.
				_stacking = TriggerProcedure.new(_state)
			Stage.END_STEP:
				_end_step()
	return null


## Applies an already-validated [param answer] to [param decision].
func apply_answer(decision: MmPendingDecision, answer: Variant) -> void:
	if _cast != null:
		_cast.apply_answer(decision, answer)
	elif _stacking != null:
		_stacking.apply_answer(decision, answer)
	elif _combat_step != null:
		_combat_step.apply_answer(decision, answer)
	elif decision is PriorityDecision:
		var index: int = answer
		var action: MmAction = (decision as PriorityDecision).actions[index]
		if action is PassAction:
			_pass_priority()
		elif action is PlayLandAction:
			_play_land(action as PlayLandAction)
		elif action is CastSpellAction:
			_cast = CastProcedure.cast_spell(_state, decision.player_id, _state.object((action as CastSpellAction).object_id))
		elif action is ActivateAbilityAction:
			_activate(action as ActivateAbilityAction, decision.player_id)
		else:
			assert(false, "Unknown action: %s" % action.describe())
	elif decision is ChooseCardsToDiscardDecision:
		var discarding: MmPlayer = _state.player(decision.player_id)
		for id: int in answer:
			_state.perform(ZoneChangeEvent.new(_state.object(id), discarding.graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.DISCARD))
		_remove_damage()
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
	_stage = Stage.START_STEP


## Performs the current step's turn-based actions (CR 703). Returns a decision when one of
## them needs a player's choice. A combat step's actions are left to a CombatProcedure.
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
			_combat_step = CombatProcedure.declare_attackers(_state)
		MmTurn.Step.DECLARE_BLOCKERS:
			_combat_step = CombatProcedure.declare_blockers(_state)
		MmTurn.Step.COMBAT_DAMAGE:
			_combat_step = CombatProcedure.combat_damage(_state)
			if _state.combat.is_first_strike_damage_step:
				# CR 510.4: the regular combat damage step follows the first-strike one.
				_steps.insert(_step_index + 1, MmTurn.Step.COMBAT_DAMAGE)
		MmTurn.Step.CLEANUP:
			var excess: int = active.cards_over_maximum_hand_size()
			if excess > 0:
				return ChooseCardsToDiscardDecision.new(active.id, excess, active.hand.object_ids())  # CR 514.1
			_remove_damage()
	return null


## CR 514.2: after any discarding, all damage marked on permanents is removed, all at once.
func _remove_damage() -> void:
	# Later (milestone 9): a static ability can keep a permanent's damage from being removed.
	var removals: Array[MmEvent] = []
	for permanent: MmGameObject in ManaPayment.sorted_permanents_of(_state, _state.active_player_id) \
			+ ManaPayment.sorted_permanents_of(_state, _state.opponent_of(_state.active_player_id).id):
		if permanent.damage_marked > 0:
			removals.append(DamageRemovedEvent.new(permanent.id))
	if not removals.is_empty():
		_state.perform_together(removals)


func _begin_priority_or_end_step() -> void:
	var cleanup_needs_priority: bool = _current_step() == MmTurn.Step.CLEANUP \
		and (not _state.pending_triggers.is_empty() or StateBasedActions.any_apply(_state))
	if cleanup_needs_priority:
		# CR 514.3a: players get priority in this cleanup step, and another one follows.
		_steps.insert(_step_index + 1, MmTurn.Step.CLEANUP)
	if MmTurn.grants_priority(_current_step()) or cleanup_needs_priority:
		# CR 117.3a: the active player receives priority first in each step.
		_priority_player_id = _state.active_player_id
		_passes_in_succession = 0
		_stage = Stage.PRIORITY
	else:
		_stage = Stage.END_STEP


## CR 117.3d and 117.4: priority passes to the next player. Once every player has passed
## in succession, the top of the stack resolves, or the step ends if the stack is empty.
func _pass_priority() -> void:
	_passes_in_succession += 1
	if _passes_in_succession < _state.players.size():
		_priority_player_id = _state.opponent_of(_priority_player_id).id
	elif _state.stack.is_empty():
		_priority_player_id = MmGameState.NO_PLAYER
		_stage = Stage.END_STEP
	else:
		_resolve_top_of_stack()
		# CR 117.3b: after resolution the active player receives priority.
		_priority_player_id = _state.active_player_id
		_passes_in_succession = 0


## CR 608.2: the top object resolves. Targets are rechecked first: if every target is now
## illegal it does not resolve, and otherwise effects simply skip illegal targets.
func _resolve_top_of_stack() -> void:
	var resolving: MmGameObject = _state.stack.objects().back()
	var specs: Array[TargetSpec] = []
	var effects: Array[MmEffect] = []
	if resolving.is_card():
		var spell: SpellAbility = CastProcedure.spell_ability_of(_state.characteristics_of(resolving))
		if spell != null:
			specs = spell.targets
			effects = spell.effects
	elif resolving.ability is TriggeredAbility:
		var triggered: TriggeredAbility = resolving.ability as TriggeredAbility
		specs = triggered.targets
		effects = triggered.effects
	else:
		var activated: ActivatedAbility = resolving.ability as ActivatedAbility
		specs = activated.targets
		effects = activated.effects
	var source_id: int = resolving.id if resolving.is_card() else resolving.source_object_id
	var checking: MmEffectContext = MmEffectContext.new(resolving.controller_id, source_id, [],
		resolving.triggering_player_id, resolving.triggering_object_id)
	var targets: Array[MmReference] = []
	var any_legal: bool = specs.is_empty()
	for index: int in specs.size():
		var chosen: MmReference = resolving.targets[index] if index < resolving.targets.size() else null
		var still_legal: bool = specs[index].is_still_legal(_state, chosen, checking)
		targets.append(chosen if still_legal else null)
		any_legal = any_legal or still_legal
	var triggered_ability: TriggeredAbility = resolving.ability as TriggeredAbility
	if triggered_ability != null and not triggered_ability.condition_holds(_state, checking):
		any_legal = false  # CR 603.4: the intervening "if" no longer holds, so it does nothing.
	if any_legal:
		var context: MmEffectContext = MmEffectContext.new(resolving.controller_id, source_id, targets,
			resolving.triggering_player_id, resolving.triggering_object_id)
		for effect: MmEffect in effects:
			effect.resolve(_state, context)
	if resolving.is_card() and any_legal and _state.characteristics_of(resolving).is_permanent():
		# CR 608.3: a permanent spell enters the battlefield. Its controller is its owner
		# until control-changing effects exist (milestone 9), as CR 608.3a needs.
		_state.perform(ZoneChangeEvent.new(_state.object(resolving.id), _state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.RESOLVED))
	elif resolving.is_card():
		# CR 608.2n: an instant or sorcery goes to its owner's graveyard.
		var reason: ZoneChangeEvent.Reason = ZoneChangeEvent.Reason.RESOLVED if any_legal else ZoneChangeEvent.Reason.DID_NOT_RESOLVE
		_state.perform(ZoneChangeEvent.new(_state.object(resolving.id), _state.player(resolving.owner_id).graveyard, MmZone.BOTTOM, reason))
	else:
		_state.perform(AbilityLeftStackEvent.new(resolving.id, any_legal))


func _end_step() -> void:
	# CR 500.4: unspent mana empties from each pool at the end of each step and phase.
	for player: MmPlayer in _state.turn_order():
		if not player.mana_pool().is_empty():
			_state.perform(ManaEmptiedEvent.new(player.id))
	if _current_step() == MmTurn.Step.END_OF_COMBAT and _state.combat.has_declared_attackers():
		_state.perform(CombatEndedEvent.new())  # CR 511.3
	_step_index += 1
	if not _state.combat.has_declared_attackers():
		# CR 508.8: without attackers, the declare blockers and combat damage steps are skipped.
		while _step_index < _steps.size() and _current_step() in [MmTurn.Step.DECLARE_BLOCKERS, MmTurn.Step.COMBAT_DAMAGE]:
			_step_index += 1
	_stage = Stage.START_TURN if _step_index >= _steps.size() else Stage.START_STEP


func _current_step() -> MmTurn.Step:
	return _steps[_step_index]


## The actions [param player_id] may take while holding priority, in a deterministic order
## (ADR 0012): Pass, then land plays, then spells, then abilities, each by object ID and
## abilities by their order on the object.
func _legal_actions(player_id: int) -> Array[MmAction]:
	var actions: Array[MmAction] = [PassAction.new()]
	var player: MmPlayer = _state.player(player_id)
	var hand: Array[MmGameObject] = _sorted_by_id(player.hand.objects())
	if _may_play_land(player):
		for card: MmGameObject in hand:
			if _state.characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND):
				actions.append(PlayLandAction.new(card.id))
	for card: MmGameObject in hand:
		if _may_cast(player, card):
			actions.append(CastSpellAction.new(card.id))
	for permanent: MmGameObject in ManaPayment.sorted_permanents_of(_state, player_id):
		var abilities: Array[MmAbility] = _state.characteristics_of(permanent).abilities
		for index: int in abilities.size():
			var ability: ActivatedAbility = abilities[index] as ActivatedAbility
			if ability != null and _may_activate(player, permanent, ability):
				actions.append(ActivateAbilityAction.new(permanent.id, index))
	return actions


## CR 305.2 and 505.6b: in your own main phase, with an empty stack, while you have a land
## play left this turn.
func _may_play_land(player: MmPlayer) -> bool:
	return _sorcery_timing(player) and player.lands_played_this_turn < _land_plays_allowed(player)


func _land_plays_allowed(_player: MmPlayer) -> int:
	# Later (milestone 9): static abilities and Emblems that grant extra land plays.
	return 1


## CR 307.1: "sorcery speed" means your own main phase with an empty stack.
func _sorcery_timing(player: MmPlayer) -> bool:
	var in_main_phase: bool = _current_step() in [MmTurn.Step.PRECOMBAT_MAIN, MmTurn.Step.POSTCOMBAT_MAIN]
	return player.id == _state.active_player_id and in_main_phase and _state.stack.is_empty()


## Whether [param card] in hand could be cast right now from start to finish: its timing,
## a legal target for every requirement (CR 601.2c), and a cost that can be paid. Any card
## but a land may be cast, so permanent spells need no special case (CR 608.3).
func _may_cast(player: MmPlayer, card: MmGameObject) -> bool:
	var characteristics: MmCharacteristics = _state.characteristics_of(card)
	if characteristics.mana_cost == null:
		return false  # CR 118.6: a card with no mana cost cannot be cast this way.
	if characteristics.has_card_type(MmCardTypes.CardType.LAND):
		return false  # CR 305.9: a land is played, never cast.
	# CR 307.1 and 702.8a: only an instant, or a card with flash, ignores sorcery timing.
	var instant_speed: bool = characteristics.has_card_type(MmCardTypes.CardType.INSTANT) \
		or characteristics.has_ability(FlashAbility)
	if not instant_speed and not _sorcery_timing(player):
		return false
	var spell: SpellAbility = CastProcedure.spell_ability_of(characteristics)
	if spell != null and not _every_requirement_has_a_target(spell.targets, player.id, card.id):
		return false
	return ManaPayment.can_afford(_state, player.id, characteristics.mana_cost)


## Mana abilities whenever their cost can be paid; other abilities also need a legal
## target for every requirement.
func _may_activate(player: MmPlayer, permanent: MmGameObject, ability: ActivatedAbility) -> bool:
	if not ability.can_pay_costs(_state, permanent):
		return false
	return ability.is_mana_ability() or _every_requirement_has_a_target(ability.targets, player.id, permanent.id)


func _every_requirement_has_a_target(specs: Array[TargetSpec], player_id: int, source_id: int) -> bool:
	var context: MmEffectContext = MmEffectContext.new(player_id, source_id)
	for spec: TargetSpec in specs:
		if spec.legal_targets(_state, context).is_empty():
			return false
	return true


## CR 305.1: the land moves straight to the battlefield. The player keeps priority, and
## taking an action means everyone must pass again before the step ends (CR 117.4).
func _play_land(action: PlayLandAction) -> void:
	var land: MmGameObject = _state.object(action.object_id)
	_state.perform(ZoneChangeEvent.new(land, _state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.PLAY_LAND))
	_passes_in_succession = 0


## CR 605.3: a mana ability resolves immediately without using the stack, and the player
## keeps priority. Any other ability goes on the stack (CR 602.2).
func _activate(action: ActivateAbilityAction, player_id: int) -> void:
	var source: MmGameObject = _state.object(action.object_id)
	var ability: ActivatedAbility = _state.characteristics_of(source).abilities[action.ability_index] as ActivatedAbility
	if ability.is_mana_ability():
		ability.pay_costs(_state, source)
		ability.resolve_effects(_state, MmEffectContext.new(source.controller_id, source.id))
		_passes_in_succession = 0
	else:
		_cast = CastProcedure.activate_ability(_state, player_id, source, action.ability_index)


func _sorted_by_id(objects: Array[MmGameObject]) -> Array[MmGameObject]:
	var sorted: Array[MmGameObject] = objects.duplicate()
	sorted.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return sorted
