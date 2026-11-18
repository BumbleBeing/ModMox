class_name FlightLayer
extends Control
## The Flight Layer (game glossary, 13k): the layer of the Encounter Screen, over every
## window, where Card Flights are drawn, and the one place they are worked out (ADR 0027).
## Shown each new snapshot with the redraw to run, it puts every card that changed zones in
## the air from where it was drawn before the board is rebuilt, aims it at where it belongs
## after, draws its Flight Card every frame, and says when it has landed.
##
## It asks the screen one question, where the zone of a route is drawn right now, and
## touches nothing else on it: what a card lands on draws itself see-through while
## is_flying() says so, and what a landing means is the screen's to decide. Its timing is a
## CardFlights, which holds no nodes.

## A card has been put in the air, after the redraw: a permanent that flies away leaves no
## ghost.
signal took_off(route: CardFlights.Route)
## A card has landed, or been taken down where it belongs: a rewind, a window of another
## size, or nothing showing where it lands.
signal landed(route: CardFlights.Route)

## How long a flight takes. Zero means no card flies.
var seconds: float:
	get:
		return _timing.seconds
	set(value):
		_timing.seconds = value
## How long after one card of several a player draws together leaves the library the next
## one does.
var gap_seconds: float:
	get:
		return _timing.gap_seconds
	set(value):
		_timing.gap_seconds = value

var _timing: CardFlights = CardFlights.new()
## Where the zone of a route is drawn: place_of(route, is_landing) -> FacePose or null.
var _place_of: Callable = func(_route: CardFlights.Route, _is_landing: bool) -> FacePose: return null
## How the card of a route is drawn where it leaves or lands, when the zone alone does not
## say: kind_of(route, is_landing) -> FlightCard.Kind.
var _kind_of: Callable = func(route: CardFlights.Route, is_landing: bool) -> FlightCard.Kind:
	return FlightCard.kind_in(route.to_zone_kind if is_landing else route.from_zone_kind)
## The routes put in the air by put_in_air() and not yet aimed.
var _put: Array[CardFlights.Route] = []
## Each card in the air's way, and the Flight Card drawn for it, by the Game Object that lands.
var _routes: Dictionary[int, CardFlights.Route] = {}
var _cards: Dictionary[int, FlightCard] = {}
## The Game Objects drawn and still on their way to a hand, in the order they land.
var _drawing: Array[int] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Gives the layer [param place_of], which says where the zone of a route is drawn right
## now: place_of(route: CardFlights.Route, is_landing: bool) -> FacePose, or null when
## nothing shows it. Leaving, it is where the Game Object that left is drawn, on its way if
## it is moving; landing, where the one it became belongs.
## [param kind_of] says how the card is drawn there, for a screen that draws some cards of
## a zone another way, as a Tucked Card is a Battlefield Face in exile (game ADR 0043):
## kind_of(route, is_landing) -> FlightCard.Kind. Without it the zone says.
func setup(place_of: Callable, kind_of: Callable = Callable()) -> void:
	_place_of = place_of
	if kind_of.is_valid():
		_kind_of = kind_of


## Shows the cards that changed zones between [param previous] and [param next] flying,
## running [param redraw] in between: where each card was is read from the board as it was
## drawn for [param previous], and where it lands from the board [param redraw] draws. A card
## still in the air from an earlier snapshot carries on from where it has got to. Nothing
## flies with no speed, for a rewind, or with no board drawn before.
func show_snapshot(previous: EncounterSnapshot, next: EncounterSnapshot, redraw: Callable) -> void:
	var begun: Array[CardFlights.Route] = _launch(previous, next)
	redraw.call()
	_aim(begun, next)


## Puts a card in the air that changed no zone but is drawn somewhere else now, as a
## Tucked Card is when its Pile Window opens (game ADR 0043): the card of [param route],
## whose two ends are the same Game Object, from [param start], drawn there as
## [param kind] from [param look]. Called before the board is rebuilt; aim_put() aims it
## after. Nothing flies with no speed. One already in the air carries on from where it has
## got to, which [param start] should then be (pose_of()).
func put_in_air(route: CardFlights.Route, start: FacePose, kind: FlightCard.Kind, look: CardLook) -> void:
	if seconds <= 0.0 or start == null:
		return
	route.leaving_kind = kind
	route.leaving_look = look
	if _timing.is_flying(route.object_id):
		if _cards.has(route.object_id):
			route.leaving_kind = _cards[route.object_id].landing_kind
			route.leaving_look = _cards[route.object_id].landing_look
		_take_down(route.object_id, false)
	_timing.launch(route.object_id, start, start)
	_routes[route.object_id] = route
	_put.append(route)


## Aims each card put_in_air() put there at where it belongs on the board as it is drawn
## now, for [param next], and draws it.
func aim_put(next: EncounterSnapshot) -> void:
	var begun: Array[CardFlights.Route] = _put.duplicate()
	_put.clear()
	_aim(begun, next)


## Where the card that lands as Game Object [param object_id] is drawn right now, or null
## if it is not in the air.
func pose_of(object_id: int) -> FacePose:
	return _timing.pose_of(object_id)


## Lets [param delta] seconds go by: each card in the air flies on, aimed again at where it
## lands now, and each one that has arrived is taken down.
func frame(delta: float) -> void:
	_timing.advance(delta)
	_pose()


## Takes every card in the air down where it belongs.
func land_all() -> void:
	for object_id: int in _timing.ids():
		_take_down(object_id, true)


## Whether the card that lands as Game Object [param object_id] is in the air.
func is_flying(object_id: int) -> bool:
	return _timing.is_flying(object_id)


## The Game Objects whose cards are in the air, in ID order.
func flying_ids() -> Array[int]:
	return _timing.ids()


## The Card Identities on their way from the library to the hand of [param player_id], in
## the order they land.
func drawn_in_air(player_id: int) -> Array[int]:
	var found: Array[int] = []
	for object_id: int in _drawing:
		if _routes[object_id].to_owner_id == player_id:
			found.append(_routes[object_id].card_id)
	return found


## The Card Identities on their way into the hand of [param player_id] some other way than
## being drawn: a card returned from the battlefield, or a spell taken back.
func flying_into_hand(player_id: int) -> Array[int]:
	var found: Array[int] = []
	for object_id: int in _timing.ids():
		var route: CardFlights.Route = _routes.get(object_id)
		if route != null and route.to_zone_kind == MmZone.Kind.HAND and route.to_owner_id == player_id \
				and not _drawing.has(object_id):
			found.append(route.card_id)
	return found


## The Flight Card drawn for the card that lands as Game Object [param object_id], or null.
func flight_card_of(object_id: int) -> FlightCard:
	return _cards.get(object_id, null) as FlightCard


## Before the redraw: puts each card that changed zones in the air, from where it was drawn
## or from where its last flight had got to. Returns the routes put in the air.
func _launch(previous: EncounterSnapshot, next: EncounterSnapshot) -> Array[CardFlights.Route]:
	var begun: Array[CardFlights.Route] = []
	if seconds <= 0.0 or next.is_rewind or previous == null:
		return begun
	for route: CardFlights.Route in CardFlights.routes(next.events):
		var kind: FlightCard.Kind = _kind_of.call(route, false)
		var look: CardLook = previous.look_of(route.first_object_id)
		var start: FacePose = _timing.pose_of(route.first_object_id)
		var is_carrying_on: bool = start != null
		if is_carrying_on:
			# Still in the air from its last move: it carries on from where it has got to.
			if _cards.has(route.first_object_id):
				kind = _cards[route.first_object_id].landing_kind
				look = _cards[route.first_object_id].landing_look
			_take_down(route.first_object_id, false)
		else:
			start = _place_of.call(route, false)
		if start == null:
			continue
		# A card appears from nothing only where it starts at the Stack Window, which shows an
		# entry and no card; one already in the air is there to be seen.
		_timing.launch(route.object_id, start, start, route.from_zone_kind == MmZone.Kind.STACK and not is_carrying_on,
				route.to_zone_kind == MmZone.Kind.STACK, route.drawn_after * gap_seconds)
		_routes[route.object_id] = route
		if route.from_zone_kind == MmZone.Kind.LIBRARY and route.to_zone_kind == MmZone.Kind.HAND:
			_drawing.append(route.object_id)
		# The card is drawn once the board is, when the look it lands with is known.
		route.leaving_kind = kind
		route.leaving_look = look
		begun.append(route)
	return begun


## After the redraw: aims each card put in the air by [param begun] at where it now belongs
## and draws it. One with nowhere to land is taken down at once.
func _aim(begun: Array[CardFlights.Route], next: EncounterSnapshot) -> void:
	for route: CardFlights.Route in begun:
		if not _timing.is_flying(route.object_id):
			continue
		var landing: FacePose = _place_of.call(route, true)
		if landing == null:
			_take_down(route.object_id, true)
			continue
		_timing.aim(route.object_id, landing)
		var card: FlightCard = FlightCard.new(route.leaving_kind, route.leaving_look,
				_kind_of.call(route, true), next.look_of(route.object_id))
		add_child(card)
		_cards[route.object_id] = card
		took_off.emit(route)
	if not begun.is_empty():
		_pose()


## Draws each card in the air where its flight has it right now, aimed at where it lands
## now, and takes down each one that has arrived.
func _pose() -> void:
	for object_id: int in _timing.ids():
		if not _cards.has(object_id):
			continue
		var landing: FacePose = _place_of.call(_routes[object_id], true)
		if landing != null:
			_timing.aim(object_id, landing)
		_cards[object_id].show_pose(_timing.pose_of(object_id), _timing.along_of(object_id))
		if _timing.has_landed(object_id):
			_take_down(object_id, true)


## Takes the card that lands as Game Object [param object_id] out of the air. With
## [param is_landing] it has landed, and says so; otherwise it flies on as another flight.
func _take_down(object_id: int, is_landing: bool) -> void:
	var route: CardFlights.Route = _routes.get(object_id)
	_drawing.erase(object_id)
	_timing.land(object_id)
	_routes.erase(object_id)
	if _cards.has(object_id):
		remove_child(_cards[object_id])
		_cards[object_id].queue_free()
		_cards.erase(object_id)
	if is_landing and route != null:
		landed.emit(route)
