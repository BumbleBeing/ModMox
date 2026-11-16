extends GutTest
## The Flight Layer (game glossary, 13k): where Card Flights are worked out and drawn,
## driven here from made-up zone changes, hand-built snapshots and fixed places, with no
## engine. It asks where a zone is drawn and touches nothing else.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SECONDS: float = 0.4
const GAP: float = 0.1
const HAND_PLACE: Vector2 = Vector2(900, 950)
const FIELD_PLACE: Vector2 = Vector2(800, 600)
const STACK_PLACE: Vector2 = Vector2(1500, 300)
const LIBRARY_PLACE: Vector2 = Vector2(1800, 900)
const GRAVEYARD_PLACE: Vector2 = Vector2(1800, 1000)

var _layer: FlightLayer
## Where each zone is drawn, by _key(); what the fake place_of() answers.
var _places: Dictionary[String, FacePose] = {}
var _redraws: int = 0


func before_each() -> void:
	_layer = FlightLayer.new()
	_layer.size = Vector2(1920, 1080)
	add_child_autofree(_layer)
	_layer.seconds = SECONDS
	_layer.gap_seconds = GAP
	_layer.setup(_place_of)
	_redraws = 0
	_places.clear()
	_put(MmZone.Kind.HAND, HERO, HAND_PLACE, 250.0)
	_put(MmZone.Kind.BATTLEFIELD, HERO, FIELD_PLACE, 140.0)
	_put(MmZone.Kind.STACK, MmZone.NO_OWNER, STACK_PLACE, StackEntry.ART_SIZE)
	_put(MmZone.Kind.LIBRARY, HERO, LIBRARY_PLACE, 96.0)
	_put(MmZone.Kind.GRAVEYARD, HERO, GRAVEYARD_PLACE, 96.0)


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


# --- Flying ---


func test_a_card_that_changed_zones_flies_from_where_it_was_to_where_it_lands() -> void:
	watch_signals(_layer)

	_fly([_moved(1, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.BATTLEFIELD, HERO, 2)])

	assert_eq(_redraws, 1, "The board was drawn once.")
	assert_true(_layer.is_flying(2), "Kept by the Game Object that lands.")
	var card: FlightCard = _layer.flight_card_of(2)
	assert_not_null(card)
	assert_eq(card.get_parent(), _layer)
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(card.position, HAND_PLACE, "It starts where it was.")
	assert_signal_emitted(_layer, "took_off")
	assert_eq((get_signal_parameters(_layer, "took_off")[0] as CardFlights.Route).object_id, 2)

	_frames(SECONDS / 2.0)
	assert_almost_eq(card.position, HAND_PLACE.lerp(FIELD_PLACE, 0.5), Vector2(0.5, 0.5), "Half-way at half-time.")
	_frames(SECONDS / 2.0 + 0.02)

	assert_false(_layer.is_flying(2))
	assert_null(_layer.flight_card_of(2))
	assert_true(card.is_queued_for_deletion(), "It is taken down where it landed.")
	assert_signal_emitted(_layer, "landed")
	var route: CardFlights.Route = get_signal_parameters(_layer, "landed")[0]
	assert_eq(route.first_object_id, 1)
	assert_eq(route.to_zone_kind, MmZone.Kind.BATTLEFIELD)


func test_where_a_card_was_is_read_before_the_redraw_and_where_it_lands_after() -> void:
	var redraw: Callable = func() -> void:
		_redraws += 1
		_put(MmZone.Kind.HAND, HERO, Vector2(100, 100), 250.0)
		_put(MmZone.Kind.BATTLEFIELD, HERO, Vector2(400, 400), 140.0)

	_layer.show_snapshot(_snapshot([]), _snapshot([_moved(1, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.BATTLEFIELD, HERO, 2)]), redraw)

	assert_eq(_layer.flight_card_of(2).position, HAND_PLACE, "From the board as it was drawn before")
	_frames(SECONDS - 0.01)
	assert_almost_eq(_layer.flight_card_of(2).position, Vector2(400, 400), Vector2(2, 2), "to the board as it is drawn now.")


func test_a_flight_is_aimed_again_every_frame_as_its_landing_place_moves() -> void:
	_fly([_moved(1, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.BATTLEFIELD, HERO, 2)])
	_frames(SECONDS / 2.0)

	# A line is scrolled, or the hand makes room: the landing place moves under it.
	_put(MmZone.Kind.BATTLEFIELD, HERO, Vector2(300, 300), 140.0)
	_frames(SECONDS / 2.0 - 0.01)

	assert_almost_eq(_layer.flight_card_of(2).position, Vector2(300, 300), Vector2(2, 2))


func test_a_card_put_on_the_stack_fades_out_at_its_entry_and_one_leaving_it_fades_in() -> void:
	_fly([_moved(1, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.STACK, MmZone.NO_OWNER, 2)])
	var going: FlightCard = _layer.flight_card_of(2)
	assert_eq(going.modulate.a, 1.0, "It leaves the hand solid")
	_frames(SECONDS - 0.01)
	assert_lt(going.modulate.a, 0.1, "and is all but gone at the entry's art.")

	_fly([_moved(3, 51, MmZone.Kind.STACK, MmZone.NO_OWNER, MmZone.Kind.GRAVEYARD, HERO, 4)])

	assert_eq(_layer.flight_card_of(4).modulate.a, 0.0, "One leaving the stack appears from nothing.")


func test_a_card_still_in_the_air_carries_on_from_where_it_has_got_to() -> void:
	_fly([_moved(1, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.STACK, MmZone.NO_OWNER, 2)])
	_frames(SECONDS / 2.0)
	var first: FlightCard = _layer.flight_card_of(2)
	var reached: Vector2 = first.position
	watch_signals(_layer)

	# It resolved before it reached the stack.
	_fly([_moved(2, 50, MmZone.Kind.STACK, MmZone.NO_OWNER, MmZone.Kind.BATTLEFIELD, HERO, 3)])

	assert_false(_layer.is_flying(2), "The first flight is over")
	assert_true(first.is_queued_for_deletion())
	assert_true(_layer.is_flying(3), "and the card flies on")
	assert_almost_eq(_layer.flight_card_of(3).position, reached, Vector2(0.5, 0.5), "from where it had got to, not from the stack.")
	assert_eq(_layer.flight_card_of(3).modulate.a, 1.0, "It is there to be seen: it does not fade in.")
	assert_signal_not_emitted(_layer, "landed", "It never landed on the stack.")


func test_cards_drawn_together_leave_the_library_one_after_another_and_join_the_hand_as_each_lands() -> void:
	watch_signals(_layer)
	_fly([
		_moved(1, 60, MmZone.Kind.LIBRARY, HERO, MmZone.Kind.HAND, HERO, 11),
		_moved(2, 61, MmZone.Kind.LIBRARY, HERO, MmZone.Kind.HAND, HERO, 12),
	])

	assert_eq(_layer.drawn_in_air(HERO), [60, 61] as Array[int], "In the order they land, by Card Identity.")
	assert_eq(_layer.drawn_in_air(VILLAIN), [] as Array[int])
	assert_eq(_layer.flying_into_hand(HERO), [] as Array[int], "A drawn card is not flying in some other way.")
	_frames(GAP * 0.8)
	assert_ne(_layer.flight_card_of(11).position, LIBRARY_PLACE, "The first has left")
	assert_eq(_layer.flight_card_of(12).position, LIBRARY_PLACE, "and the second waits its turn.")

	_frames(SECONDS - GAP * 0.8 + 0.02)
	assert_eq(_layer.drawn_in_air(HERO), [61] as Array[int], "The first has landed.")
	assert_signal_emit_count(_layer, "landed", 1)
	_frames(GAP + 0.02)
	assert_eq(_layer.drawn_in_air(HERO), [] as Array[int])
	assert_signal_emit_count(_layer, "landed", 2)


func test_a_card_returned_to_the_hand_is_flying_into_it_and_was_not_drawn() -> void:
	_fly([_moved(1, 70, MmZone.Kind.BATTLEFIELD, HERO, MmZone.Kind.HAND, HERO, 2)])

	assert_eq(_layer.flying_into_hand(HERO), [70] as Array[int])
	assert_eq(_layer.drawn_in_air(HERO), [] as Array[int])
	assert_eq(_layer.flying_into_hand(VILLAIN), [] as Array[int])


func test_landing_everything_at_once_takes_every_card_down_and_says_so() -> void:
	_fly([
		_moved(1, 60, MmZone.Kind.LIBRARY, HERO, MmZone.Kind.HAND, HERO, 11),
		_moved(3, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.BATTLEFIELD, HERO, 4),
	])
	watch_signals(_layer)

	_layer.land_all()

	assert_false(_layer.is_flying(11))
	assert_false(_layer.is_flying(4))
	assert_eq(_layer.drawn_in_air(HERO), [] as Array[int])
	assert_signal_emit_count(_layer, "landed", 2)
	assert_eq(_layer.get_child_count(), 0)


# --- What does not fly ---


func test_nothing_flies_at_no_speed_and_the_board_is_still_drawn() -> void:
	_layer.seconds = 0.0

	_fly([_moved(1, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.BATTLEFIELD, HERO, 2)])

	assert_eq(_redraws, 1)
	assert_false(_layer.is_flying(2))
	assert_eq(_layer.get_child_count(), 0)


func test_nothing_flies_for_a_rewind_or_for_the_first_snapshot() -> void:
	var rewind: EncounterSnapshot = _snapshot([_moved(1, 50, MmZone.Kind.BATTLEFIELD, HERO, MmZone.Kind.HAND, HERO, 2)])
	rewind.is_rewind = true

	_layer.show_snapshot(_snapshot([]), rewind, _redraw)
	_layer.show_snapshot(null, _snapshot([_moved(3, 51, MmZone.Kind.HAND, HERO, MmZone.Kind.BATTLEFIELD, HERO, 4)]), _redraw)

	assert_eq(_redraws, 2)
	assert_false(_layer.is_flying(2), "An undo is not something that happened in the game (ADR 0015).")
	assert_false(_layer.is_flying(4), "With no board drawn before, a card was nowhere to fly from.")


func test_a_card_with_nowhere_to_start_from_does_not_fly_and_one_with_nowhere_to_land_comes_down() -> void:
	_places.erase(_key(MmZone.Kind.LIBRARY, HERO))
	watch_signals(_layer)

	_fly([_moved(1, 60, MmZone.Kind.LIBRARY, HERO, MmZone.Kind.HAND, HERO, 11)])

	assert_false(_layer.is_flying(11), "Nothing showed where it was.")
	assert_signal_not_emitted(_layer, "took_off")

	_places.erase(_key(MmZone.Kind.BATTLEFIELD, HERO))
	_fly([_moved(3, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.BATTLEFIELD, HERO, 4)])

	assert_false(_layer.is_flying(4), "Nothing shows where it lands, so it is taken down at once")
	assert_signal_emitted(_layer, "landed", "and that is a landing.")


func test_the_look_a_card_leaves_as_is_the_one_it_had_before_and_it_lands_as_it_is_now() -> void:
	var previous: EncounterSnapshot = _snapshot([])
	previous.looks[1] = _look("grizzly_bears")
	var next: EncounterSnapshot = _snapshot([_moved(1, 50, MmZone.Kind.HAND, HERO, MmZone.Kind.BATTLEFIELD, HERO, 2)])
	next.looks[2] = _look("hill_giant")

	_layer.show_snapshot(previous, next, _redraw)

	var card: FlightCard = _layer.flight_card_of(2)
	assert_true(card.leaving_face() is CardFace, "From the hand it leaves as a Card Face")
	assert_true(card.landing_face() is BattlefieldFace, "and lands as a Battlefield Face.")
	assert_eq(card.landing_look, next.looks[2])


# --- Helpers ---


func _place_of(route: CardFlights.Route, is_landing: bool) -> FacePose:
	var zone_kind: MmZone.Kind = route.to_zone_kind if is_landing else route.from_zone_kind
	var owner_id: int = route.to_owner_id if is_landing else route.from_owner_id
	return _places.get(_key(zone_kind, owner_id), null)


func _put(zone_kind: MmZone.Kind, owner_id: int, center: Vector2, height: float) -> void:
	_places[_key(zone_kind, owner_id)] = FacePose.of(center, height, 0.0)


func _key(zone_kind: MmZone.Kind, owner_id: int) -> String:
	return "%d/%d" % [zone_kind, owner_id]


func _redraw() -> void:
	_redraws += 1


## Shows the layer a snapshot made of [param events] after an empty one.
func _fly(events: Array[MmEvent]) -> void:
	_layer.show_snapshot(_snapshot([]), _snapshot(events), _redraw)


func _snapshot(events: Array[MmEvent]) -> EncounterSnapshot:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.events = events
	for event: MmEvent in events:
		var change: ZoneChangeEvent = event as ZoneChangeEvent
		snapshot.looks[change.new_object_id] = _look("grizzly_bears")
	return snapshot


## Card [param card_id], Game Object [param object_id], moves from one zone to another and
## becomes Game Object [param new_object_id].
func _moved(object_id: int, card_id: int, from_kind: MmZone.Kind, from_owner: int, to_kind: MmZone.Kind,
		to_owner: int, new_object_id: int) -> ZoneChangeEvent:
	var from: MmZone = MmZone.new(from_kind, from_owner)
	var card: MmGameObject = MmGameObject.new(object_id, card_id, from_owner if from_owner != MmZone.NO_OWNER else HERO, null)
	card.attach_to_zone(from)
	var change: ZoneChangeEvent = ZoneChangeEvent.new(card, MmZone.new(to_kind, to_owner), 0, ZoneChangeEvent.Reason.CAST)
	change.new_object_id = new_object_id
	return change


func _look(file_name: String) -> CardLook:
	return CardLook.of_definition(load(ALPHA % file_name) as MmCardDefinition)


## Lets [param seconds] go by a hundredth of a second at a time.
func _frames(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_layer.frame(minf(0.01, left))
		left -= 0.01
