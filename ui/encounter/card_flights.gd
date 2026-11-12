class_name CardFlights
extends RefCounted
## Card Flights (game glossary): cards in the air between two zones (13d-2). A card that
## changes zones is drawn once, flying from where it was to where it lands, in place of
## fading out in one place and in at another. It lives on the Encounter Screen beside the
## FaceMotion, outside the redrawn nodes, and like it holds no nodes: each flight is a pose
## to start from and a pose to land at, kept by the ID of the Game Object that lands. The
## screen asks for each flight's pose every frame and places a FlightCard there.
##
## A flight can be aimed again while it is in the air, because where a card lands can move
## under it: the hand makes room, a line is scrolled, a window is dragged.

## A frame never counts for more than this, as in Face Motion.
const LONGEST_FRAME: float = FaceMotion.LONGEST_FRAME
## How much of its flight a card takes to fade in where it appears from nothing, or out
## where it disappears.
const FADE_SHARE: float = 0.25

## How long a flight takes. Zero means no card flies.
var seconds: float = 0.0

var _clock: float = 0.0
var _flights: Dictionary[int, Flight] = {}


## Each card's way through [param events]: from the zone it first left to the zone it ended
## in. A card that passed through a zone on the way, as a spell that resolved at once
## passed through the stack, has one route.
static func routes(events: Array[MmEvent]) -> Array[Route]:
	var found: Array[Route] = []
	for event: MmEvent in events:
		var change: ZoneChangeEvent = event as ZoneChangeEvent
		if change == null:
			continue
		var route: Route = null
		for known: Route in found:
			if known.object_id == change.object_id:
				route = known
		if route == null:
			route = Route.new()
			route.first_object_id = change.object_id
			route.card_id = change.card_id
			route.from_zone_kind = change.from_zone_kind
			route.from_owner_id = change.from_owner_id
			found.append(route)
		route.object_id = change.new_object_id
		route.to_zone_kind = change.to_zone_kind
		route.to_owner_id = change.to_owner_id
	return found


## Lets a frame of [param delta] seconds go by.
func advance(delta: float) -> void:
	_clock += minf(delta, LONGEST_FRAME)


## Puts the card that lands as Game Object [param object_id] in the air, from [param from]
## to [param to]. With [param fades_in] it appears from nothing where it starts, and with
## [param fades_out] it disappears where it lands.
func launch(object_id: int, from: FacePose, to: FacePose, fades_in: bool = false, fades_out: bool = false) -> void:
	var flight: Flight = Flight.new()
	flight.from = from
	flight.to = to
	flight.started = _clock
	flight.fades_in = fades_in
	flight.fades_out = fades_out
	_flights[object_id] = flight


## The card that lands as Game Object [param object_id] now lands at [param to]. Where it
## started and when stay as they were.
func aim(object_id: int, to: FacePose) -> void:
	if _flights.has(object_id):
		_flights[object_id].to = to


## Takes the card that lands as Game Object [param object_id] out of the air.
func land(object_id: int) -> void:
	_flights.erase(object_id)


## Takes every card out of the air.
func clear() -> void:
	_flights.clear()


## Whether the card that lands as Game Object [param object_id] is in the air. It stays
## there, at its landing place, until land() takes it down.
func is_flying(object_id: int) -> bool:
	return _flights.has(object_id)


## Whether the flight of Game Object [param object_id] has reached where it lands.
func has_landed(object_id: int) -> bool:
	return _flights.has(object_id) and _time_along(object_id) >= 1.0


## The Game Objects whose cards are in the air, in ID order.
func ids() -> Array[int]:
	var found: Array[int] = _flights.keys()
	found.sort()
	return found


## How far along its way the card of Game Object [param object_id] is, from 0 to 1: slow,
## fast, slow.
func along_of(object_id: int) -> float:
	return FaceMotion.ease_of(_time_along(object_id))


## How to draw the card of Game Object [param object_id] right now, or null if it is not
## in the air.
func pose_of(object_id: int) -> FacePose:
	if not _flights.has(object_id):
		return null
	var flight: Flight = _flights[object_id]
	var along: float = along_of(object_id)
	var pose: FacePose = flight.from.blend(flight.to, along)
	if flight.fades_in:
		pose.alpha *= clampf(along / FADE_SHARE, 0.0, 1.0)
	if flight.fades_out:
		pose.alpha *= clampf((1.0 - along) / FADE_SHARE, 0.0, 1.0)
	return pose


func _time_along(object_id: int) -> float:
	if seconds <= 0.0:
		return 1.0
	return clampf((_clock - _flights[object_id].started) / seconds, 0.0, 1.0)


## One card's way from the zone it left to the zone it ended in.
class Route:
	extends RefCounted

	## The Game Object that left, and the one the card is where it ended.
	var first_object_id: int
	var object_id: int
	var card_id: int
	var from_zone_kind: MmZone.Kind
	var from_owner_id: int
	var to_zone_kind: MmZone.Kind
	var to_owner_id: int
	## How the card is drawn as it leaves (a FlightCard.Kind) and from which look, set by
	## the screen when it puts the card in the air.
	var leaving_kind: int = 0
	var leaving_look: CardLook = null


## One card in the air.
class Flight:
	extends RefCounted

	var from: FacePose
	var to: FacePose
	var started: float
	var fades_in: bool
	var fades_out: bool
