extends GutTest
## Card Flights on the Encounter Screen: a card that changes zones is drawn once, in the
## air, from where it was to where it lands, in place of fading out there and in here
## (13d-2).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const MOVE: float = 0.25
const FLIGHT: float = 0.4
const NEAR: Vector2 = Vector2(1.0, 1.0)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced, and a card that has landed, are freed at the end of the frame.
	await wait_process_frames(2)


func test_no_card_flies_until_the_screen_is_told_to_play_at_the_games_pace() -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	assert_eq(_screen.card_flights().seconds, 0.0)

	_screen.use_game_pace(EncounterPresenter.new(_bears(), DefaultAnswerAgent.new()))

	assert_almost_eq(_screen.card_flights().seconds, GameSpeed.seconds(Pacing.FLIGHT_SECONDS, GameSpeed.Speed.NORMAL), 0.0001)
	assert_lt(Pacing.FLIGHT_SECONDS * 1000.0, float(Pacing.ACTION_MSEC), "A flight lands before the Villain's next action.")


func test_with_flights_off_a_card_is_simply_where_it_belongs() -> void:
	_open(_bears(), 0.0)

	_play("Forest")

	var forest: int = _permanents("Forest")[0]
	assert_eq(_screen.card_flights().ids(), [] as Array[int])
	assert_null(_screen.flight_card_of(forest))


func test_nothing_flies_through_the_pregame() -> void:
	_open(_bears())

	assert_eq(_screen.card_flights().ids(), [] as Array[int], "Opening hands are not dealt through the air.")


func test_a_land_played_flies_from_its_place_in_the_hand_to_its_place_in_the_row() -> void:
	_open(_bears())
	var from: Vector2 = _middle(_screen.face_of(_in_hand("Forest")))

	_play("Forest")

	var forest: int = _permanents("Forest")[0]
	var card: FlightCard = _screen.flight_card_of(forest)
	var to: Vector2 = _screen.face_motion().rest_of(forest).center
	assert_almost_eq(card.position, from, NEAR, "It starts where it was in the hand.")
	assert_true(card.leaving_face() is CardFace)
	assert_true(card.landing_face() is BattlefieldFace)
	assert_eq(_screen.face_of(forest).modulate.a, 0.0, "Its place in the row shows nothing until it lands.")
	_advance(FLIGHT / 2.0)
	assert_almost_eq(card.position, (from + to) / 2.0, NEAR)
	assert_eq(_screen.face_of(forest).modulate.a, 0.0)
	_advance(FLIGHT / 2.0)

	assert_null(_screen.flight_card_of(forest))
	assert_true(card.is_queued_for_deletion())
	assert_eq(_screen.face_of(forest).modulate.a, 1.0, "It has landed.")
	assert_eq(_screen.card_flights().ids(), [] as Array[int])


func test_a_flying_card_is_over_every_window_and_takes_no_clicks() -> void:
	_open(_bears())
	_play("Forest")
	var card: FlightCard = _screen.flight_card_of(_permanents("Forest")[0])
	var layer: Control = card.get_parent() as Control

	_screen.stack_window().move_to_front()

	assert_gt(layer.z_index, 1, "Over a window a click brought to the front, and over the card of the hand that is raised.")
	assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_null(ClickCatcher.of(card))


func test_a_redraw_mid_flight_carries_the_card_on_from_where_it_had_got_to() -> void:
	_open(_bears())
	_play("Forest")
	var forest: int = _permanents("Forest")[0]
	var card: FlightCard = _screen.flight_card_of(forest)
	_advance(FLIGHT / 2.0)
	var before: Vector2 = card.position
	var face: Control = _screen.face_of(forest)

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	assert_ne(_screen.face_of(forest), face, "The board was rebuilt.")
	assert_same(_screen.flight_card_of(forest), card)
	assert_almost_eq(card.position, before, NEAR)
	assert_eq(_screen.face_of(forest).modulate.a, 0.0, "The new face shows nothing either.")
	_advance(FLIGHT / 2.0)
	assert_null(_screen.flight_card_of(forest))
	assert_eq(_screen.face_of(forest).modulate.a, 1.0)


func test_a_creature_that_dies_flies_to_its_owners_graveyard_and_leaves_no_ghost() -> void:
	_open(_setup_of([_bear(), Scenario.free_shock("Zap", 2)]))
	_cast("Bear")
	_resolve()
	_settle()
	var bear: int = _permanents("Bear")[0]
	var place: Vector2 = _middle(_screen.face_of(bear))

	_cast("Zap")
	_target(bear)
	_resolve()

	var dead: int = _in_graveyard("Bear")
	var card: FlightCard = _screen.flight_card_of(dead)
	assert_null(_screen.ghost_of(bear), "It flies; it does not fade where it stood.")
	assert_almost_eq(card.position, place, NEAR)
	assert_true(card.leaving_face() is BattlefieldFace)
	assert_true(card.landing_face() is CardFace)
	assert_eq(_screen.pile_text("hero_graveyard"), "Graveyard (2)", "The count changes at once.")
	assert_eq(_screen.face_of(dead).modulate.a, 0.0, "The pile shows it once it lands.")
	_settle()

	assert_null(_screen.flight_card_of(dead))
	assert_eq(_screen.face_of(dead).modulate.a, 1.0)
	assert_almost_eq(card.position, _pile("hero_graveyard"), NEAR)


func test_a_pile_shows_the_card_under_the_one_still_in_the_air() -> void:
	_open(_setup_of([_bear(), Scenario.free_shock("Zap", 2)]))
	_cast("Bear")
	_resolve()
	_settle()
	_cast("Zap")
	_target(_permanents("Bear")[0])
	_resolve()
	_settle()
	_cast("Bear")
	_resolve()
	_settle()
	var under: int = _presenter.snapshot().view.graveyards[HERO].back().id
	_cast("Zap")
	_target(_permanents("Bear")[0])
	_resolve()

	assert_eq(_screen.face_of(under).modulate.a, 1.0, "The card that was on top is still seen")
	assert_eq(_screen.face_of(_presenter.snapshot().view.graveyards[HERO].back().id).modulate.a, 0.0, "until the new one lands.")


func test_a_spell_cast_flies_to_the_art_of_its_entry_in_the_stack_window_and_fades_out_there() -> void:
	_open(_bears())
	var from: Vector2 = _middle(_screen.face_of(_in_hand("Bear")))

	_presenter.is_hold_key_down = true
	_cast("Bear")
	_presenter.is_hold_key_down = false
	# The Stack Window's entries find their places a frame later.
	await wait_process_frames(2)

	var spell: int = _presenter.snapshot().view.stack[0].id
	var card: FlightCard = _screen.flight_card_of(spell)
	assert_almost_eq(card.position, from, NEAR)
	assert_null(card.landing_face(), "A card all the way.")
	_advance(FLIGHT / 2.0)
	assert_eq(card.modulate.a, 1.0, "Solid for most of the way.")
	_advance(FLIGHT * 0.45)
	assert_lt(card.modulate.a, 0.2)
	assert_almost_eq(card.position, _art_of(spell), Vector2(6, 6))
	assert_almost_eq(card.leaving_face().scale.y * card.leaving_face().size.y, StackEntry.ART_SIZE, 3.0, "As small as the art.")
	_advance(FLIGHT * 0.05)
	assert_null(_screen.flight_card_of(spell))


func test_a_permanent_spell_that_resolves_fades_in_at_its_entry_and_flies_to_its_row() -> void:
	_open(_bears())
	_presenter.is_hold_key_down = true
	_cast("Bear")
	_presenter.is_hold_key_down = false
	await wait_process_frames(2)
	_settle()
	var from: Vector2 = _art_of(_presenter.snapshot().view.stack[0].id)

	_resolve()

	var bear: int = _permanents("Bear")[0]
	var card: FlightCard = _screen.flight_card_of(bear)
	assert_almost_eq(card.position, from, NEAR)
	assert_eq(card.modulate.a, 0.0, "It appears from nothing.")
	assert_true(card.landing_face() is BattlefieldFace)
	_advance(FLIGHT / 2.0)
	assert_eq(card.modulate.a, 1.0)
	_advance(FLIGHT / 2.0)
	assert_null(_screen.flight_card_of(bear))
	assert_eq(_screen.face_of(bear).modulate.a, 1.0)


func test_a_spell_that_resolves_while_on_its_way_to_the_stack_flies_on_from_where_it_had_got_to() -> void:
	_open(_setup_of([Scenario.instant("Spark", Scenario.mana_cost(0), [], [])]))
	var from: Vector2 = _middle(_screen.face_of(_in_hand("Spark")))

	# The Hero's own spell is passed for them and the Villain passes, before the card has
	# got anywhere.
	_cast("Spark")

	var spark: int = _in_graveyard("Spark")
	var card: FlightCard = _screen.flight_card_of(spark)
	assert_almost_eq(card.position, from, NEAR)
	assert_eq(card.modulate.a, 1.0, "It is already in the air, so it does not fade in.")
	_settle()
	assert_almost_eq(card.position, _pile("hero_graveyard"), NEAR)


func test_an_instant_that_resolves_from_the_stack_flies_from_its_entry_to_the_graveyard() -> void:
	_open(_setup_of([Scenario.instant("Spark", Scenario.mana_cost(0), [], [])]))
	_presenter.is_hold_key_down = true
	_cast("Spark")
	_presenter.is_hold_key_down = false
	await wait_process_frames(2)
	_settle()
	var from: Vector2 = _art_of(_presenter.snapshot().view.stack[0].id)

	_resolve()

	var card: FlightCard = _screen.flight_card_of(_in_graveyard("Spark"))
	assert_almost_eq(card.position, from, NEAR)
	assert_eq(card.modulate.a, 0.0)


func test_the_heros_draw_turns_face_up_on_its_way_from_the_library_and_the_villains_stays_a_back() -> void:
	_open(_bears())
	_settle()
	_pass_until(func() -> bool:
		return _presenter.snapshot().view.active_player_id == VILLAIN and _presenter.snapshot().view.step == MmTurn.Step.DRAW)

	var villains: Array[int] = _screen.card_flights().ids()
	assert_eq(villains.size(), 1, "The Villain drew.")
	var back: FlightCard = _screen.flight_card_of(villains[0])
	assert_true(back.is_face_down())
	assert_almost_eq(back.position, _pile("villain_library"), NEAR)
	var villain_hand: int = _presenter.snapshot().view.hand_sizes[VILLAIN]
	assert_eq(_screen.villain_card_back_count(), villain_hand - 1, "The Villain's hand grows when the card lands.")
	_settle()
	assert_eq(_screen.villain_card_back_count(), villain_hand)
	assert_almost_eq(back.position, EncounterLayout.regions(SCREEN)["villain_hand"].get_center(), NEAR)

	var held: Array[int] = _hand_ids()
	_pass_until(func() -> bool:
		return _presenter.snapshot().view.active_player_id == HERO and _presenter.snapshot().view.step == MmTurn.Step.DRAW)

	var drawn: int = -1
	for object_id: int in _hand_ids():
		if not held.has(object_id):
			drawn = object_id
	var card: FlightCard = _screen.flight_card_of(drawn)
	assert_almost_eq(card.position, _pile("hero_library"), NEAR)
	assert_false(card.leaving_face() is CardFace, "A back as it leaves the library,")
	assert_true(card.landing_face() is CardFace, "and its face as it reaches the hand.")
	assert_null(_screen.face_of(drawn), "It is not in the hand until it lands.")
	_settle()
	assert_almost_eq(card.position, _middle(_screen.face_of(drawn)), NEAR)
	assert_eq(_screen.face_of(drawn).modulate.a, 1.0)


func test_cards_drawn_together_leave_the_library_one_at_a_time() -> void:
	_open(_setup_of([Scenario.free_draw("Insight", 3)]))
	_screen.card_flights().gap_seconds = 0.1
	_settle()
	var held: Array[int] = _hand_ids()
	_presenter.is_hold_key_down = true
	_cast("Insight")
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	for index: int in target.candidates.size():
		if not target.candidates[index].is_object() and target.candidates[index].id == HERO:
			_presenter.answer(index)
			break
	_presenter.wait_until_idle()
	_presenter.is_hold_key_down = false
	await wait_process_frames(2)
	_settle()
	held.erase(_presenter.snapshot().view.stack[0].id)

	_resolve()

	var drawn: Array[int] = []
	for object_id: int in _hand_ids():
		if not held.has(object_id) and _screen.card_flights().is_flying(object_id):
			drawn.append(object_id)
	drawn.sort()
	assert_eq(drawn.size(), 3)
	var library: Vector2 = _pile("hero_library")
	_advance(0.05)
	assert_gt(_screen.flight_card_of(drawn[0]).position.distance_to(library), 2.0, "The first has left,")
	assert_almost_eq(_screen.flight_card_of(drawn[1]).position, library, NEAR, "the second has not,")
	assert_almost_eq(_screen.flight_card_of(drawn[2]).position, library, NEAR, "nor the third.")
	_advance(0.1)
	assert_gt(_screen.flight_card_of(drawn[1]).position.distance_to(library), 2.0, "Then the second,")
	assert_almost_eq(_screen.flight_card_of(drawn[2]).position, library, NEAR)
	_advance(0.1)
	assert_gt(_screen.flight_card_of(drawn[2]).position.distance_to(library), 2.0, "then the third.")
	var other: int = -1
	for object_id: int in _hand_ids():
		if not drawn.has(object_id):
			other = object_id
	var other_at: Vector2 = _screen.face_of(other).position
	for object_id: int in drawn:
		assert_null(_screen.face_of(object_id), "None is in the hand while it is in the air.")
	_advance(0.2)
	assert_not_null(_screen.face_of(drawn[0]), "The first joins the hand as it lands,")
	assert_eq(_screen.face_of(drawn[0]).modulate.a, 1.0)
	assert_null(_screen.face_of(drawn[1]), "and the second is still on its way.")
	assert_eq(_screen.face_of(other).position, other_at, "The hand does not jump to make room: it eases from where it was.")
	_advance(0.1)
	assert_not_null(_screen.face_of(drawn[1]))
	assert_null(_screen.face_of(drawn[2]))
	var last: FlightCard = _screen.flight_card_of(drawn[2])
	_advance(FLIGHT * 1.5)
	assert_almost_eq(last.position, _middle(_screen.face_of(drawn[2])), NEAR, "Each lands on the place it takes.")
	for object_id: int in drawn:
		assert_eq(_screen.face_of(object_id).modulate.a, 1.0, "Each is in the hand once it lands.")
	assert_eq(_screen.card_flights().ids(), [] as Array[int])


func test_a_discarded_card_flies_from_the_hand_to_the_graveyard() -> void:
	_open(_bears())
	_settle()
	_pass_until(func() -> bool: return _presenter.snapshot().decision is ChooseCardsToDiscardDecision)
	_settle()
	var discard: ChooseCardsToDiscardDecision = _presenter.snapshot().decision as ChooseCardsToDiscardDecision
	var from: Vector2 = _middle(_screen.face_of(discard.candidate_ids[0]))

	_presenter.answer(discard.candidate_ids.slice(0, discard.count))
	_presenter.wait_until_idle()

	var card: FlightCard = _screen.flight_card_of(_presenter.snapshot().view.graveyards[HERO].back().id)
	assert_almost_eq(card.position, from, NEAR)
	assert_null(card.landing_face())


func test_an_undo_takes_every_card_out_of_the_air_and_flies_nothing() -> void:
	_open(_bears())
	_play("Forest")
	var card: FlightCard = _screen.flight_card_of(_permanents("Forest")[0])

	_screen.undo()

	assert_eq(_screen.card_flights().ids(), [] as Array[int], "A rewind is not something that happened in the game.")
	assert_true(card.is_queued_for_deletion())
	assert_eq(_screen.face_of(_in_hand("Forest")).modulate.a, 1.0, "The card is back in the hand at once.")

	_play("Forest")
	assert_not_null(_screen.flight_card_of(_permanents("Forest")[0]), "What happens after an undo flies as usual.")


func test_a_window_of_another_size_lands_every_card_at_once() -> void:
	_open(_bears())
	_play("Forest")
	var forest: int = _permanents("Forest")[0]

	_screen.size = Vector2(1600, 1000)

	assert_eq(_screen.card_flights().ids(), [] as Array[int])
	assert_null(_screen.flight_card_of(forest))
	assert_eq(_screen.face_of(forest).modulate.a, 1.0)


func test_a_permanent_that_leaves_while_scrolled_out_of_sight_flies_from_the_arrow_at_that_end_of_its_line() -> void:
	_open(_setup_of([_bear(), _bear(), Scenario.free_shock("Zap", 2)]))
	for bear: int in 4:
		_cast("Bear")
		_resolve()
	_settle()
	# Narrow enough that the last Bear is out of sight at the right end of its line.
	_screen.size = Vector2(1100, 1080)
	_screen.line("hero_creatures").scroll_to(0.0)
	var arrow: Vector2 = _screen.line("hero_creatures").right_arrow().get_global_rect().get_center() - _screen.global_position
	var bears: Array[int] = _permanents("Bear")

	_cast("Zap")
	_target(bears[3])
	_resolve()

	var card: FlightCard = _screen.flight_card_of(_in_graveyard("Bear"))
	assert_almost_eq(card.position, arrow, NEAR)
	assert_lt(card.leaving_face().scale.y * (card.leaving_face() as BattlefieldFace).card().size.y,
			_screen.face_motion().rest_of(bears[0]).height, "Small as it comes out from under the arrow.")


func test_a_card_returned_from_a_graveyard_flies_from_its_pile() -> void:
	_check_a_raised_bear_flies_from_the_pile(false)


func test_a_card_returned_from_a_graveyard_flies_from_its_pile_with_its_window_open_too() -> void:
	_check_a_raised_bear_flies_from_the_pile(true)


func _check_a_raised_bear_flies_from_the_pile(is_window_open: bool) -> void:
	_open(_setup_of([_bear(), Scenario.free_shock("Zap", 2), Scenario.free_raise("Raise")]))
	_cast("Bear")
	_resolve()
	_settle()
	_cast("Zap")
	_target(_permanents("Bear")[0])
	_resolve()
	_settle()
	if is_window_open:
		_screen.pile_catcher("hero_graveyard").clicked.emit()
	var held: Array[int] = _ids_in_hand()

	_cast("Raise")
	_target(_in_graveyard("Bear"))
	_resolve()

	var returned: int = -1
	for id: int in _ids_in_hand():
		if not held.has(id):
			returned = id
	var card: FlightCard = _screen.flight_card_of(returned)
	assert_not_null(card, "The Bear is in the air.")
	if card != null:
		assert_almost_eq(card.position, _pile("hero_graveyard"), NEAR, "From the pile, not from the window.")
	assert_eq(_screen.pile_window("hero_graveyard").is_open(), is_window_open)
	_settle()
	assert_null(_screen.flight_card_of(returned))


func _ids_in_hand() -> Array[int]:
	var ids: Array[int] = []
	for card: MmObjectView in _presenter.snapshot().view.hand:
		ids.append(card.id)
	return ids


## Opens a screen whose faces take MOVE seconds to move and whose cards take
## [param flight_seconds] to fly, with the Hero in their first main phase, auto-pass off.
## The screen does not run by itself: only _advance() lets time go by.
func _open(setup: MmEncounterSetup, flight_seconds: float = FLIGHT) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.set_process(false)
	_screen.size = SCREEN
	# Not at the corner of the window, so a place worked out from the wrong corner shows.
	_screen.position = Vector2(30, 20)
	_screen.face_motion().seconds = MOVE
	_screen.card_flights().seconds = flight_seconds
	_presenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_pass_until(func() -> bool:
		return _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN and _presenter.snapshot().view.active_player_id == HERO)


## The Hero's deck alternates Forests and free 2/2 Bears.
func _bears() -> MmEncounterSetup:
	return _setup_of([Scenario.basic_land("Forest"), _bear()])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))


func _setup_of(cards: Array[MmCardDefinition]) -> MmEncounterSetup:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	return Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40))


## Lets [param seconds] go by in short frames, and a hair more.
func _advance(seconds: float) -> void:
	var frames: int = ceili(seconds / 0.01)
	for frame: int in frames:
		_screen.advance_motion(seconds / frames)
	_screen.advance_motion(0.000001)


## Lets every move and flight finish.
func _settle() -> void:
	_advance(FLIGHT * 1.5)


## Where the middle of [param face] is drawn, in the screen's coordinates.
func _middle(face: Control) -> Vector2:
	return face.get_global_transform() * (face.size / 2.0) - _screen.global_position


## The middle of the card on the pile in Region [param key], in the screen's coordinates.
func _pile(key: String) -> Vector2:
	var pile: Rect2 = EncounterLayout.regions(_screen.size)[key]
	return pile.position + Vector2(pile.size.x / 2.0, EncounterLayout.PILE_HEIGHT / 2.0)


## The middle of the art of the Stack Window's entry for [param object_id].
func _art_of(object_id: int) -> Vector2:
	return _screen.stack_entry_of(object_id).art().get_global_rect().get_center() - _screen.global_position


## The first card named [param card_name] in the Hero's hand, as an object ID.
func _in_hand(card_name: String) -> int:
	for in_hand: MmObjectView in _presenter.snapshot().view.hand:
		if in_hand.name == card_name:
			return in_hand.id
	return -1


func _hand_ids() -> Array[int]:
	var ids: Array[int] = []
	for in_hand: MmObjectView in _presenter.snapshot().view.hand:
		ids.append(in_hand.id)
	return ids


## The last card named [param card_name] put into the Hero's graveyard, as an object ID.
func _in_graveyard(card_name: String) -> int:
	var found: int = -1
	for card: MmObjectView in _presenter.snapshot().view.graveyards[HERO]:
		if card.name == card_name:
			found = card.id
	return found


func _cast(card_name: String) -> void:
	_act(CastSpellAction, card_name)


func _play(card_name: String) -> void:
	_act(PlayLandAction, card_name)


func _act(kind: Script, card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if is_instance_of(action, kind) and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("No %s action for %s." % [kind.resource_path.get_file(), card_name])


## Aims the spell being cast at Game Object [param object_id].
func _target(object_id: int) -> void:
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	for index: int in target.candidates.size():
		if target.candidates[index].is_object() and target.candidates[index].id == object_id:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("Nothing can target %d." % object_id)


## Passes until the stack is empty.
func _resolve() -> void:
	for attempt: int in 10:
		if _presenter.snapshot().view.stack.is_empty():
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


func _permanents(card_name: String) -> Array[int]:
	var found: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			found.append(permanent.id)
	return found


## Passes, one answer at a time, until [param is_there] says to stop.
func _pass_until(is_there: Callable) -> void:
	for attempt: int in 200:
		if is_there.call():
			return
		var decision: MmPendingDecision = _presenter.snapshot().decision
		if decision is PriorityDecision:
			_presenter.pass_priority()
		elif decision is ChooseCardsToDiscardDecision:
			var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
			_presenter.answer(discard.candidate_ids.slice(0, discard.count))
		else:
			_presenter.answer([])
		_presenter.wait_until_idle()
