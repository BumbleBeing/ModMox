class_name LookWindow
extends ZoneWindow
## The Look window (game ADR 0085): the cards a look at the top of the Hero's library shows,
## face up in one row, leftmost on top of the library, as Militia Bugler's, with "Hand" baked
## into the window's bottom edge, centered however it is resized. The cards that may be taken
## glow green, the one selected white, and the rest not at all. A click on a card that may
## be taken selects it, or lets it go. When the rest go to the bottom in a random order, as
## Militia Bugler's, there is no dragging; when they go in any order, as Faerie Mechanist's
## (engine ADR 0084's addendum), a press moved more than DRAG_START drags a card, and the row
## makes room where it is held, as the Surveil window's does, leftmost first and rightmost
## deepest. "Hand" is grayed out while nothing is selected. It has no close button. It shows
## a LookChoice and changes nothing itself: what a drag, a click or the button means is the
## screen's.

## A card was clicked: it is selected, or let go if it was.
signal card_clicked(object_id: int)
## A card was dragged from place [param from] in the row to place [param to].
signal moved(from: int, to: int)
## "Hand" was pressed.
signal hand_pressed

const TINT: Color = StackColors.PLAIN
## The Glow of the card selected, white as a card chosen to discard is (A401).
const PICKED_GLOW: Color = Color.WHITE
const HAND: String = "Hand"
## How far a press moves before it is a drag, and how much of the way to its place a card
## eases each frame: the Surveil window's.
const DRAG_START: float = SurveilWindow.DRAG_START
const EASE: float = SurveilWindow.EASE
## A unit of space: four pixels at 1080p.
const UNIT: float = 4.0
const HAND_BUTTON: Vector2 = Vector2(50.0 * UNIT, InfoPanel.ROW_HEIGHT)
## How many cards wide it opens, as the Library window does.
const CARDS_WIDE: int = 4

var _row_area: Control
var _button: Button
## The cards in the row, in the order drawn: the choice's, or a drag's while one is held.
var _order: Array[int] = []
var _faces: Dictionary[int, CardFace] = {}
## Whether the row may be ordered by dragging.
var _orders_rest: bool = false
## The card a press began on, so that letting go on it clicks it; where the press was, where
## on the card, its place when pressed, and whether the press has become a drag.
var _pressed: int = LookChoice.NONE
var _press_at: Vector2 = Vector2.ZERO
var _grab_offset: Vector2 = Vector2.ZERO
var _held_from: int = -1
var _is_dragging_card: bool = false
## What was last shown, so that a redraw that changes nothing rebuilds nothing.
var _shown: String = ""


## How big it opens: four cards wide, with Hand in its bottom edge.
static func opening_size() -> Vector2:
	return ZoneWindow.size_around(_inner_size(), HAND_BUTTON.y)


## The size of the row.
static func _inner_size() -> Vector2:
	var card: Vector2 = _card_size()
	var room: float = PileWindow.GLOW_ROOM
	return Vector2(CARDS_WIDE * card.x + (CARDS_WIDE - 1) * PileWindow.GAP + room * 2.0, card.y + room * 2.0)


static func _card_size() -> Vector2:
	return Vector2(PileWindow.CARD_HEIGHT * CardGeometry.ASPECT, PileWindow.CARD_HEIGHT)


func _init() -> void:
	super("Look", false, TINT)
	size = opening_size()
	_row_area = Control.new()
	_row_area.custom_minimum_size = _inner_size()
	_row_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_row_area.gui_input.connect(_on_row_input)
	body().add_child(_row_area)
	_button = Button.new()
	_button.text = HAND
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", InfoPanel.BUTTON_FONT + UiText.RAISE)
	_button.disabled = true
	_button.pressed.connect(func() -> void: hand_pressed.emit())
	bake_button(_button, HAND_BUTTON)
	SteelFrame.apply(_button, InfoPanel.BUTTON)


## Shows [param choice], each card drawn from [param looks] by object ID: its title, its row
## in order, how each card glows and whether Hand can be pressed.
func show_choice(choice: LookChoice, looks: Dictionary[int, CardLook]) -> void:
	show_title("Look at %d" % choice.count())
	var row: Array[int] = choice.row()
	var may_pick: Array[int] = []
	for object_id: int in row:
		if choice.can_pick(object_id):
			may_pick.append(object_id)
	var signature: String = "%s %d %s" % [row, choice.picked(), may_pick]
	if signature == _shown and not _is_dragging_card:
		return
	_shown = signature
	_orders_rest = choice.orders_rest()
	_pressed = LookChoice.NONE
	_is_dragging_card = false
	_order = row
	var was_at: Dictionary[int, Vector2] = {}
	for object_id: int in _faces:
		if is_instance_valid(_faces[object_id]):
			was_at[object_id] = _faces[object_id].position
			_row_area.remove_child(_faces[object_id])
			_faces[object_id].queue_free()
	_faces.clear()
	for place: int in _order.size():
		var object_id: int = _order[place]
		var face: CardFace = CardFace.new()
		face.setup(looks[object_id], _card_size().y)
		face.position = was_at.get(object_id, slot_at(place))
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row_area.add_child(face)
		if object_id == choice.picked():
			BorderEffects.add_glow(face, face.size, PICKED_GLOW)
		elif may_pick.has(object_id):
			BorderEffects.add_glow(face, face.size, DecisionClicks.color_of(DecisionClicks.Kind.OTHER))
		_faces[object_id] = face
	_button.disabled = choice.picked() == LookChoice.NONE


## Forgets what it showed, so the next choice is drawn afresh.
func forget() -> void:
	_shown = ""


## The cards in the row, in the order drawn.
func entries() -> Array[int]:
	return _order.duplicate()


## The face of [param object_id] in the row, or null.
func face_of(object_id: int) -> CardFace:
	return _faces.get(object_id, null) as CardFace


func hand_button() -> Button:
	return _button


## Where the card at [param place] in the row rests, in the row's own coordinates.
func slot_at(place: int) -> Vector2:
	return Vector2(PileWindow.GLOW_ROOM + place * (_card_size().x + PileWindow.GAP), PileWindow.GLOW_ROOM)


## The middle of the place [param place] in the row, on the screen.
func slot_center(place: int) -> Vector2:
	return _row_area.get_global_transform() * (slot_at(place) + _card_size() / 2.0)


## Every card but the one dragged eases toward its place.
func _process(_delta: float) -> void:
	for place: int in _order.size():
		var object_id: int = _order[place]
		if (object_id == _pressed and _is_dragging_card) or not _faces.has(object_id):
			continue
		var face: CardFace = _faces[object_id]
		face.position = face.position.lerp(slot_at(place), EASE)


## A press on a card and letting go on the same card clicks it. When the row may be ordered,
## moving the press more than DRAG_START drags the card instead, the row making room where
## it is, and letting go says where it went.
func _on_row_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_pressed = _card_at(button.position)
			if _pressed != LookChoice.NONE:
				_press_at = button.position
				_grab_offset = button.position - _faces[_pressed].position
				_held_from = _order.find(_pressed)
				_is_dragging_card = false
				_row_area.move_child(_faces[_pressed], -1)
		elif _pressed != LookChoice.NONE:
			var released: int = _pressed
			var was_drag: bool = _is_dragging_card
			_pressed = LookChoice.NONE
			_is_dragging_card = false
			if not was_drag:
				if _card_at(button.position) == released:
					card_clicked.emit(released)
			elif _order.find(released) != _held_from:
				_shown = ""
				moved.emit(_held_from, _order.find(released))
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _pressed != LookChoice.NONE and _orders_rest:
		if not _is_dragging_card and motion.position.distance_to(_press_at) > DRAG_START:
			_is_dragging_card = true
		if _is_dragging_card:
			_drag_to(motion.position - _grab_offset)


## Holds the dragged card at [param at], and moves it in the row to the nearest place.
func _drag_to(at: Vector2) -> void:
	_faces[_pressed].position = at
	var step: float = _card_size().x + PileWindow.GAP
	var place: int = clampi(roundi((at.x - PileWindow.GLOW_ROOM) / step), 0, _order.size() - 1)
	if _order.find(_pressed) != place:
		_order.erase(_pressed)
		_order.insert(place, _pressed)


## The card of the row under [param point], the one drawn on top first, or NONE.
func _card_at(point: Vector2) -> int:
	for index: int in range(_row_area.get_child_count() - 1, -1, -1):
		var child: Node = _row_area.get_child(index)
		for object_id: int in _faces:
			var face: CardFace = _faces[object_id]
			if face == child and Rect2(face.position, face.size).has_point(point):
				return object_id
	return LookChoice.NONE
