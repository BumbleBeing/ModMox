class_name TriggerList
extends Control
## The triggers being put in order, in the Stack Window (13e-2): one StackEntry for each,
## the top one resolving first, dragged up and down into place (A393, A394). A press on an
## entry becomes a drag after three pixels; the held entry follows the cursor up and down
## inside the list, the others make room, and letting go puts it down there. The entries
## are placed by hand, never by a container, so they ease to their places and nothing is
## rebuilt while one is held.
##
## It holds the order it shows and says when a drag has changed it; the Encounter Screen
## keeps the TriggerOrder that remembers the moves, and follows the mouse while an entry is
## pressed or held.

## A drag moved the trigger at place [param from] to place [param to].
signal moved(from: int, to: int)

## How much of the way to its place an entry goes in a sixtieth of a second.
const EASE: float = 0.3
const HELD: Color = Color(1.35, 1.35, 1.35)

## Each trigger's entry, by trigger number.
var _entries: Array[StackEntry] = []
## Trigger numbers, the one that resolves first at the front.
var _order: Array[int] = []
## The entry pressed or held: a DragCard, whose "card" here is a trigger number.
var _drag: DragCard = DragCard.new()


## [param entries] has each trigger's entry at its trigger number, and [param order] lists
## the numbers from the one that resolves first down.
func _init(entries: Array[StackEntry], order: Array[int]) -> void:
	_entries = entries
	_order = order.duplicate()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for number: int in entries.size():
		entries[number].add_grip()
		entries[number].gui_input.connect(_on_entry_input.bind(number))
		add_child(entries[number])
	resized.connect(place.bind(1.0))


func _ready() -> void:
	custom_minimum_size = Vector2(0, EncounterLayout.trigger_list_height(_entries.size(), entry_height()))
	place(1.0)


func _process(delta: float) -> void:
	place(EncounterLayout.ease_weight(EASE, delta))


## How tall each entry is.
func entry_height() -> float:
	return _entries[0].get_combined_minimum_size().y if not _entries.is_empty() else 0.0


## The trigger numbers, from the one that resolves first down.
func order() -> Array[int]:
	return _order.duplicate()


## Shows [param order]. Nothing is rebuilt: the entries ease to their new places.
func set_order(order: Array[int]) -> void:
	_order = order.duplicate()


## The entries from the top down.
func entries_in_order() -> Array[StackEntry]:
	var found: Array[StackEntry] = []
	for number: int in _order:
		found.append(_entries[number])
	return found


## The entry of trigger [param number].
func entry_of(number: int) -> StackEntry:
	return _entries[number]


## Whether an entry is pressed or held, so the mouse is to be followed wherever it goes.
func is_pressed() -> bool:
	return _drag.is_pressed() or _drag.is_holding()


func is_holding() -> bool:
	return _drag.is_holding()


## The trigger number pressed or held, or DragCard.NONE.
func held_number() -> int:
	return _drag.card_id()


## The left button went down on trigger [param number]'s entry with the cursor at
## [param at], in the list's own coordinates.
func press(number: int, at: Vector2) -> void:
	_drag.press(number, at, at - _entries[number].position)


## The mouse moved to [param at]. Once it has gone far enough the entry is picked up, and
## from then on the others leave a gap where it would be put down.
func drag_to(at: Vector2) -> void:
	_drag.move(at)
	if _drag.is_holding():
		_drag.hover(false, EncounterLayout.trigger_gap(_held_top(), _order.size(), entry_height()))
		place(0.0)


## The left button came up. A held entry is put down where the others made room, which is
## one move however far it went; put down where it was, or never picked up, it is none.
func release() -> void:
	if not _drag.is_holding():
		_drag.drop()
		return
	var from: int = _order.find(_drag.card_id())
	var to: int = _drag.gap()
	_drag.drop()
	if from == to:
		return
	var number: int = _order[from]
	_order.remove_at(from)
	_order.insert(to, number)
	moved.emit(from, to)


## Lets go of the entry without moving it: a right-click.
func cancel() -> void:
	_drag.drop()


## Moves every entry [param weight] of the way to its place. The held one is under the
## cursor at once, drawn over the rest and lit.
func place(weight: float) -> void:
	if _entries.is_empty():
		return
	var height: float = entry_height()
	var slot: int = 0
	for number: int in _order:
		var entry: StackEntry = _entries[number]
		entry.size = Vector2(size.x, height)
		if _drag.is_holding() and number == _drag.card_id():
			continue
		if _drag.is_holding() and slot == _drag.gap():
			slot += 1
		entry.position = entry.position.lerp(Vector2(0, EncounterLayout.trigger_slot(slot, height)), weight)
		entry.z_index = 0
		entry.modulate = Color.WHITE
		slot += 1
	if _drag.is_holding():
		var held: StackEntry = _entries[_drag.card_id()]
		held.position = Vector2(0, _held_top())
		held.z_index = 1
		held.modulate = HELD


func _held_top() -> float:
	return EncounterLayout.trigger_held_top(_drag.cursor().y, _drag.cursor().y - _drag.place().y, _order.size(), entry_height())


func _on_entry_input(event: InputEvent, number: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		press(number, _entries[number].position + click.position)
