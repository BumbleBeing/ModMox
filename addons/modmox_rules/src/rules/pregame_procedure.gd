class_name PregameProcedure
extends RefCounted
## Starting the game (CR 103): determine the starting player, shuffle, draw opening hands,
## then London mulligans until every player has kept.

enum Step { DETERMINE_STARTING_PLAYER, AWAIT_PLAY_OR_DRAW, SHUFFLE_AND_DRAW, KEEP_OR_MULLIGAN, BOTTOM_CARDS, RESOLVE_MULLIGANS, DONE }

var _state: MmGameState
var _rule: MmEncounterSetup.StartingPlayerRule
var _step: Step = Step.DETERMINE_STARTING_PLAYER
## Players still to answer keep or mulligan this round, in turn order.
var _undecided: Array[int] = []
## Players who kept this round and may owe cards to the bottom, in turn order.
var _to_bottom: Array[int] = []
## Players who chose to mulligan this round, in turn order.
var _to_mulligan: Array[int] = []
var _kept: Dictionary[int, bool] = {}


func _init(state: MmGameState, rule: MmEncounterSetup.StartingPlayerRule) -> void:
	_state = state
	_rule = rule


## A copy of this procedure working on [param state], a copy of the original state.
func copy_for(state: MmGameState) -> PregameProcedure:
	var copy: PregameProcedure = PregameProcedure.new(state, _rule)
	copy._step = _step
	copy._undecided = _undecided.duplicate()
	copy._to_bottom = _to_bottom.duplicate()
	copy._to_mulligan = _to_mulligan.duplicate()
	copy._kept = _kept.duplicate()
	return copy


## Runs every automatic step until a player must decide. Returns that decision, or null
## once the pregame is over.
func next_decision() -> MmPendingDecision:
	while true:
		match _step:
			Step.DETERMINE_STARTING_PLAYER:
				var choice: MmPendingDecision = _determine_starting_player()
				if choice != null:
					return choice
			Step.AWAIT_PLAY_OR_DRAW:
				assert(false, "The play/draw decision has not been answered.")
				return null
			Step.SHUFFLE_AND_DRAW:
				_shuffle_and_draw_opening_hands()
				_begin_mulligan_round()
			Step.KEEP_OR_MULLIGAN:
				if not _undecided.is_empty():
					var deciding: MmPlayer = _state.player(_undecided[0])
					return KeepOrMulliganDecision.new(deciding.id, deciding.mulligans_taken, _cards_to_bottom(deciding))
				_step = Step.BOTTOM_CARDS
			Step.BOTTOM_CARDS:
				while not _to_bottom.is_empty():
					var keeper: MmPlayer = _state.player(_to_bottom[0])
					var count: int = _cards_to_bottom(keeper)
					if count > 0:
						return ChooseCardsToBottomDecision.new(keeper.id, count, keeper.hand.object_ids())
					_to_bottom.pop_front()
				_step = Step.RESOLVE_MULLIGANS
			Step.RESOLVE_MULLIGANS:
				_resolve_mulligans()
				if _kept.size() == _state.players.size():
					_step = Step.DONE
				else:
					_begin_mulligan_round()
			Step.DONE:
				return null
	return null


## Applies an already-validated [param answer] to [param decision].
func apply_answer(decision: MmPendingDecision, answer: Variant) -> void:
	if decision is ChoosePlayOrDrawDecision:
		var chooser_id: int = decision.player_id
		var plays: bool = answer == ChoosePlayOrDrawDecision.Choice.PLAY
		var starting_id: int = chooser_id if plays else _state.opponent_of(chooser_id).id
		_state.perform(StartingPlayerEvent.new(starting_id, chooser_id))
		_step = Step.SHUFFLE_AND_DRAW
	elif decision is KeepOrMulliganDecision:
		var player_id: int = _undecided.pop_front()
		if answer == KeepOrMulliganDecision.Choice.KEEP:
			_kept[player_id] = true
			_to_bottom.append(player_id)
		else:
			_to_mulligan.append(player_id)
	elif decision is ChooseCardsToBottomDecision:
		var keeper: MmPlayer = _state.player(decision.player_id)
		for id: int in answer:
			_state.perform(ZoneChangeEvent.new(_state.object(id), keeper.library, MmZone.BOTTOM, ZoneChangeEvent.Reason.PUT_ON_BOTTOM))
		_to_bottom.pop_front()
	else:
		assert(false, "The pregame cannot answer %s." % decision.describe())


## Returns the play/draw decision, or null when the setup forces the starting player.
func _determine_starting_player() -> MmPendingDecision:
	var chooser_id: int = MmGameState.NO_PLAYER
	match _rule:
		MmEncounterSetup.StartingPlayerRule.HERO_STARTS:
			_state.perform(StartingPlayerEvent.new(MmEncounterSetup.HERO_PLAYER_ID))
		MmEncounterSetup.StartingPlayerRule.VILLAIN_STARTS:
			_state.perform(StartingPlayerEvent.new(MmEncounterSetup.VILLAIN_PLAYER_ID))
		MmEncounterSetup.StartingPlayerRule.HERO_CHOOSES:
			chooser_id = MmEncounterSetup.HERO_PLAYER_ID
		MmEncounterSetup.StartingPlayerRule.VILLAIN_CHOOSES:
			chooser_id = MmEncounterSetup.VILLAIN_PLAYER_ID
		MmEncounterSetup.StartingPlayerRule.RANDOM_CHOOSER:
			# CR 103.1: a random method (the coin flip) picks who chooses.
			chooser_id = _state.game_rng.next_int(_state.players.size())
	if chooser_id == MmGameState.NO_PLAYER:
		_step = Step.SHUFFLE_AND_DRAW
		return null
	_step = Step.AWAIT_PLAY_OR_DRAW
	return ChoosePlayOrDrawDecision.new(chooser_id)


## CR 103.2 and 103.4: shuffle each library, then each player draws an opening hand.
func _shuffle_and_draw_opening_hands() -> void:
	for player: MmPlayer in _state.turn_order():
		_state.perform(ShuffleEvent.new(player.library))
	for player: MmPlayer in _state.turn_order():
		_state.draw_cards(player.id, player.opening_hand_size)


func _begin_mulligan_round() -> void:
	_undecided.clear()
	_to_bottom.clear()
	_to_mulligan.clear()
	for player: MmPlayer in _state.turn_order():
		if not _kept.has(player.id):
			_undecided.append(player.id)
	_step = Step.KEEP_OR_MULLIGAN


## CR 103.5: each mulliganing player shuffles their hand into their library and draws a
## new hand of their opening hand size.
func _resolve_mulligans() -> void:
	for player_id: int in _to_mulligan:
		var player: MmPlayer = _state.player(player_id)
		_state.perform(MulliganEvent.new(player_id))
		for card: MmGameObject in player.hand.objects():
			_state.perform(ZoneChangeEvent.new(card, player.library, MmZone.BOTTOM, ZoneChangeEvent.Reason.MULLIGAN))
		_state.perform(ShuffleEvent.new(player.library))
		_state.draw_cards(player_id, player.opening_hand_size)


## London mulligan: one card per mulligan beyond the player's Free Mulligans, but never
## more than the hand holds.
func _cards_to_bottom(player: MmPlayer) -> int:
	var owed: int = maxi(0, player.mulligans_taken - player.free_mulligans)
	return mini(owed, player.hand.size())
