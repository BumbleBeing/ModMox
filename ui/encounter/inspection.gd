class_name Inspection
extends RefCounted
## Which card the Inspector shows (13h, ADR 0033): the Pinned card, which a right-click
## pins. Hovering shows nothing: an Inspector that followed the cursor was too busy to look
## at while mousing over the hand (A472). The screen keeps one of these outside the nodes
## it redraws and tells it of right-clicks.

## No card: object IDs start above this.
const NOTHING: int = 0

var _pinned: int = NOTHING
var _is_dragging: bool = false


## A right-click on the card [param object_id], or on NOTHING: it pins that card, and on
## the Pinned card or on nothing lets the Pinned card go. While something is dragged a
## right-click puts it down and means nothing here.
func right_click(object_id: int) -> void:
	if _is_dragging:
		return
	_pinned = NOTHING if object_id == _pinned else object_id


## Lets the Pinned card go.
func let_go() -> void:
	_pinned = NOTHING


## Whether a card or a trigger is being dragged.
func set_dragging(is_dragging: bool) -> void:
	_is_dragging = is_dragging


## Forgets the Pinned card if it is not among [param object_ids], the cards that can still
## be seen.
func keep_only(object_ids: Array[int]) -> void:
	if not object_ids.has(_pinned):
		_pinned = NOTHING


## The card to show, or NOTHING: the Pinned card.
func shown() -> int:
	return _pinned


func pinned() -> int:
	return _pinned
