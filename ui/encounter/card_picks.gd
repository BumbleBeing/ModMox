class_name CardPicks
extends RefCounted
## The Hero's half-made answer to a decision that chooses cards from their hand (13e-2):
## which to put on the bottom after keeping, or which to discard; or permanents on the
## battlefield, such as creatures to tap for a cost (ChoosePermanentsDecision); or up to
## some number of cards in the Hero's library, found by a search (ChooseCardsInLibraryDecision,
## game ADR 0058), any number of which up to that answers; or up to some number of target
## permanents (ChooseTargetsDecision, game ADR 0022), any number of which up to that
## answers too. Cards are picked one
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
	return decision is ChooseCardsToBottomDecision or decision is ChooseCardsToDiscardDecision \
		or decision is ChoosePermanentsDecision or decision is ChooseCardsInLibraryDecision \
		or decision is ChooseTargetsDecision


func _init(decision: MmPendingDecision = null) -> void:
	if decision is ChooseCardsToBottomDecision:
		_decision = decision
		_candidates = (decision as ChooseCardsToBottomDecision).candidate_ids.duplicate()
		_count = (decision as ChooseCardsToBottomDecision).count
	elif decision is ChooseCardsToDiscardDecision:
		_decision = decision
		_candidates = (decision as ChooseCardsToDiscardDecision).candidate_ids.duplicate()
		_count = (decision as ChooseCardsToDiscardDecision).count
	elif decision is ChoosePermanentsDecision:
		_decision = decision
		_candidates = (decision as ChoosePermanentsDecision).candidate_ids.duplicate()
		_count = (decision as ChoosePermanentsDecision).count
	elif decision is ChooseCardsInLibraryDecision:
		_decision = decision
		_candidates = (decision as ChooseCardsInLibraryDecision).candidate_ids.duplicate()
		_count = (decision as ChooseCardsInLibraryDecision).most
	elif decision is ChooseTargetsDecision:
		_decision = decision
		for candidate: MmReference in (decision as ChooseTargetsDecision).candidates:
			_candidates.append(candidate.id)
		_count = (decision as ChooseTargetsDecision).most


## Whether these are the picks being made for [param decision]: a new decision needs new ones.
func is_for(decision: MmPendingDecision) -> bool:
	return _decision == decision


func is_active() -> bool:
	return _decision != null


func is_bottoming() -> bool:
	return _decision is ChooseCardsToBottomDecision


func is_discarding() -> bool:
	return _decision is ChooseCardsToDiscardDecision


## Whether the picks are cards found by a search, clicked in the Hero's Library window.
func is_searching() -> bool:
	return _decision is ChooseCardsInLibraryDecision


## Whether the picks are permanents on the battlefield, clicked there.
func is_picking_permanents() -> bool:
	return _decision is ChoosePermanentsDecision


## Whether the picks are "up to" some number of target permanents, clicked on the battlefield.
func is_targeting() -> bool:
	return _decision is ChooseTargetsDecision


## Whether the picks are permanents clicked on the battlefield: to pay a cost, or targets.
func is_picking_on_battlefield() -> bool:
	return is_picking_permanents() or is_targeting()


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


## Whether [param object_id] is one of what may be picked.
func is_candidate(object_id: int) -> bool:
	return _candidates.has(object_id)


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


## Whether the picks answer: as many as asked for, or for a search or targets any number up
## to that.
func is_complete() -> bool:
	if is_searching() or is_targeting():
		return _picked.size() <= _count
	return is_active() and _picked.size() == _count


## What confirming a search does, on the pass button: "Find nothing", "Find Forest" or
## "Find 2 cards" (game ADR 0058). [param view] names the card.
func search_confirm_text(view: MmPlayerView) -> String:
	if _picked.is_empty():
		return "Find nothing"
	if _picked.size() == 1:
		return "Find " + EncounterSnapshot.name_in(view, _picked[0])
	return "Find %d cards" % _picked.size()


## What confirming targets does, on the pass button: "No targets" with none picked, and
## otherwise "Confirm targets".
func targets_confirm_text() -> String:
	return "No targets" if _picked.is_empty() else "Confirm targets"


## The decision's answer: the picked cards' IDs, in the order picked; for targets, their
## places among the decision's candidates.
func answer() -> Array:
	var ids: Array = []
	if is_targeting():
		for id: int in _picked:
			ids.append(_candidates.find(id))
		return ids
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
