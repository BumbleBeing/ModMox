class_name HandStrip
extends Control
## The Hand Strip (game glossary, 13j): the Hero's hand as the Encounter Screen draws it, a
## fanned row of Card Faces along the bottom that parts around the card under the cursor,
## lights it, and makes room where a Drag Card hovers. The screen keeps it outside the
## redrawn board, as it keeps Face Motion (ADR 0027), so it keeps its faces across a redraw
## and each eases on from wherever it was.
##
## It is shown a HandShow from each snapshot, takes only the presses the screen has already
## found are its own (nothing drawn over the hand, the game not paused), and is told where
## the cursor is each frame. What a click on a card would do is handed to it; it says what
## the Hero did with a card and plays nothing itself. It keeps the Hand Order and the Drag
## Card, which nothing else reaches.
##
## A press becomes a drag after three pixels (A371). The held card is drawn upright on the
## drag layer above the windows; over the strip the other cards make room for it and letting
## go puts it down there, and above it letting go plays it (A372). Its faces ignore the
## mouse: what the cursor is on is worked out from where each is drawn.

## A card with one way to be played was played: let go above the strip or double-clicked.
## The card is let go of first, since the answer brings a redraw, accepted or refused.
signal answered(answer: int)
## A card with several ways to be played asks for the Option Menu at [param at]. A card
## let go waits where it was let go until menu_closed().
signal menu_wanted(options: Array[ClickOption], at: Vector2)
## A card was pressed and let go where it was pressed (A400).
signal clicked(card_id: int)
## What letting go of the held card would play changed: an option, or null for nothing.
signal offer_changed(option: ClickOption)

## How much of the way to its place a card goes in a sixtieth of a second.
const EASE: float = 0.3
## From how many cards a hand eases more slowly, and the slowest it goes: more cards part
## closer together, and the same speed read as frantic.
const CALM_FROM: int = 7
const CALMEST_EASE: float = 0.18
## How much of the way to how light it belongs a card goes in a sixtieth of a second.
const LIGHT_EASE: float = 0.4
## How light the card under the cursor is drawn.
const HOVER_LIGHT: Color = ClickCatcher.BRIGHT
## How far round a card is a little bigger to the mouse than it looks, in pixels.
const PRESS_MARGIN: float = 8.0

## What the hand was last shown from.
var _hand: HandShow = HandShow.new()
var _order: HandOrder = HandOrder.new()
var _drag: DragCard = DragCard.new()
## Where a held card is drawn: a layer above the windows, given by the screen.
var _drag_layer: Control = null
## The face of each card drawn, the held one included, by Card Identity.
var _faces: Dictionary[int, CardFace] = {}
## What each face was drawn from, to tell when a card must be drawn again.
var _drawn_looks: Dictionary[int, String] = {}
## The Card Identities of the row, left to right: the hand without the held card and the
## cards still arriving.
var _row: Array[int] = []
## Where each card of the row rests and how far it is turned, as the row is laid out now.
var _rest: Array[Vector2] = []
var _turns: Array[float] = []
## Where the cursor was last seen.
var _cursor: Vector2 = Vector2.ZERO
## What letting go of the held card would play, as last said.
var _offer: ClickOption = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Gives the strip [param drag_layer], a layer above the windows filling the same part of
## the screen, where a held card is drawn.
func setup(drag_layer: Control) -> void:
	_drag_layer = drag_layer


## Shows the hand as [param hand] has it. A card already drawn keeps its face. Unless the
## hand is easing, every card is put at its place at once; while it eases, a card already
## drawn carries on from where it is and only a card new to the row is put at its place.
func show_hand(hand: HandShow) -> void:
	_hand = hand
	_cursor = hand.cursor
	_order.update(hand.cards, hand.is_rewind)
	if _drag.card_id() != DragCard.NONE and not hand.cards.has(_drag.card_id()):
		# The card being held has left the hand (A380).
		_drag.drop()
	var drawn: Array[int] = []
	for card_id: int in _order.cards():
		if not hand.arriving.has(card_id):
			drawn.append(card_id)
	for card_id: int in _faces.keys():
		if not drawn.has(card_id) or _drawn_looks[card_id] != _look_key(hand.looks[card_id]):
			_take_face(card_id)
	_row.clear()
	var is_new: Dictionary[int, bool] = {}
	for card_id: int in drawn:
		if not _faces.has(card_id):
			_make_face(card_id)
			is_new[card_id] = true
		if not (_drag.is_lifted() and card_id == _drag.card_id()):
			_row.append(card_id)
	for card_id: int in _row:
		_reparent(_faces[card_id], self)
		move_child(_faces[card_id], -1)
		_faces[card_id].visible = not hand.hidden.has(card_id)
	_lay_out()
	var places: Array[Vector2] = _places(_cursor)
	for index: int in _row.size():
		if is_new.has(_row[index]):
			_faces[_row[index]].position = places[index]
			_faces[_row[index]].rotation = _turns[index]
	if not hand.is_easing:
		_spread(1.0)
	if _drag.is_lifted():
		var lifted: CardFace = _faces[_drag.card_id()]
		_reparent(lifted, _drag_layer)
		lifted.rotation = 0.0
		lifted.z_index = 0
		lifted.position = _drag.place()
	_glow_all()


## The left button went down at [param cursor], a double-click when [param is_double]. On a
## card of the hand this is the start of a drag, or with [param is_double] it plays the
## card: at once if there is one way to, or from the Option Menu if there are several
## (A377). A double-click on a card that cannot be played is a press like any other: two
## tries at a drag in quick succession arrive as one, and the second must not be swallowed.
## Returns whether a card of the hand was under the cursor.
func press(cursor: Vector2, is_double: bool) -> bool:
	var card_id: int = _card_at(cursor)
	if card_id == DragCard.NONE:
		return false
	var options: Array[ClickOption] = _hand.options_of(card_id) if is_double else ([] as Array[ClickOption])
	if options.size() > 1:
		menu_wanted.emit(options, cursor)
	elif options.size() == 1:
		answered.emit(options[0].answer)
	else:
		_drag.press(card_id, cursor, cursor - _faces[card_id].position)
	return true


## The mouse moved to [param cursor] with a card pressed or held. Once it has moved far
## enough the card is picked up and follows the cursor; the hand makes room for it while it
## is over the strip, and over the panels at the left it is let go of (A371).
func drag_to(cursor: Vector2) -> void:
	if _drag.move(cursor):
		_lift()
	if not _drag.is_holding():
		return
	if EncounterLayout.is_over_panels(cursor, _hand.regions):
		cancel()
		return
	var lifted: CardFace = _faces[_drag.card_id()]
	var is_above: bool = EncounterLayout.is_above_hand(cursor, _hand.regions)
	var gap: int = DragCard.NONE
	if not is_above:
		gap = EncounterLayout.hand_gap(_row.size(), _hand.regions["hero_hand"], lifted.size, cursor)
	if _drag.hover(is_above, gap):
		_lay_out()
	lifted.position = _drag.place()


## The left button came up at [param cursor]. A card pressed and never picked up has been
## clicked. A held card let go above the strip is played: at once with one way to play it,
## from the Option Menu with several, the card waiting where it was let go (A372). One that
## cannot be played right now goes back to its place without a word (A380). Over the strip
## it is put down where the hand made room.
func release(cursor: Vector2) -> void:
	drag_to(cursor)
	if not _drag.is_holding():
		if _drag.is_pressed():
			var card_id: int = _drag.card_id()
			_drag.drop()
			clicked.emit(card_id)
		return
	if not _drag.is_above():
		_put_down(_drag.gap())
		return
	var options: Array[ClickOption] = _hand.options_of(_drag.card_id())
	if options.is_empty():
		_put_back()
	elif options.size() > 1:
		_drag.wait()
		_lay_out()
		menu_wanted.emit(options, cursor)
	else:
		# The answer brings a redraw of its own, accepted or refused, and a refused card
		# must not stay held with the button up. Its face goes back into the row where it
		# was let go, so a card that is played flies from there.
		_put_back()
		answered.emit(options[0].answer)


## Lets go of a card that is pressed, held or waiting on the Option Menu, back to its place
## in the hand: a right-click, the panels at the left, or the Pause Menu opening.
func cancel() -> void:
	if _drag.is_lifted():
		_put_back()
	else:
		_drag.drop()


## The Option Menu closed. A card that was waiting on it goes back to the hand; if a way to
## play it was chosen, the answer takes it from there.
func menu_closed() -> void:
	if _drag.is_waiting():
		_put_back()


## Moves the hand [param delta] seconds on, with the cursor at [param cursor]: each card
## goes part of the way to where it belongs, in place, turn and lightness, as far in one slow
## frame as in the frames it replaced.
func frame(delta: float, cursor: Vector2) -> void:
	_cursor = cursor
	_spread(EncounterLayout.ease_weight(ease_for(_row.size()), delta))
	_light(EncounterLayout.ease_weight(LIGHT_EASE, delta))


## How much of the way to its place a card of a row of [param count] goes in a sixtieth of
## a second: EASE up to CALM_FROM cards, and a little less for each card past that.
static func ease_for(count: int) -> float:
	if count <= CALM_FROM:
		return EASE
	return maxf(EASE * CALM_FROM / count, CALMEST_EASE)


## The card of the row drawn under [param point], as a Card Identity, or DragCard.NONE: the
## one seen there, turned and parted as it is, and of two that overlap the one on top. This
## is the card that is lit.
func card_under(point: Vector2) -> int:
	var found: int = DragCard.NONE
	for card_id: int in _row:
		var face: CardFace = _faces[card_id]
		if not face.visible or not Rect2(Vector2.ZERO, face.size).has_point(face.get_transform().affine_inverse() * point):
			continue
		# A later card is drawn over an earlier one, and a raised one over them all.
		if face.z_index > 0:
			return card_id
		found = card_id
	return found


## Where [param card_id] is drawn now, held or not, as the middle of its face, or null for a
## card not drawn.
func place_of(card_id: int) -> FacePose:
	var face: CardFace = _faces.get(card_id)
	if face == null or not is_instance_valid(face) or not face.is_inside_tree():
		return null
	var middle: Vector2 = face.get_global_transform() * (face.size / 2.0) - get_global_transform().origin
	return FacePose.of(middle, face.size.y, 0.0)


## Where [param card_id] belongs in the row, as the middle of its face. For a card still
## arriving it is where the card lands: its place in the row as the row will be then, with
## every card arriving before it already there. Null for a card not in the hand.
func rest_of(card_id: int) -> FacePose:
	var size_now: Vector2 = _card_size()
	var index: int = _row.find(card_id)
	var corner: Vector2
	var turn: float
	if index >= 0:
		corner = _rest_now()[index]
		turn = _turns[index]
	else:
		var landing: int = _hand.arriving.find(card_id)
		if landing < 0:
			return null
		var row: Array[int] = []
		for in_hand: int in _order.cards():
			var arrives_later: bool = _hand.arriving.find(in_hand) > landing
			if not arrives_later and not (_drag.is_lifted() and in_hand == _drag.card_id()):
				row.append(in_hand)
		index = row.find(card_id)
		corner = EncounterLayout.hand_row(row.size(), DragCard.NONE, _hand.regions["hero_hand"], size_now)[index]
		turn = EncounterLayout.hand_row_angles(row.size(), DragCard.NONE)[index]
	# A card turns about the middle of its bottom edge.
	var middle: Vector2 = corner + Vector2(size_now.x / 2.0, size_now.y) + Vector2(0.0, -size_now.y / 2.0).rotated(turn)
	return FacePose.of(middle, size_now.y, 0.0)


## The card held or waiting on the Option Menu, or DragCard.NONE.
func held() -> int:
	return _drag.card_id() if _drag.is_lifted() else DragCard.NONE


## Whether a card is held and follows the cursor: lifted, and not waiting on the Option Menu.
func is_holding() -> bool:
	return _drag.is_holding()


## What letting go of the held card would play right now, or null.
func offer() -> ClickOption:
	return _offer


## How far [param card_id] is turned where it belongs in the row, in radians, or 0.0 for a
## card not in the row.
func fan_turn_of(card_id: int) -> float:
	var index: int = _row.find(card_id)
	return _turns[index] if index >= 0 and index < _turns.size() else 0.0


## The card pressed and not yet picked up, or DragCard.NONE.
func pressed() -> int:
	return _drag.card_id() if _drag.is_pressed() else DragCard.NONE


## Whether a card is pressed and not yet picked up.
func is_pressing() -> bool:
	return _drag.is_pressed()


## The cards in hand, in the Hero's order.
func order() -> Array[int]:
	return _order.cards()


## The face of [param card_id], held or in the row, or null.
func face_of(card_id: int) -> CardFace:
	return _faces.get(card_id)


## The card of the row that [param cursor] is on, or DragCard.NONE. The card nearest the
## cursor counts where it is drawn and also where the cursor is sending it: the hand eases
## toward the cursor over several frames, fewer when a frame is slow, and a press made on
## arriving must not miss the card for being early.
func _card_at(cursor: Vector2) -> int:
	if _row.is_empty():
		return DragCard.NONE
	var size_now: Vector2 = _card_size()
	var rest: Array[Vector2] = _rest_now()
	if not EncounterLayout.is_cursor_over_hand(rest, size_now, cursor):
		return DragCard.NONE
	var drawn: int = card_under(cursor)
	if drawn != DragCard.NONE:
		return drawn
	var index: int = roundi(EncounterLayout.hand_cursor_place(rest, size_now, cursor))
	if not _faces[_row[index]].visible:
		# A card not shown yet takes no press.
		return DragCard.NONE
	var is_on_it: bool = Rect2(_faces[_row[index]].position, size_now).grow(PRESS_MARGIN).has_point(cursor) \
			or Rect2(_places(cursor)[index], size_now).grow(PRESS_MARGIN).has_point(cursor)
	return _row[index] if is_on_it else DragCard.NONE


## Takes the pressed card out of the row and holds it. Nothing is rebuilt: its own face is
## lifted to the drag layer, upright.
func _lift() -> void:
	var card_id: int = _drag.card_id()
	var face: CardFace = _faces[card_id]
	# Where the rest go is worked out again as soon as the card hovers.
	_row.erase(card_id)
	_reparent(face, _drag_layer)
	face.rotation = 0.0
	face.z_index = 0


## Puts the lifted card into the row at [param index] among the other cards, and into the
## Hand Order there. Nothing is rebuilt: its face goes back into the row, where it eases to
## its place from where it was let go.
func _put_down(index: int) -> void:
	var card_id: int = _drag.card_id()
	var face: CardFace = _faces[card_id]
	var at: int = clampi(index, 0, _row.size())
	_drag.drop()
	_order.place(card_id, at)
	_reparent(face, self)
	if not _row.is_empty():
		var is_last: bool = at == _row.size()
		move_child(face, _faces[_row[at - 1]].get_index() + 1 if is_last else _faces[_row[at]].get_index())
	_row.insert(at, card_id)
	# Only a card that can be played glowed brighter while held; any other keeps its glow.
	if not _hand.options_of(card_id).is_empty():
		BorderEffects.set_glow_of(face, face.size, _hand.glow_of(card_id), _hand.glow_seconds)
	_lay_out()


## Puts the lifted card back where it was in the hand.
func _put_back() -> void:
	_put_down(_order.place_of(_drag.card_id()))


## Works out where the row's cards go now, for where the held card is, and shows on the held
## card and in what it offers whether letting go would play it. Nothing is rebuilt: the
## cards ease to their places.
func _lay_out() -> void:
	var gap: int = _drag.gap() if _drag.has_gap() else DragCard.NONE
	if _hand.regions.has("hero_hand"):
		_rest = EncounterLayout.hand_row(_row.size(), gap, _hand.regions["hero_hand"], _card_size())
		_turns = EncounterLayout.hand_row_angles(_row.size(), gap)
	_glow_lifted()
	var offer: ClickOption = null
	if _drag.is_holding() and _drag.is_above():
		var options: Array[ClickOption] = _hand.options_of(_drag.card_id())
		offer = options[0] if not options.is_empty() else null
	if offer != _offer:
		_offer = offer
		offer_changed.emit(offer)


## Each card glows in the colors the hand was shown with, the held one as _glow_lifted() says.
func _glow_all() -> void:
	for card_id: int in _row:
		BorderEffects.set_glow_of(_faces[card_id], _faces[card_id].size, _hand.glow_of(card_id), _hand.glow_seconds)
	_glow_lifted()


## A lifted card that can be played glows in the colors of what letting go offers, brighter
## where letting go would do it (A375); one that cannot keeps the glow it had.
func _glow_lifted() -> void:
	if not _drag.is_lifted() or _hand.options_of(_drag.card_id()).is_empty():
		return
	var face: CardFace = _faces[_drag.card_id()]
	var is_to_play: bool = _drag.is_waiting() or _drag.is_above()
	BorderEffects.set_glow_of(face, face.size, _hand.glow_of(_drag.card_id(), is_to_play), _hand.glow_seconds)


## Where each card of the row rests right now: where the row puts it, and a card chosen to
## be discarded a quarter of its height above that (A401).
func _rest_now() -> Array[Vector2]:
	var rest: Array[Vector2] = _rest.duplicate()
	for index: int in mini(rest.size(), _row.size()):
		if _hand.raised.has(_row[index]):
			rest[index].y -= _card_size().y * EncounterLayout.PICKED_RISE
	return rest


## Where the row's cards go with the cursor at [param cursor]: parted around the card under
## it, and never past the hand's bounds. While a card is held they keep to their places.
func _places(cursor: Vector2) -> Array[Vector2]:
	var rest: Array[Vector2] = _rest_now()
	if _row.is_empty() or _drag.is_lifted():
		return rest
	return EncounterLayout.hand_spread_within(rest, _card_size(), cursor, _hand.regions["hero_hand"])


## Moves the row's cards [param weight] of the way to where they belong, in place and in
## turn, the one nearest the cursor drawn in front.
func _spread(weight: float) -> void:
	if _row.is_empty():
		return
	var places: Array[Vector2] = _places(_cursor)
	var nearest: int = -1
	var rest: Array[Vector2] = _rest_now()
	if not _drag.is_lifted() and EncounterLayout.is_cursor_over_hand(rest, _card_size(), _cursor):
		nearest = roundi(EncounterLayout.hand_cursor_place(rest, _card_size(), _cursor))
	for index: int in _row.size():
		var face: CardFace = _faces[_row[index]]
		face.position = face.position.lerp(places[index], weight)
		face.rotation = lerpf(face.rotation, _turns[index], weight)
		face.z_index = 1 if index == nearest else 0


## Moves each card [param weight] of the way to how light it belongs: a little lighter while
## it is the one drawn under the cursor, unless it is pressed or held.
func _light(weight: float) -> void:
	var lit: int = DragCard.NONE
	if not _drag.is_lifted():
		lit = card_under(_cursor)
	if _drag.is_pressed() and lit == _drag.card_id():
		lit = DragCard.NONE
	for card_id: int in _row:
		_ease_light(_faces[card_id], HOVER_LIGHT if card_id == lit else Color.WHITE, weight)
	if _drag.is_lifted():
		_ease_light(_faces[_drag.card_id()], Color.WHITE, weight)


## Draws a face for [param card_id], turning about the middle of its bottom edge, deaf to
## the mouse.
func _make_face(card_id: int) -> void:
	var face: CardFace = CardFace.new()
	face.setup(_hand.looks[card_id], _card_size().y)
	face.pivot_offset = Vector2(face.size.x / 2.0, face.size.y)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(face)
	_faces[card_id] = face
	_drawn_looks[card_id] = _look_key(_hand.looks[card_id])


## Takes away the face of [param card_id].
func _take_face(card_id: int) -> void:
	var face: CardFace = _faces[card_id]
	face.get_parent().remove_child(face)
	face.queue_free()
	_faces.erase(card_id)
	_drawn_looks.erase(card_id)


static func _reparent(face: CardFace, parent: Control) -> void:
	if face.get_parent() == parent:
		return
	if face.get_parent() != null:
		face.get_parent().remove_child(face)
	parent.add_child(face)


static func _ease_light(face: CardFace, light: Color, weight: float) -> void:
	var alpha: float = face.modulate.a
	face.modulate = face.modulate.lerp(light, weight)
	face.modulate.a = alpha


static func _card_size() -> Vector2:
	return Vector2(EncounterLayout.HAND_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.HAND_CARD_HEIGHT)


## What a face shows of [param look], so a card whose look changed is drawn again and one
## whose look is the same keeps its face.
static func _look_key(look: CardLook) -> String:
	return "%s|%s|%s|%s|%s" % [look.name, look.type_line(), look.rules_text, look.power_toughness_texts(), look.art_key]
