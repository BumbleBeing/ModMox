extends GutTest
## Card Flights: where a card that changed zones is drawn while it flies from where it was
## to where it landed, and which cards a snapshot's events put in the air (13d-2).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SECONDS: float = 0.4
const HERE: Vector2 = Vector2(100, 200)
const THERE: Vector2 = Vector2(300, 600)

var _flights: CardFlights


func before_each() -> void:
	_flights = CardFlights.new()
	_flights.seconds = SECONDS


func test_a_flight_eases_from_where_it_left_to_where_it_lands() -> void:
	_flights.launch(7, FacePose.of(HERE, 250.0, 0.0), FacePose.of(THERE, 150.0, 0.0))

	assert_true(_flights.is_flying(7))
	assert_eq(_flights.pose_of(7).center, HERE)
	assert_eq(_flights.along_of(7), 0.0)
	_wait(SECONDS / 2.0)
	assert_almost_eq(_flights.pose_of(7).center, Vector2(200, 400), Vector2(0.01, 0.01), "Half-way at half-time.")
	assert_almost_eq(_flights.pose_of(7).height, 200.0, 0.01)
	_wait(SECONDS / 4.0)
	assert_almost_eq(_flights.along_of(7), 0.84375, 0.001, "Slow at both ends.")
	assert_false(_flights.has_landed(7))
	_wait(SECONDS / 4.0)
	assert_eq(_flights.pose_of(7).center, THERE)
	assert_true(_flights.has_landed(7), "It has landed, and is flying until it is taken down.")
	assert_true(_flights.is_flying(7))

	_flights.land(7)

	assert_false(_flights.is_flying(7))
	assert_eq(_flights.ids(), [] as Array[int])
	assert_null(_flights.pose_of(7))


func test_a_flight_aimed_somewhere_new_keeps_its_start_and_its_time() -> void:
	_flights.launch(7, FacePose.of(HERE, 250.0, 0.0), FacePose.of(HERE, 250.0, 0.0))
	_wait(SECONDS / 2.0)

	_flights.aim(7, FacePose.of(THERE, 150.0, 0.0))

	assert_almost_eq(_flights.pose_of(7).center, Vector2(200, 400), Vector2(0.01, 0.01))
	_flights.aim(8, FacePose.of(THERE, 150.0, 0.0))
	assert_false(_flights.is_flying(8), "Aiming a card that is not in the air does nothing.")


func test_with_no_time_to_fly_a_flight_has_landed_at_once() -> void:
	_flights.seconds = 0.0

	_flights.launch(7, FacePose.of(HERE, 250.0, 0.0), FacePose.of(THERE, 150.0, 0.0))

	assert_true(_flights.has_landed(7))
	assert_eq(_flights.pose_of(7).center, THERE)


func test_a_slow_frame_counts_for_a_thirtieth_of_a_second_at_most() -> void:
	_flights.launch(7, FacePose.of(HERE, 250.0, 0.0), FacePose.of(THERE, 150.0, 0.0))

	_flights.advance(5.0)

	assert_false(_flights.has_landed(7))
	assert_almost_eq(_flights.along_of(7), FaceMotion.ease_of(CardFlights.LONGEST_FRAME / SECONDS), 0.0001)


func test_a_card_that_disappears_where_it_lands_fades_out_over_the_last_of_its_flight() -> void:
	_flights.launch(7, FacePose.of(HERE, 250.0, 0.0), FacePose.of(THERE, 60.0, 0.0), false, true)

	assert_eq(_flights.pose_of(7).alpha, 1.0)
	_wait(SECONDS / 2.0)
	assert_eq(_flights.pose_of(7).alpha, 1.0, "Solid for most of the way.")
	_wait(SECONDS * 0.4)
	assert_lt(_flights.pose_of(7).alpha, 0.2)
	_wait(SECONDS * 0.1)
	assert_eq(_flights.pose_of(7).alpha, 0.0)


func test_a_card_that_appears_from_nothing_fades_in_over_the_first_of_its_flight() -> void:
	_flights.launch(7, FacePose.of(HERE, 60.0, 0.0), FacePose.of(THERE, 150.0, 0.0), true, false)

	assert_eq(_flights.pose_of(7).alpha, 0.0)
	_wait(SECONDS * 0.1)
	assert_between(_flights.pose_of(7).alpha, 0.01, 0.2)
	_wait(SECONDS * 0.4)
	assert_eq(_flights.pose_of(7).alpha, 1.0)
	_wait(SECONDS / 2.0)
	assert_eq(_flights.pose_of(7).alpha, 1.0)
	assert_eq(CardFlights.FADE_SHARE, 0.25, "A quarter of the way, as the prototype settled on.")


func test_clearing_takes_every_card_out_of_the_air() -> void:
	_flights.launch(7, FacePose.of(HERE, 250.0, 0.0), FacePose.of(THERE, 150.0, 0.0))
	_flights.launch(3, FacePose.of(HERE, 250.0, 0.0), FacePose.of(THERE, 150.0, 0.0))
	assert_eq(_flights.ids(), [3, 7] as Array[int], "In ID order.")

	_flights.clear()

	assert_eq(_flights.ids(), [] as Array[int])


func test_a_land_played_is_one_route_from_the_hand_to_the_battlefield() -> void:
	var presenter: EncounterPresenter = _at_main([Scenario.basic_land("Forest")])
	var in_hand: MmObjectView = presenter.snapshot().view.hand[0]

	_act(presenter, PlayLandAction)

	var routes: Array[CardFlights.Route] = CardFlights.routes(presenter.snapshot().events)
	assert_eq(routes.size(), 1)
	assert_eq(routes[0].first_object_id, in_hand.id)
	assert_eq(routes[0].card_id, in_hand.card_id)
	assert_eq(routes[0].object_id, presenter.snapshot().view.battlefield[0].id)
	assert_eq(routes[0].from_zone_kind, MmZone.Kind.HAND)
	assert_eq(routes[0].from_owner_id, HERO)
	assert_eq(routes[0].to_zone_kind, MmZone.Kind.BATTLEFIELD)


func test_a_card_that_passes_through_a_zone_is_one_route() -> void:
	var presenter: EncounterPresenter = _at_main([Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))])
	var in_hand: MmObjectView = presenter.snapshot().view.hand[0]
	var events: Array[MmEvent] = []
	presenter.changed.connect(func(snapshot: EncounterSnapshot) -> void: events.append_array(snapshot.events))

	# The Hero's own spell is passed for them and the Villain passes: it resolves.
	_act(presenter, CastSpellAction)

	var routes: Array[CardFlights.Route] = CardFlights.routes(events)
	assert_eq(routes.size(), 1, "Hand to stack to battlefield is one flight.")
	assert_eq(routes[0].first_object_id, in_hand.id)
	assert_eq(routes[0].object_id, presenter.snapshot().view.battlefield[0].id)
	assert_eq(routes[0].from_zone_kind, MmZone.Kind.HAND)
	assert_eq(routes[0].to_zone_kind, MmZone.Kind.BATTLEFIELD)


func test_events_that_move_no_card_make_no_route() -> void:
	var presenter: EncounterPresenter = _at_main([Scenario.basic_land("Forest")])

	presenter.pass_priority()
	presenter.wait_until_idle()

	assert_false(presenter.snapshot().events.is_empty())
	assert_eq(CardFlights.routes(presenter.snapshot().events).size(), 0)


## A presenter whose Hero, with a deck of [param cards] over and over, has priority in their
## first main phase.
func _at_main(cards: Array[MmCardDefinition]) -> EncounterPresenter:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	var presenter: EncounterPresenter = EncounterPresenter.new(
			Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40)), DefaultAnswerAgent.new())
	presenter.set_auto_passing(false)
	presenter.start()
	presenter.wait_until_idle()
	if presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		presenter.wait_until_idle()
	presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	presenter.wait_until_idle()
	for attempt: int in 20:
		if presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN:
			break
		presenter.pass_priority()
		presenter.wait_until_idle()
	return presenter


func _act(presenter: EncounterPresenter, kind: Script) -> void:
	var priority: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	for index: int in priority.actions.size():
		if is_instance_of(priority.actions[index], kind):
			assert_eq(presenter.answer(index), "")
			presenter.wait_until_idle()
			return
	fail_test("No such action.")


## Lets [param seconds] go by in short frames, and a hair more.
func _wait(seconds: float) -> void:
	var frames: int = ceili(seconds / 0.01)
	for frame: int in frames:
		_flights.advance(seconds / frames)
	_flights.advance(0.000001)
