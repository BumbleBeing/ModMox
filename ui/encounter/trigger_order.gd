class_name TriggerOrder
extends RefCounted
## The Hero's half-made answer to an order-triggers decision (A339): the triggers in a
## list whose top resolves first, moved up and down one place at a time. Kept by the
## Encounter Screen outside the nodes it redraws, as a CombatSelection is, and confirmed
## with the pass button.

var _decision: OrderTriggersDecision = null
## Trigger numbers, the one that resolves first at the front.
var _order: Array[int] = []
## The orders before each move, for undo.
var _history: Array = []


## Whether [param decision] is answered by ordering triggers.
static func covers(decision: MmPendingDecision) -> bool:
	return decision is OrderTriggersDecision


## Whether every trigger of [param decision] reads the same and was triggered by the same
## player or object, so that their order changes nothing and the Hero need not be asked
## (A344). Abilities are compared by their words, since each card has its own copy.
static func are_alike(decision: OrderTriggersDecision) -> bool:
	for index: int in range(1, decision.abilities.size()):
		if AbilityText.of_ability(decision.abilities[index], "this") != AbilityText.of_ability(decision.abilities[0], "this"):
			return false
		if decision.triggering_player_ids[index] != decision.triggering_player_ids[0]:
			return false
		if decision.triggering_object_ids[index] != decision.triggering_object_ids[0]:
			return false
	return true


func _init(decision: MmPendingDecision = null) -> void:
	_decision = decision as OrderTriggersDecision
	if _decision != null:
		for index: int in _decision.source_object_ids.size():
			_order.append(index)


## Whether this is the order being made for [param decision]: a new decision needs a new one.
func is_for(decision: MmPendingDecision) -> bool:
	return _decision == decision


func is_active() -> bool:
	return _decision != null


## The trigger numbers, from the one that resolves first down.
func order() -> Array[int]:
	return _order.duplicate()


## Whether the trigger at [param place] can move [param step] places: -1 is up, 1 is down.
func can_move(place: int, step: int) -> bool:
	return place >= 0 and place < _order.size() and place + step >= 0 and place + step < _order.size()


## Swaps the trigger at [param place] with the one [param step] places away. Returns
## whether it could.
func move(place: int, step: int) -> bool:
	if not can_move(place, step):
		return false
	_history.append(_order.duplicate())
	var moved: int = _order[place]
	_order[place] = _order[place + step]
	_order[place + step] = moved
	return true


func can_undo() -> bool:
	return not _history.is_empty()


## Takes back the last move. Returns whether there was one.
func undo() -> bool:
	if _history.is_empty():
		return false
	_order.assign(_history.pop_back() as Array)
	return true


## The decision's answer: the triggers in the order they go on the stack, so the one that
## resolves first is listed last (ADR 0016).
func answer() -> Array:
	var put_on_stack: Array = []
	for index: int in range(_order.size() - 1, -1, -1):
		put_on_stack.append(_order[index])
	return put_on_stack
