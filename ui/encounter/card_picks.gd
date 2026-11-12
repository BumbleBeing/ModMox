class_name CardPicks
extends RefCounted
## The Hero's half-made answer to a decision that chooses cards from their hand (13e-2):
## which to put on the bottom after keeping, or which to discard. Cards are picked one
## click at a time, and the answer lists them in the order picked, so the last card put on
## the bottom ends up lowest. Kept by the Encounter Screen outside the nodes it redraws, as
## a CombatSelection is, and confirmed with a button.
##
## Cards are known here by Game Object ID, as the decision names them: nothing moves while
## the decision is pending, so the IDs hold.

var _decision: MmPendingDecision = null
var _candidates: Array[int] = []
var _count: int = 0
var _picked: Array[int] = []
## The picks before each click, for undo.
var _history: Array = []


## Whether [param decision] is answered by picking cards.
static func covers(decision: MmPendingDecision) -> bool:
	return decision is ChooseCardsToBottomDecision or decision is ChooseCardsToDiscardDecision


func _init(decision: MmPendingDecision = null) -> void:
	if decision is ChooseCardsToBottomDecision:
		_decision = decision
		_candidates = (decision as ChooseCardsToBottomDecision).candidate_ids.duplicate()
		_count = (decision as ChooseCardsToBottomDecision).count
	elif decision is ChooseCardsToDiscardDecision:
		_decision = decision
		_candidates = (decision as ChooseCardsToDiscardDecision).candidate_ids.duplicate()
		_count = (decision as ChooseCardsToDiscardDecision).count


## Whether these are the picks being made for [param decision]: a new decision needs new ones.
func is_for(decision: MmPendingDecision) -> bool:
	return _decision == decision


func is_active() -> bool:
	return _decision != null


func is_bottoming() -> bool:
	return _decision is ChooseCardsToBottomDecision


func is_discarding() -> bool:
	return _decision is ChooseCardsToDiscardDecision


## Whether the order picked changes anything: only for several cards put on the bottom.
func is_ordered() -> bool:
	return is_bottoming() and _count > 1


## How many cards must be picked.
func count() -> int:
	return _count


## The cards picked so far, in the order picked.
func picked() -> Array[int]:
	return _picked.duplicate()


func is_picked(object_id: int) -> bool:
	return _picked.has(object_id)


## Whether [param object_id] can be picked now: a card of the decision, not picked yet,
## while fewer than the count are.
func can_pick(object_id: int) -> bool:
	return _candidates.has(object_id) and not _picked.has(object_id) and _picked.size() < _count


## Picks [param object_id]. Returns whether it could.
func pick(object_id: int) -> bool:
	if not can_pick(object_id):
		return false
	_history.append(_picked.duplicate())
	_picked.append(object_id)
	return true


## Picks [param object_id], or lets it go if it was picked. Returns whether anything changed.
func toggle(object_id: int) -> bool:
	if not _picked.has(object_id):
		return pick(object_id)
	_history.append(_picked.duplicate())
	_picked.erase(object_id)
	return true


func can_undo() -> bool:
	return not _history.is_empty()


## Takes back the last click. Returns whether there was one.
func undo() -> bool:
	if _history.is_empty():
		return false
	_picked.assign(_history.pop_back() as Array)
	return true


func is_complete() -> bool:
	return is_active() and _picked.size() == _count


## The decision's answer: the picked cards' IDs, in the order picked.
func answer() -> Array:
	var ids: Array = []
	ids.assign(_picked)
	return ids


## What the Hero is asked, in one line.
func prompt() -> String:
	var cards: String = "%d card%s" % [_count, "" if _count == 1 else "s"]
	if is_bottoming():
		return "Put %s on the bottom" % cards
	if is_discarding():
		return "Discard %s (%d chosen)" % [cards, _picked.size()]
	return ""
