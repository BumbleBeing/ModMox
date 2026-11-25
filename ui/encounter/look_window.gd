class_name LookWindow
extends ZoneWindow
## The Look window (game ADR 0085): the cards a look at the top of the Hero's library shows,
## face up in one row, leftmost on top of the library, as Militia Bugler's, with "Hand" baked
## into the window's bottom edge, centered however it is resized. The cards that may be taken
## glow green, the one selected white, and the rest not at all. A click on a card that may
## be taken selects it, or lets it go; there is no dragging, since the rest go to the bottom
## in a random order. "Hand" is grayed out while nothing is selected. It has no close button.
## It shows a LookChoice and changes nothing itself: what a click or the button means is the
## screen's.

## A card was clicked: it is selected, or let go if it was.
signal card_clicked(object_id: int)
## "Hand" was pressed.
signal hand_pressed

const TINT: Color = StackColors.PLAIN
## The Glow of the card selected, white as a card chosen to discard is (A401).
const PICKED_GLOW: Color = Color.WHITE
const HAND: String = "Hand"
## A unit of space: four pixels at 1080p.
const UNIT: float = 4.0
const HAND_BUTTON: Vector2 = Vector2(50.0 * UNIT, InfoPanel.ROW_HEIGHT)
## How many cards wide it opens, as the Library window does.
const CARDS_WIDE: int = 4

var _row_area: Control
var _button: Button
## The cards in the row, in the order drawn.
var _order: Array[int] = []
var _faces: Dictionary[int, CardFace] = {}
## The card a press began on, so that letting go on it clicks it.
var _pressed: int = LookChoice.NONE
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
	if signature == _shown:
		return
	_shown = signature
	_order = row
	for object_id: int in _faces:
		if is_instance_valid(_faces[object_id]):
			_row_area.remove_child(_faces[object_id])
			_faces[object_id].queue_free()
	_faces.clear()
	for place: int in _order.size():
		var object_id: int = _order[place]
		var face: CardFace = CardFace.new()
		face.setup(looks[object_id], _card_size().y)
		face.position = slot_at(place)
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


## A press on a card and letting go on the same card clicks it.
func _on_row_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_pressed = _card_at(button.position)
	elif _pressed != LookChoice.NONE:
		var released: int = _pressed
		_pressed = LookChoice.NONE
		if _card_at(button.position) == released:
			card_clicked.emit(released)


## The card of the row under [param point], or NONE.
func _card_at(point: Vector2) -> int:
	for object_id: int in _faces:
		var face: CardFace = _faces[object_id]
		if Rect2(face.position, face.size).has_point(point):
			return object_id
	return LookChoice.NONE
