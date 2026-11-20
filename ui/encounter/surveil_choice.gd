class_name SurveilChoice
extends RefCounted
## The Hero's half-made answer to a surveil (game ADR 0069): the cards still in the Surveil
## window's row, leftmost on top, ordered by dragging; the one card selected; and the cards
## sent to the graveyard, in the order sent. Kept by the Encounter Screen outside the nodes
## it redraws, as a TriggerOrder is, and given with the pass button. Undo takes back the last
## move or sending, one at a time; selecting is not a change of the answer.

## No card: nothing is selected, or nothing was sent.
const NONE: int = 0

var _decision: SurveilDecision = null
## The object IDs still in the row, the one that goes on top first.
var _row: Array[int] = []
## The object IDs sent to the graveyard, in the order sent.
var _sent: Array[int] = []
var _picked: int = NONE
## The row and the cards sent before each change, for undo.
var _history: Array = []


## Whether [param decision] is answered by a SurveilChoice.
static func covers(decision: MmPendingDecision) -> bool:
	return decision is SurveilDecision


func _init(decision: MmPendingDecision = null) -> void:
	_decision = decision as SurveilDecision
	if _decision != null:
		_row = _decision.card_ids.duplicate()


## Whether this is the choice being made for [param decision]: a new decision needs a new one.
func is_for(decision: MmPendingDecision) -> bool:
	return _decision == decision


func is_active() -> bool:
	return _decision != null


## How many cards are surveilled, the number in the window's title.
func count() -> int:
	return 0 if _decision == null else _decision.card_ids.size()


## The cards still in the row, the one that goes on top first.
func row() -> Array[int]:
	return _row.duplicate()


## The cards sent to the graveyard, in the order sent.
func sent() -> Array[int]:
	return _sent.duplicate()


## The card selected, or NONE.
func picked() -> int:
	return _picked


## Selects [param object_id], or lets it go if it is selected already.
func pick(object_id: int) -> void:
	if _row.has(object_id):
		_picked = NONE if _picked == object_id else object_id


## Moves the card at place [param from] to place [param to], the others making room: one
## move, however far it goes. Returns whether anything changed.
func move_to(from: int, to: int) -> bool:
	if from == to or from < 0 or from >= _row.size() or to < 0 or to >= _row.size():
		return false
	_remember()
	var moved: int = _row[from]
	_row.remove_at(from)
	_row.insert(to, moved)
	return true


## Sends the selected card to the graveyard. Returns it, or NONE with nothing selected.
func send_picked() -> int:
	if _picked == NONE:
		return NONE
	_remember()
	var sent_id: int = _picked
	_row.erase(sent_id)
	_sent.append(sent_id)
	_picked = NONE
	return sent_id


func can_undo() -> bool:
	return not _history.is_empty()


## Takes back the last move or sending. Returns whether there was one.
func undo() -> bool:
	if _history.is_empty():
		return false
	var before: Array = _history.pop_back()
	_row.assign(before[0] as Array)
	_sent.assign(before[1] as Array)
	_picked = NONE
	return true


## The decision's answer (engine ADR 0068): the cards sent, in the order sent, then the row.
func answer() -> Array:
	return [_sent.duplicate(), _row.duplicate()]


func _remember() -> void:
	_history.append([_row.duplicate(), _sent.duplicate()])
