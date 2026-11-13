class_name OpeningHandOverlay
extends Control
## The opening-hand overlay (game glossary): a scrim over everything right of the sidebar
## through the pregame, with the Hero's hand drawn large on it, a heading above and buttons
## below (13e-2). It draws what an OpeningHand says and reports what is pressed; the
## Encounter Screen answers. Its contents are rebuilt on every redraw.
##
## The hand is fanned as it is in play: each card turned a little more than the last, their
## bottom corners overlapping. The card under the cursor glows white, comes to the front,
## eases upright, rises and grows a little, so it can be read. While cards are being put on
## the bottom, the ones that can still go glow green and take a click, and a card put down
## leaves the row.
##
## The cards move (OpeningMotion): a new hand is dealt from the library a card at a time, a
## card that leaves the row goes back there, the row eases closed and open, and when the
## pregame ends the hand flies down to its strip. Each card is placed every frame from where
## its move has got to, the card under the cursor a little higher and larger than that.
## While any card is in the air the cursor is on no card and a click chooses none; the
## buttons still work.
##
## The cards ignore the mouse. The overlay takes it and works out which card the cursor is
## on from where each is drawn, turned as it is: the card already under the cursor first,
## since it is in front, then whichever lies on top. Godot's own picking goes by the order
## of the nodes, which bringing a card to the front does not change.

## A button that answers the decision outright was pressed: play or draw, keep or mulligan.
signal answered(answer: int)
## A card that can be put on the bottom was clicked.
signal card_clicked(object_id: int)
## The button that confirms the cards put on the bottom was pressed.
signal confirmed
## The overlay has gone: it finished fading out, or was taken away at once.
signal closed

const SCRIM: Color = Color(0.03, 0.04, 0.06, 0.88)
const VILLAIN_COLOR: Color = Color(1, 0.86, 0.55)
## Keep is shaded blue and Mulligan burnt orange, playing first or drawing a blue-gray, and
## Confirm green (ButtonShading).
const KEEP_COLOR: Color = Color(0.17, 0.36, 0.66)
const MULLIGAN_COLOR: Color = Color(0.72, 0.33, 0.09)
const CHOICE_COLOR: Color = Color(0.29, 0.36, 0.47)
const CONFIRM_COLOR: Color = Color(0.16, 0.5, 0.27)
const NONE: int = -1
## How much of the way to its turn, and to its rise, a card goes in a sixtieth of a second.
const EASE: float = 0.3
## How far the card under the cursor rises, as a share of its height, and how much larger
## it is drawn.
const HOVER_RISE: float = 0.1
const HOVER_GROW: float = 0.06
## The share of the overlay's width a card flies in the whole of a flight's time: about as
## far as the library is from the far end of a full row. A shorter trip is quicker.
const FULL_FLIGHT: float = 0.7

## How long a Glow takes to ease in or out; the Encounter Screen sets it.
var glow_seconds: float = 0.0
## Through show_frame(), the color each card glowed before, so a redraw does not ease in
## again a Glow that has not changed.
var _glowed_before: Dictionary[int, Color] = {}
var _is_drawing: bool = false
var _heading: Label = null
var _under_heading: Label = null
var _villain: Label = null
var _buttons: Dictionary[String, Button] = {}
var _row: Control = null
var _faces: Dictionary[int, CardFace] = {}
var _shown: Array[int] = []
var _fade: Tween = null
var _is_closing: bool = false
## How far each card of the row is turned in the fan, and whether it can be put on the
## bottom, by Game Object ID.
var _turns: Dictionary[int, float] = {}
var _can_go_down: Dictionary[int, bool] = {}
## The card the cursor is on, and where the cursor was last seen while it was over the
## overlay, so a redraw can find the card under a cursor that has not moved.
var _hovered: int = NONE
var _cursor: Vector2 = Vector2.ZERO
var _has_cursor: bool = false
var _motion: OpeningMotion = OpeningMotion.new()
## What each card was last drawn from, for one that is drawn on its way out of the row.
var _looks: Dictionary[int, CardLook] = {}
## The height each card's face was built at; its pose scales it from there.
var _built: Dictionary[int, float] = {}
## Where the layout put each card of the row.
var _homes: Dictionary[int, Vector2] = {}
## How far each card has risen under the cursor, 0 to 1, and how it was last turned. They
## outlive a redraw only while the cards move, so that a card does not jump.
var _lifts: Dictionary[int, float] = {}
var _rotations: Dictionary[int, float] = {}
## The cards on their way out of the row, and the card backs over cards that are turning.
var _leaving: Dictionary[int, CardFace] = {}
var _backs: Dictionary[int, Control] = {}
## The cards flying to the hand's strip as the overlay goes.
var _landing: Dictionary[int, bool] = {}


func _init() -> void:
	# A Control stops the mouse unless told otherwise, which is what a scrim is for.
	hide()


func _process(delta: float) -> void:
	follow_cursor()
	advance(delta)
	ease_cards(EncounterLayout.ease_weight(EASE, delta))


## How the cards move. Its times are the Encounter Screen's to set; with none, as in a
## test, every card is simply at its place.
func motion() -> OpeningMotion:
	return _motion


## Lets a frame of [param delta] seconds go by for the cards that are moving.
func advance(delta: float) -> void:
	if not visible:
		return
	var was_moving: bool = _motion.is_moving()
	_motion.advance(delta)
	if was_moving:
		_pose_cards()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click_at(click.position)


## Draws [param opening]'s frame over [param area]: the cards of [param snapshot]'s hand in
## the order of [param cards] (Card Identities), less those [param picks] has put on the
## bottom. [param library] is where the Hero's library is drawn on the screen: a hand the
## Hero has not seen is dealt from there, and a card that leaves the row goes back to it.
## Given none, cards neither come nor go.
func show_frame(opening: OpeningHand, snapshot: EncounterSnapshot, picks: CardPicks, cards: Array[int], area: Rect2,
		library: Rect2 = Rect2()) -> void:
	_glowed_before.clear()
	for object_id: int in _faces:
		if BorderEffects.glow_color(_faces[object_id]) != null:
			_glowed_before[object_id] = BorderEffects.glow_color(_faces[object_id])
	_is_drawing = true
	var is_keeping_poise: bool = _motion.seconds > 0.0
	var lifts: Dictionary[int, float] = _lifts.duplicate() if is_keeping_poise else ({} as Dictionary[int, float])
	var rotations: Dictionary[int, float] = _rotations.duplicate() if is_keeping_poise else ({} as Dictionary[int, float])
	_clear()
	_stop_fade()
	_is_closing = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 1.0
	position = area.position
	size = area.size
	show()
	var inside: Rect2 = Rect2(Vector2.ZERO, area.size)
	var unit: float = area.size.y / EncounterLayout.DESIGN_HEIGHT
	var scrim: ColorRect = ColorRect.new()
	scrim.color = SCRIM
	scrim.size = area.size
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var hand: Array[MmObjectView] = []
	for card_id: int in cards:
		for seen: MmObjectView in snapshot.view.hand:
			if seen.card_id == card_id and not picks.is_picked(seen.id):
				hand.append(seen)
	var dealt: int = snapshot.view.hand.size()
	var places: Array[Rect2] = EncounterLayout.opening_hand_cards(dealt, hand.size(), inside)
	var turns: Array[float] = EncounterLayout.opening_hand_turns(dealt, hand.size())
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	var targets: Dictionary[int, FacePose] = {}
	for index: int in hand.size():
		_add_card(hand[index], snapshot.look_of(hand[index].id), places[index], turns[index], picks.can_pick(hand[index].id))
		targets[hand[index].id] = FacePose.of(places[index].position + Vector2(places[index].size.x / 2.0, places[index].size.y),
				places[index].size.y, turns[index])
	# A409: a mulligan is seen to happen, even into a hand much like the last.
	_motion.full_distance = area.size.x * FULL_FLIGHT
	_motion.show_cards(targets, _library_pose(library, area), opening.is_new_hand())
	for object_id: int in _shown:
		_lifts[object_id] = lifts.get(object_id, 0.0)
		_faces[object_id].rotation = rotations.get(object_id, _motion.pose_of(object_id).turn)
		if _motion.face_of(object_id) < 1.0:
			_backs[object_id] = _add_back(_faces[object_id])
	for object_id: int in _motion.leaving_ids():
		_add_leaving(object_id)
	for object_id: int in _looks.keys():
		if not _faces.has(object_id) and not _leaving.has(object_id):
			_looks.erase(object_id)
			_built.erase(object_id)
	_pose_cards()

	var parts: Dictionary[String, Rect2] = EncounterLayout.opening_hand(dealt, inside)
	_heading = _label(opening.heading(), parts["heading"], 34.0 * unit, Color.WHITE)
	_under_heading = _label(opening.under_heading(), parts["under_heading"], 21.0 * unit, Color(1, 1, 1, 0.7))
	_villain = _label(opening.villain_text(), parts["villain"], 21.0 * unit, VILLAIN_COLOR)
	match opening.frame():
		OpeningHand.Frame.PLAY_OR_DRAW:
			_add_pair(parts["middle"], unit, "Play first", ChoosePlayOrDrawDecision.Choice.PLAY, "Draw first", ChoosePlayOrDrawDecision.Choice.DRAW)
			ButtonShading.apply(_buttons["Play first"], CHOICE_COLOR)
			ButtonShading.apply(_buttons["Draw first"], CHOICE_COLOR)
		OpeningHand.Frame.KEEP_OR_MULLIGAN:
			_add_pair(parts["buttons"], unit, opening.keep_text(), KeepOrMulliganDecision.Choice.KEEP,
					opening.mulligan_text(), KeepOrMulliganDecision.Choice.MULLIGAN)
			ButtonShading.apply(_buttons[opening.keep_text()], KEEP_COLOR)
			ButtonShading.apply(_buttons[opening.mulligan_text()], MULLIGAN_COLOR)
		OpeningHand.Frame.BOTTOM:
			var button_size: Vector2 = EncounterLayout.OPENING_BUTTON * unit
			var confirm: Button = _button("Confirm", Rect2(parts["buttons"].get_center() - button_size / 2.0, button_size),
					func() -> void: confirmed.emit())
			confirm.disabled = not picks.is_complete()
			ButtonShading.apply(confirm, CONFIRM_COLOR)
	if _has_cursor:
		# The cursor may be resting where another card now is.
		hover_at(_cursor)
	_is_drawing = false
	_glowed_before.clear()


## Takes the overlay away, over [param fade_seconds]. While it fades it takes no clicks.
## Each card that [param hand] names flies to its pose there meanwhile, in the screen's own
## coordinates: its place in the hand's strip, which shows nothing of it until it lands
## (is_landing). The scrim, the words and the buttons fade around the cards.
func close(fade_seconds: float, hand: Dictionary[int, FacePose] = {}) -> void:
	if not visible or _is_closing:
		return
	if fade_seconds <= 0.0:
		_stop_fade()
		_finish_closing()
		return
	stop_hovering()
	_is_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in get_children():
		_ignore_mouse(child)
	_stop_fade()
	_fade = create_tween()
	var strip: Dictionary[int, FacePose] = {}
	if _motion.seconds > 0.0:
		for object_id: int in hand:
			if _faces.has(object_id):
				var pose: FacePose = hand[object_id]
				strip[object_id] = FacePose.of(pose.center - position, pose.height, pose.turn)
				_landing[object_id] = true
	if strip.is_empty():
		_fade.tween_property(self, "modulate:a", 0.0, fade_seconds)
	else:
		_motion.move_to(strip)
		_fade.set_parallel(true)
		for fading: CanvasItem in _all_but_landing():
			_fade.tween_property(fading, "modulate:a", 0.0, fade_seconds)
		# The overlay stays until the last card is down.
		_fade.tween_interval(maxf(fade_seconds, _motion.seconds))
		_fade.set_parallel(false)
	_fade.tween_callback(_finish_closing)


## Whether the card that is Game Object [param object_id] is flying to the hand's strip as
## the overlay goes, so that the strip does not show it yet.
func is_landing(object_id: int) -> bool:
	return _is_closing and _landing.has(object_id)


## Whether it is up and taking input: not hidden, and not fading away.
func is_open() -> bool:
	return visible and not _is_closing


func is_closing() -> bool:
	return _is_closing


## The scrim, and the three lines of words, for a test to see where each was put.
func scrim() -> ColorRect:
	return get_child(0) as ColorRect if get_child_count() > 0 else null


func heading_label() -> Label:
	return _heading


func under_heading_label() -> Label:
	return _under_heading


func villain_label() -> Label:
	return _villain


func heading_text() -> String:
	return _heading.text if _heading != null else ""


func under_heading_text() -> String:
	return _under_heading.text if _under_heading != null else ""


func villain_text() -> String:
	return _villain.text if _villain != null else ""


## The button that reads [param text], or null if this frame has none.
func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


## What every button of this frame reads, from the left.
func button_texts() -> Array[String]:
	var texts: Array[String] = []
	texts.assign(_buttons.keys())
	return texts


## The Game Object IDs of the cards in the row, in the order drawn.
func shown_ids() -> Array[int]:
	return _shown.duplicate()


## The face of the card in the row that is Game Object [param object_id], or null.
func face_of(object_id: int) -> CardFace:
	return _faces.get(object_id, null) as CardFace


## The row the cards are children of, which fades in with a new hand.
func row() -> Control:
	return _row


## Whether the card in the row that is Game Object [param object_id] takes a click, to be
## put on the bottom.
func can_go_down(object_id: int) -> bool:
	return _can_go_down.get(object_id, false)


## The middle of the card that is Game Object [param object_id], where it is drawn.
func center_of(object_id: int) -> Vector2:
	var face: CardFace = _faces[object_id]
	return face.get_transform() * (face.size / 2.0)


## The card of the row drawn at [param point], as a Game Object ID, or NONE. The card the
## cursor is already on comes first, because it is in front; otherwise it is the one that
## lies on top there.
func card_at(point: Vector2) -> int:
	if _hovered != NONE and _is_on(_hovered, point):
		return _hovered
	for index: int in range(_shown.size() - 1, -1, -1):
		if _is_on(_shown[index], point):
			return _shown[index]
	return NONE


## The card the cursor is on, or NONE.
func hovered_id() -> int:
	return _hovered


## The cursor is at [param point]: the card there glows white and comes to the front, and
## eases upright from then on. The card it left goes back into the fan.
func hover_at(point: Vector2) -> void:
	if not is_open():
		return
	_cursor = point
	_has_cursor = true
	# While cards are in the air none of them answers to the mouse.
	_hover(NONE if _motion.is_moving() else card_at(point))


## Looks at where the cursor is, every frame: on the overlay itself it is over the cards or
## the scrim between them, and anywhere else (a button, a window over the scrim, the
## sidebar) it is on no card. Asked for each frame, not taken from the mouse's moves, so a
## card that comes under a resting cursor is found too.
func follow_cursor() -> void:
	if not is_open() or not is_inside_tree():
		return
	if get_viewport().gui_get_hovered_control() == self:
		hover_at(get_local_mouse_position())
	elif _has_cursor:
		stop_hovering()


## The cursor has left the cards: for a button, or for the sidebar.
func stop_hovering() -> void:
	_has_cursor = false
	_hover(NONE)


## The left button went down at [param point]. On a card that can be put on the bottom,
## that card was clicked.
func click_at(point: Vector2) -> void:
	hover_at(point)
	if _hovered != NONE and can_go_down(_hovered):
		card_clicked.emit(_hovered)


## Turns every card [param weight] of the way to where it belongs: upright under the
## cursor, risen and a little larger, and otherwise as the fan has it. A card in the air is
## turned exactly as its flight has it, so it lands already turned.
func ease_cards(weight: float) -> void:
	for object_id: int in _shown:
		var is_hovered: bool = object_id == _hovered
		var pose: FacePose = _motion.pose_of(object_id)
		var wanted: float = 0.0 if is_hovered else (pose.turn if pose != null else _turns[object_id])
		if _motion.is_flying(object_id):
			_faces[object_id].rotation = wanted
		else:
			_faces[object_id].rotation = lerp_angle(_faces[object_id].rotation, wanted, weight)
		_rotations[object_id] = _faces[object_id].rotation
		_lifts[object_id] = lerpf(_lifts.get(object_id, 0.0), 1.0 if is_hovered else 0.0, weight)
	_pose_cards()


## How far the card that is Game Object [param object_id] has risen under the cursor: 0 in
## the fan, 1 fully risen.
func lift_of(object_id: int) -> float:
	return _lifts.get(object_id, 0.0)


## The card back over the card that is Game Object [param object_id] while it turns over, in
## the row or on its way out of it, or null once its face is all that shows.
func back_of(object_id: int) -> Control:
	return _backs.get(object_id, null) as Control


## The face of a card on its way out of the row, or null once it has gone.
func leaving_face_of(object_id: int) -> CardFace:
	return _leaving.get(object_id, null) as CardFace


## Places every card where its move has got to: the cards of the row, the one under the
## cursor higher and larger, and the cards on their way out, which go when they arrive.
func _pose_cards() -> void:
	for object_id: int in _shown:
		var pose: FacePose = _motion.pose_of(object_id)
		if pose == null:
			continue
		var lift: float = _lifts.get(object_id, 0.0)
		_place(_faces[object_id], object_id, pose, lift)
		if _motion.face_of(object_id) >= 1.0 and _backs.has(object_id):
			_backs[object_id].queue_free()
			_backs.erase(object_id)
		_show_back(object_id, _motion.face_of(object_id))
	for object_id: int in _leaving.keys():
		var pose: FacePose = _motion.leaving_pose(object_id)
		if pose == null:
			_backs.erase(object_id)
			_leaving[object_id].queue_free()
			_leaving.erase(object_id)
			continue
		_place(_leaving[object_id], object_id, pose, 0.0)
		_leaving[object_id].rotation = pose.turn
		_show_back(object_id, _motion.leaving_face(object_id))


## Puts [param face] at [param pose], whose center is the middle of the card's bottom edge,
## risen and grown by [param lift].
func _place(face: CardFace, object_id: int, pose: FacePose, lift: float) -> void:
	var built: float = _built.get(object_id, face.size.y)
	face.scale = Vector2.ONE * (pose.height / built) * (1.0 + HOVER_GROW * lift)
	var at: Vector2 = pose.center - face.pivot_offset - Vector2(0, pose.height * HOVER_RISE * lift)
	# At rest it is exactly where the layout put it, not a rounding away from there.
	var home: Vector2 = _homes.get(object_id, at)
	face.position = home if at.is_equal_approx(home) else at
	face.modulate.a = pose.alpha


## Shows as much of a card's back as it has still to turn: solid until half-way, then
## fading from its face.
func _show_back(object_id: int, face_up: float) -> void:
	if not _backs.has(object_id):
		return
	_backs[object_id].modulate.a = clampf(2.0 - 2.0 * face_up, 0.0, 1.0)


## A card back over [param face], as large as it.
func _add_back(face: CardFace) -> Control:
	var back: Panel = CardBack.make(face.size.y)
	face.add_child(back)
	_ignore_mouse(back)
	return back


## Draws the card that has left the row as Game Object [param object_id], which is on its
## way to the library, under the cards of the row.
func _add_leaving(object_id: int) -> void:
	if not _looks.has(object_id):
		return
	var face: CardFace = CardFace.new()
	face.setup(_looks[object_id], _built[object_id])
	face.pivot_offset = Vector2(face.size.x / 2.0, face.size.y)
	add_child(face)
	move_child(face, _row.get_index())
	_ignore_mouse(face)
	_leaving[object_id] = face
	_backs[object_id] = _add_back(face)


## Where the library's card is, as a pose on the overlay, or null if there is no library to
## deal from.
func _library_pose(library: Rect2, area: Rect2) -> FacePose:
	if not library.has_area():
		return null
	return FacePose.of(Vector2(library.get_center().x, library.end.y) - area.position, library.size.y, 0.0)


## Everything drawn on the overlay but the cards flying to the hand's strip.
func _all_but_landing() -> Array[CanvasItem]:
	var fading: Array[CanvasItem] = []
	for child: Node in get_children():
		if child != _row and child is CanvasItem:
			fading.append(child as CanvasItem)
	for object_id: int in _shown:
		if not _landing.has(object_id):
			fading.append(_faces[object_id])
	return fading


func _add_card(seen: MmObjectView, look: CardLook, place: Rect2, turn: float, takes_click: bool) -> void:
	var face: CardFace = CardFace.new()
	face.setup(look, place.size.y)
	face.position = place.position
	# It turns about the middle of its bottom edge, as a card of the hand does.
	face.pivot_offset = Vector2(place.size.x / 2.0, place.size.y)
	face.rotation = turn
	_row.add_child(face)
	# Every part of it, and only now: a face builds some of its parts on entering the tree,
	# and one that passes the mouse on hands the overlay a press but never a move, so the
	# cursor would cross the card unseen.
	_ignore_mouse(face)
	_faces[seen.id] = face
	_looks[seen.id] = look
	_built[seen.id] = place.size.y
	_homes[seen.id] = place.position
	_shown.append(seen.id)
	_turns[seen.id] = turn
	_can_go_down[seen.id] = takes_click
	_show_glow(seen.id)


## Whether the card that is Game Object [param object_id] is drawn at [param point].
func _is_on(object_id: int, point: Vector2) -> bool:
	var face: CardFace = _faces.get(object_id, null) as CardFace
	return face != null and Rect2(Vector2.ZERO, face.size).has_point(face.get_transform().affine_inverse() * point)


## Makes [param object_id] the card the cursor is on, or none of them.
func _hover(object_id: int) -> void:
	if object_id == _hovered:
		return
	var was: int = _hovered
	_hovered = object_id
	for changed: int in [was, object_id]:
		if _faces.has(changed):
			_faces[changed].z_index = 1 if changed == _hovered else 0
			_show_glow(changed)
	# Only a card that takes a click shows the pointing hand.
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_go_down(_hovered) else Control.CURSOR_ARROW


## Gives the card its Glow: white under the cursor, green while it can be put on the
## bottom, and otherwise none.
func _show_glow(object_id: int) -> void:
	var face: CardFace = _faces[object_id]
	var color: Variant = null
	if object_id == _hovered:
		color = Color.WHITE
	elif can_go_down(object_id):
		color = DecisionClicks.color_of(DecisionClicks.Kind.OTHER)
	var seconds: float = glow_seconds
	if _is_drawing and _glowed_before.get(object_id) == color:
		seconds = 0.0
	if color == null:
		BorderEffects.remove_glow(face, seconds)
	else:
		BorderEffects.set_glow(face, face.size, color, seconds)


func _add_pair(row_rect: Rect2, unit: float, left_text: String, left_answer: int, right_text: String, right_answer: int) -> void:
	var button_size: Vector2 = EncounterLayout.OPENING_BUTTON * unit
	var middle: float = row_rect.get_center().x
	_button(left_text, Rect2(Vector2(middle - button_size.x - 12.0 * unit, row_rect.position.y), button_size),
			func() -> void: answered.emit(left_answer))
	_button(right_text, Rect2(Vector2(middle + 12.0 * unit, row_rect.position.y), button_size),
			func() -> void: answered.emit(right_answer))


func _button(text: String, box: Rect2, on_press: Callable) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.position = box.position
	made.size = box.size
	made.add_theme_font_size_override("font_size", int(box.size.y * 0.42) + UiText.RAISE)
	made.pressed.connect(on_press)
	add_child(made)
	_buttons[text] = made
	return made


func _label(text: String, box: Rect2, font_size: float, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = box.position
	label.size = box.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(font_size) + UiText.RAISE)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_hovered = NONE
	_turns.clear()
	_can_go_down.clear()
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_heading = null
	_under_heading = null
	_villain = null
	_row = null
	_buttons.clear()
	_faces.clear()
	_shown.clear()
	_leaving.clear()
	_backs.clear()
	_homes.clear()
	_lifts.clear()
	_rotations.clear()


func _stop_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


func _finish_closing() -> void:
	_is_closing = false
	_clear()
	_motion.clear()
	_looks.clear()
	_built.clear()
	_landing.clear()
	hide()
	closed.emit()


func _ignore_mouse(node: Node) -> void:
	var control: Control = node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
