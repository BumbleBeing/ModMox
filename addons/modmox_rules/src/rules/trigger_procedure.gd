class_name TriggerProcedure
extends RefCounted
## Puts every pending trigger on the stack before a player receives priority (CR 603.3b):
## the active player's first, then the other player's, each player choosing the order of
## their own. Targets are chosen as each one is put on the stack, and one with no legal
## target for a requirement is removed instead (CR 603.3d).
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
## The triggered ability whose targets are being chosen, or 0.
var _stack_object_id: int = 0
var _target_specs: Array[TargetSpec] = []
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
	copy._target_specs = _target_specs
	copy._next_target = _next_target
	copy._controller_id = _controller_id
	return copy


## The next choice a player must make, or null once every pending trigger is on the stack
## or removed.
func next_decision() -> MmPendingDecision:
	while true:
		if _stack_object_id != 0 and _next_target < _target_specs.size():
			var context: MmEffectContext = MmEffectContext.new(_controller_id, _stack_object_id)
			var legal: Array[MmReference] = _target_specs[_next_target].legal_targets(_state, context)
			return ChooseTargetDecision.new(_controller_id, _stack_object_id, _next_target, legal)
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
	elif decision is ChooseTargetDecision:
		var chosen: MmReference = (decision as ChooseTargetDecision).candidates[answer as int]
		_state.perform(TargetChosenEvent.new(_stack_object_id, _next_target, chosen))
		_next_target += 1
	else:
		assert(false, "Stacking triggers cannot answer %s." % decision.describe())


func _put_on_stack(pending: PendingTrigger) -> void:
	for spec: TargetSpec in pending.ability.targets:
		if spec.legal_targets(_state, pending.context()).is_empty():
			_state.perform(TriggerRemovedEvent.new(pending))  # CR 603.3d
			return
	var put: TriggeredAbilityPutOnStackEvent = TriggeredAbilityPutOnStackEvent.new(pending)
	_state.perform(put)
	_stack_object_id = put.new_object_id
	_target_specs = pending.ability.targets
	_next_target = 0
	_controller_id = pending.controller_id
