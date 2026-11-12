class_name FlightCard
extends Control
## A card drawn in the air (Card Flights). It is drawn as what it was where it left and as
## what it is where it lands, one fading into the other on the way: a Card Face from the
## hand becomes a Battlefield Face, and a card back from the library turns face up. Its
## place is its middle. It takes no clicks.

## How a card is drawn: a Card Face, a Battlefield Face, or a card back.
enum Kind { CARD, FIELD, BACK }

## The height its faces are built at; the pose scales them.
const BUILD_HEIGHT: float = 250.0

## What it is drawn as where it lands, and from which look, for a flight that carries on
## from this one.
var landing_kind: Kind
var landing_look: CardLook

var _leaving: Control
var _landing: Control = null


## How a card in a zone of [param zone_kind] is drawn.
static func kind_in(zone_kind: MmZone.Kind) -> Kind:
	if zone_kind == MmZone.Kind.BATTLEFIELD:
		return Kind.FIELD
	if zone_kind == MmZone.Kind.LIBRARY:
		return Kind.BACK
	return Kind.CARD


## A card that leaves as [param from_kind] drawn from [param from_look] and lands as
## [param to_kind] drawn from [param to_look]. A look the Hero may not see is null, and
## that end is a card back.
func _init(from_kind: Kind, from_look: CardLook, to_kind: Kind, to_look: CardLook) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var leaving_kind: Kind = from_kind if from_look != null else Kind.BACK
	landing_kind = to_kind if to_look != null else Kind.BACK
	landing_look = to_look
	if leaving_kind == landing_kind and leaving_kind != Kind.FIELD:
		# The same shape all the way: one face, as it is where it lands.
		_leaving = _face(landing_kind, to_look)
		return
	_leaving = _face(leaving_kind, from_look)
	_landing = _face(landing_kind, to_look)


## Draws it at [param pose], [param along] of the way through its flight (0 to 1).
func show_pose(pose: FacePose, along: float) -> void:
	position = pose.center
	modulate.a = pose.alpha
	for face: Control in [_leaving, _landing]:
		if face == null:
			continue
		face.scale = Vector2.ONE * (pose.height / BUILD_HEIGHT)
		var field: BattlefieldFace = face as BattlefieldFace
		if field != null:
			field.show_turn(pose.turn)
	if _landing != null:
		# Both are solid half-way, so the card is never see-through.
		_leaving.modulate.a = clampf(2.0 - 2.0 * along, 0.0, 1.0)
		_landing.modulate.a = clampf(2.0 * along, 0.0, 1.0)


## The face it is drawn with as it leaves.
func leaving_face() -> Control:
	return _leaving


## The face it is drawn with as it lands, or null if that is the same face.
func landing_face() -> Control:
	return _landing


## Whether it is a card back all the way.
func is_face_down() -> bool:
	return landing_kind == Kind.BACK and _landing == null


func _face(kind: Kind, look: CardLook) -> Control:
	var face: Control
	if kind == Kind.FIELD:
		var field: BattlefieldFace = BattlefieldFace.new()
		field.setup(look, BUILD_HEIGHT)
		face = field
	elif kind == Kind.CARD:
		var card: CardFace = CardFace.new()
		card.setup(look, BUILD_HEIGHT)
		face = card
	else:
		face = CardBack.make(BUILD_HEIGHT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.pivot_offset = face.size / 2.0
	face.position = -face.size / 2.0
	add_child(face)
	return face
