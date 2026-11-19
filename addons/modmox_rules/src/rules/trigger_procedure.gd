class_name TriggerProcedure
extends RefCounted
## Puts every pending trigger on the stack before a player receives priority (CR 603.3b):
## the active player's first, then the other player's, each player choosing the order of
## their own. A modal one's mode is chosen as it is put on the stack, and one with no mode
## that can be chosen is removed instead (CR 603.3c). Targets are chosen next, and one with
## no legal target for a requirement is removed instead (CR 603.3d); an "up to" requirement
## may always choose none, so it never removes one.
##
## Later: no order decision for triggers whose order cannot matter, such as two copies of
## the same ability from the same source triggered by the same event.

var _state: MmGameState
## Players still to stack their triggers, in APNAP order.
var _players: Array[int] = []
## The triggers chosen to go on the stack next, in order.
var _queue: Array[PendingTrigger] = []
## The player whose triggers are being ordered, or MmGameState.NO_PLAYER.
var _ordering_player_id: int = MmGameState.NO_PLAYER
var _ordering: Array[PendingTrigger] = []
## The triggered ability whose mode or targets are being chosen, or 0.
var _stack_object_id: int = 0
## Whether its mode is still to be chosen (CR 603.3c).
var _is_choosing_mode: bool = false
var _target_requirements: Array[TargetRequirement] = []
var _next_target: int = 0
var _controller_id: int = MmGameState.NO_PLAYER


func _init(state: MmGameState) -> void:
	_state = state
	var active_id: int = state.active_player_id
	_players = [active_id, state.opponent_of(active_id).id]


## A copy of this procedure working on [param state], a copy of the original state.
func copy_for(state: MmGameState) -> TriggerProcedure:
	var copy: TriggerProcedure = TriggerProcedure.new(state)
	copy._players = _players.duplicate()
	copy._queue = _queue.duplicate()  # Pending triggers never change, so sharing them is safe.
	copy._ordering_player_id = _ordering_player_id
	copy._ordering = _ordering.duplicate()
	copy._stack_object_id = _stack_object_id
	copy._is_choosing_mode = _is_choosing_mode
	copy._target_requirements = _target_requirements
	copy._next_target = _next_target
	copy._controller_id = _controller_id
	return copy


## The next choice a player must make, or null once every pending trigger is on the stack
## or removed.
func next_decision() -> MmPendingDecision:
	while true:
		if _stack_object_id != 0 and _is_choosing_mode:
			var decision: ChooseModeDecision = _mode_decision()
			assert(decision != null, "A mode could be chosen as the trigger was put on the stack.")
			if decision.modes.size() > 1:
				return decision
			_choose_mode(decision.modes[0])  # The only mode that can be chosen needs no asking.
			continue
		if _stack_object_id != 0 and _next_target < _target_requirements.size():
			var context: MmEffectContext = MmEffectContext.of_stack_object(_state.object(_stack_object_id))
			var choice: MmPendingDecision = TargetChoice.decision_for(_state, _controller_id, _stack_object_id,
				_target_requirements, _next_target, context)
			if choice != null:
				return choice
			_next_target += 1  # An "up to" with nothing to choose chooses none, unasked.
			continue
		_stack_object_id = 0
		if _ordering_player_id != MmGameState.NO_PLAYER:
			return OrderTriggersDecision.new(_ordering_player_id, _ordering)
		if not _queue.is_empty():
			_put_on_stack(_queue.pop_front())
			continue
		if _players.is_empty():
			return null
		var player_id: int = _players.pop_front()
		var theirs: Array[PendingTrigger] = []
		for pending: PendingTrigger in _state.pending_triggers:
			if pending.controller_id == player_id:
				theirs.append(pending)
		if theirs.size() > 1:
			_ordering_player_id = player_id
			_ordering = theirs
		else:
			_queue = theirs
	return null


## Applies an already-validated [param answer] to [param decision].
func apply_answer(decision: MmPendingDecision, answer: Variant) -> void:
	if decision is OrderTriggersDecision:
		_queue = []
		for index: Variant in answer as Array:
			_queue.append(_ordering[index as int])
		_ordering_player_id = MmGameState.NO_PLAYER
		_ordering = []
	elif decision is ChooseModeDecision:
		_choose_mode((decision as ChooseModeDecision).modes[answer as int])
	elif decision is ChooseTargetDecision or decision is ChooseTargetsDecision:
		TargetChoice.perform_answer(_state, decision, answer, _target_requirements)
		_next_target += 1
	else:
		assert(false, "Stacking triggers cannot answer %s." % decision.describe())


func _put_on_stack(pending: PendingTrigger) -> void:
	var ability: TriggeredAbility = pending.ability
	if ability.is_modal():
		if ChooseModeDecision.of(_state, pending.controller_id, 0, ability.modes, pending.context()) == null:
			_state.perform(TriggerRemovedEvent.new(pending))  # CR 603.3c: no mode can be chosen.
			return
	else:
		for requirement: TargetRequirement in ability.targets:
			if not requirement.can_be_chosen(_state, pending.context()):
				_state.perform(TriggerRemovedEvent.new(pending))  # CR 603.3d
				return
	var put: TriggeredAbilityPutOnStackEvent = TriggeredAbilityPutOnStackEvent.new(pending)
	_state.perform(put)
	_stack_object_id = put.new_object_id
	_is_choosing_mode = ability.is_modal()
	_target_requirements = ability.targets
	_next_target = 0
	_controller_id = pending.controller_id


## The modes of the triggered ability being put on the stack that may be chosen, each with
## what its targets could be (CR 700.2a).
func _mode_decision() -> ChooseModeDecision:
	var put: MmGameObject = _state.object(_stack_object_id)
	return ChooseModeDecision.of(_state, _controller_id, _stack_object_id, (put.ability as TriggeredAbility).modes,
		MmEffectContext.of_stack_object(put))


func _choose_mode(mode_index: int) -> void:
	_state.perform(ModeChosenEvent.new(_stack_object_id, mode_index))
	_target_requirements = (_state.object(_stack_object_id).ability as TriggeredAbility).modes[mode_index].targets
	_is_choosing_mode = false
