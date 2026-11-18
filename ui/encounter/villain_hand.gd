class_name VillainHand
extends Control
## The Villain Hand (game glossary): the Villain's hand as the Encounter Screen draws it, a
## fan of card backs hanging from the top of its Region. The screen keeps it outside the
## redrawn board, as it keeps the Hand Strip (ADR 0027), so a back is never rebuilt: a card
## that lands in the hand makes the others ease aside, at the Hand Strip's pace, rather than
## jump. A redraw that is not easing puts every back at its place at once, as it does the
## Hero's cards. It takes no clicks: the Hero cannot see these cards, except a Known Card,
## one the Villain revealed as they found it (game ADR 0058), which is drawn face up with a
## small eye at the right end of the fan until it leaves the hand.

## Each back, left to right.
var _backs: Array[Control] = []
## Where each back hangs and how far it is turned, as the hand is laid out now.
var _places: Array[Vector2] = []
var _turns: Array[float] = []
var _rect: Rect2 = Rect2()
## The faces of the Known Cards drawn on the backs at the right end, and which they are.
var _known_faces: Array[CardFace] = []
var _known_ids: Array[int] = []
## How many backs there were when they were drawn: a back gone or new moves them.
var _known_on_backs: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param count] card backs fanned in [param hand_rect]. A back already drawn stays
## where it is and, with [param is_easing], eases to its new place; otherwise every back is
## put at its place at once. A back new to the hand joins at the right end, at its place.
func show_hand(count: int, hand_rect: Rect2, is_easing: bool) -> void:
	_rect = hand_rect
	while _backs.size() > count:
		var gone: Control = _backs.pop_back()
		remove_child(gone)
		gone.queue_free()
	_places = EncounterLayout.villain_hand(count, hand_rect, _card_size())
	_turns.clear()
	for index: int in count:
		_turns.append(-EncounterLayout.fan_angle(index, count))
	while _backs.size() < count:
		var back: Panel = CardBack.make(_card_size().y)
		back.pivot_offset = Vector2(_card_size().x / 2.0, 0.0)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var index: int = _backs.size()
		back.position = _places[index]
		back.rotation = _turns[index]
		add_child(back)
		_backs.append(back)
	if not is_easing:
		_ease_backs(1.0)


## Draws [param looks], the Known Cards of [param known_ids], face up on the backs at the
## right end of the fan, each with a small eye: the Hero sees these cards (game ADR 0058).
## Nothing is rebuilt while they stay the same cards on the same backs.
func show_known(known_ids: Array[int], looks: Array[CardLook]) -> void:
	var shown: int = mini(known_ids.size(), _backs.size())
	var wanted: Array[int] = known_ids.slice(0, shown)
	if wanted == _known_ids and _backs.size() == _known_on_backs:
		return
	_known_on_backs = _backs.size()
	for face: CardFace in _known_faces:
		face.get_parent().remove_child(face)
		face.queue_free()
	_known_faces.clear()
	_known_ids = wanted
	for index: int in shown:
		var face: CardFace = CardFace.new()
		face.setup(looks[index], _card_size().y)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var eye: SeenEye = SeenEye.new()
		eye.position = Vector2(-10.0, _card_size().y - SeenEye.SIDE - 4.0)
		face.add_child(eye)
		_backs[_backs.size() - shown + index].add_child(face)
		_known_faces.append(face)


## How many Known Cards are drawn face up.
func known_count() -> int:
	return _known_faces.size()


## Moves each back [param delta] seconds' worth of the way to where it belongs.
func frame(delta: float) -> void:
	_ease_backs(EncounterLayout.ease_weight(HandStrip.ease_for(_backs.size()), delta))


## How many card backs are drawn.
func count() -> int:
	return _backs.size()


## The card back at [param index], left to right.
func back(index: int) -> Control:
	return _backs[index]


## Where the card the Villain draws [param arriving_before] cards after the first still in
## the air lands, as the middle of its back: the place at the right end of the hand as it
## will be with every card drawn before it already there.
func landing_place(arriving_before: int) -> FacePose:
	var total: int = _backs.size() + arriving_before + 1
	var corner: Vector2 = EncounterLayout.villain_hand(total, _rect, _card_size())[total - 1]
	var turn: float = -EncounterLayout.fan_angle(total - 1, total)
	# A back turns about the middle of its top edge.
	var middle: Vector2 = corner + Vector2(_card_size().x / 2.0, 0.0) + Vector2(0.0, _card_size().y / 2.0).rotated(turn)
	return FacePose.of(middle, _card_size().y, 0.0)


func _ease_backs(weight: float) -> void:
	for index: int in _backs.size():
		_backs[index].position = _backs[index].position.lerp(_places[index], weight)
		_backs[index].rotation = lerpf(_backs[index].rotation, _turns[index], weight)


static func _card_size() -> Vector2:
	return Vector2(EncounterLayout.VILLAIN_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.VILLAIN_CARD_HEIGHT)
