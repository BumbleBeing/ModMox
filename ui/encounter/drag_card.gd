class_name DragCard
extends RefCounted
## The Drag Card (game glossary): the card of the Hero's hand that is pressed, held or
## waiting on the Option Menu. It lives on the Encounter Screen, outside the redrawn nodes,
## so the card stays held while the board is rebuilt under it (A380).
##
## A press becomes a hold once the cursor has moved START_DISTANCE, so that a double-click
## never starts a drag. A held card is either over the hand's strip, where the other cards
## leave a gap for it, or above it, where letting go plays it. A card let go above the
## strip with several ways to be played waits where it was released until the Option Menu
## has an answer (A372).

const NONE: int = -1
## How far the cursor moves, in pixels, before a press is a drag.
const START_DISTANCE: float = 3.0

enum State { IDLE, PRESSED, HELD, WAITING }

var _state: State = State.IDLE
var _card_id: int = NONE
var _pressed_at: Vector2 = Vector2.ZERO
var _grab: Vector2 = Vector2.ZERO
var _cursor: Vector2 = Vector2.ZERO
var _is_above: bool = false
var _gap: int = NONE


## The button went down on [param card_id] with the cursor at [param at], which is
## [param grab] from the card's top left corner. Whatever was held before is let go of.
func press(card_id: int, at: Vector2, grab: Vector2) -> void:
	drop()
	_state = State.PRESSED
	_card_id = card_id
	_pressed_at = at
	_grab = grab
	_cursor = at


## The cursor moved to [param at]. Returns true when this is the move that picks the card up.
func move(at: Vector2) -> bool:
	if _state == State.IDLE or _state == State.WAITING:
		return false
	_cursor = at
	if _state == State.PRESSED and at.distance_to(_pressed_at) >= START_DISTANCE:
		_state = State.HELD
		return true
	return false


## The held card is above the hand's strip, or over it at [param gap] among the other
## cards. Returns whether either changed, which is when the hand has to make room again.
func hover(is_above: bool, gap: int) -> bool:
	var has_changed: bool = is_above != _is_above or gap != _gap
	_is_above = is_above
	_gap = gap
	return has_changed


## The held card was let go where it is, to wait there for the Option Menu.
func wait() -> void:
	if _state == State.HELD:
		_state = State.WAITING


## Lets go of everything.
func drop() -> void:
	_state = State.IDLE
	_card_id = NONE
	_gap = NONE
	_is_above = false


## The Card Identity pressed, held or waiting, or NONE.
func card_id() -> int:
	return _card_id


func is_pressed() -> bool:
	return _state == State.PRESSED


func is_holding() -> bool:
	return _state == State.HELD


func is_waiting() -> bool:
	return _state == State.WAITING


## Whether the card is out of the hand's row: held, or waiting on the Option Menu.
func is_lifted() -> bool:
	return _state == State.HELD or _state == State.WAITING


## Where the lifted card's top left corner is drawn: under the cursor, as it was grabbed.
func place() -> Vector2:
	return _cursor - _grab


## Where the cursor was last seen.
func cursor() -> Vector2:
	return _cursor


func is_above() -> bool:
	return _is_above


## Where among the other cards the held card would be put down, or NONE above the strip.
func gap() -> int:
	return _gap


## Whether the row leaves a gap for the card: only while it is held over the strip.
func has_gap() -> bool:
	return _state == State.HELD and not _is_above and _gap != NONE
