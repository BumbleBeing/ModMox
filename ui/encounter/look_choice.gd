class_name LookChoice
extends RefCounted
## The Hero's half-made answer to a look at the top cards of their library (game ADR 0085),
## as Militia Bugler's: the cards still in the Look window's row, top first; the one card
## selected, which only a card that may be taken can be, while fewer than the most have
## been; and the cards taken into the hand, in the order taken. Kept by the Encounter Screen
## outside the nodes it redraws, as a SurveilChoice is, and given with the pass button. Undo
## takes back the last card taken; selecting is not a change of the answer. When the rest go
## to the bottom in any order, as Faerie Mechanist's do (engine ADR 0084's addendum), the row
## is ordered by moving its cards, as a surveil's is, leftmost first and rightmost deepest,
## and undo takes back a move as well.

## No card: nothing is selected, or nothing was taken.
const NONE: int = 0

var _decision: ChooseLookedAtCardsDecision = null
## The object IDs still in the row, top first.
var _row: Array[int] = []
## The object IDs taken into the hand, in the order taken.
var _taken: Array[int] = []
var _picked: int = NONE
## The row and the cards taken before each card was taken or moved, for undo.
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


## Whether the rest go to the bottom in the order of the row, so its cards can be moved.
func orders_rest() -> bool:
	return _decision != null and _decision.orders_rest


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
	_remember()
	var taken_id: int = _picked
	_row.erase(taken_id)
	_taken.append(taken_id)
	_picked = NONE
	return taken_id


func can_undo() -> bool:
	return not _history.is_empty()


## Moves the card at place [param from] in the row to place [param to], the others making
## room, when the rest go in any order: one move, however far it goes. Returns whether
## anything changed.
func move_to(from: int, to: int) -> bool:
	if not orders_rest() or from == to or from < 0 or from >= _row.size() or to < 0 or to >= _row.size():
		return false
	_remember()
	var moved: int = _row[from]
	_row.remove_at(from)
	_row.insert(to, moved)
	return true


## Takes back the last card taken, or the last move. Returns whether there was one.
func undo() -> bool:
	if _history.is_empty():
		return false
	var before: Array = _history.pop_back()
	_row.assign(before[0] as Array)
	_taken.assign(before[1] as Array)
	_picked = NONE
	return true


## The decision's answer (engine ADR 0084): the cards taken, and when the rest go in any
## order, the row after them, leftmost first and rightmost deepest.
func answer() -> Array:
	if orders_rest():
		return [_taken.duplicate(), _row.duplicate()]
	return _taken.duplicate()


func _remember() -> void:
	_history.append([_row.duplicate(), _taken.duplicate()])
