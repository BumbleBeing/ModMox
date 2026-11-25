class_name LookChoice
extends RefCounted
## The Hero's half-made answer to a look at the top cards of their library (game ADR 0085),
## as Militia Bugler's: the cards still in the Look window's row, top first; the one card
## selected, which only a card that may be taken can be, while fewer than the most have
## been; and the cards taken into the hand, in the order taken. Kept by the Encounter Screen
## outside the nodes it redraws, as a SurveilChoice is, and given with the pass button. Undo
## takes back the last card taken; selecting is not a change of the answer.

## No card: nothing is selected, or nothing was taken.
const NONE: int = 0

var _decision: ChooseLookedAtCardsDecision = null
## The object IDs still in the row, top first.
var _row: Array[int] = []
## The object IDs taken into the hand, in the order taken.
var _taken: Array[int] = []
var _picked: int = NONE
## The row before each card was taken, for undo.
var _history: Array = []


## Whether [param decision] is answered by a LookChoice.
static func covers(decision: MmPendingDecision) -> bool:
	return decision is ChooseLookedAtCardsDecision


func _init(decision: MmPendingDecision = null) -> void:
	_decision = decision as ChooseLookedAtCardsDecision
	if _decision != null:
		_row = _decision.card_ids.duplicate()


## Whether this is the choice being made for [param decision]: a new decision needs a new one.
func is_for(decision: MmPendingDecision) -> bool:
	return _decision == decision


func is_active() -> bool:
	return _decision != null


## How many cards are looked at, the number in the window's title.
func count() -> int:
	return 0 if _decision == null else _decision.card_ids.size()


## The cards still in the row, top first.
func row() -> Array[int]:
	return _row.duplicate()


## The cards taken into the hand, in the order taken.
func taken() -> Array[int]:
	return _taken.duplicate()


## The card selected, or NONE.
func picked() -> int:
	return _picked


## Whether [param object_id] may be selected: a card in the row that may be taken, while
## fewer than the most have been.
func can_pick(object_id: int) -> bool:
	return _decision != null and _row.has(object_id) and _decision.candidate_ids.has(object_id) \
		and _taken.size() < _decision.most


## Selects [param object_id], or lets it go if it is selected already.
func pick(object_id: int) -> void:
	if _picked == object_id:
		_picked = NONE
	elif can_pick(object_id):
		_picked = object_id


## Takes the selected card into the hand. Returns it, or NONE with nothing selected.
func take_picked() -> int:
	if _picked == NONE:
		return NONE
	_history.append(_row.duplicate())
	var taken_id: int = _picked
	_row.erase(taken_id)
	_taken.append(taken_id)
	_picked = NONE
	return taken_id


func can_undo() -> bool:
	return not _history.is_empty()


## Takes back the last card taken. Returns whether there was one.
func undo() -> bool:
	if _history.is_empty():
		return false
	_row.assign(_history.pop_back() as Array)
	_taken.pop_back()
	_picked = NONE
	return true


## The decision's answer (engine ADR 0084): the cards taken.
func answer() -> Array:
	return _taken.duplicate()
