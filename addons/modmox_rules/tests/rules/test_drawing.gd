extends GutTest
## CR 121: drawing a card moves the top card of a library to its owner's hand.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_drawing_creates_a_new_game_object_with_the_same_card_identity() -> void:
	# ADR 0008 / CR 400.7: a card that changes zones becomes a new object.
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	var draws: Array[ZoneChangeEvent] = _draws(engine)

	assert_eq(draws.size(), 14, "Both players draw an opening hand of seven.")
	for draw: ZoneChangeEvent in draws:
		assert_ne(draw.new_object_id, draw.object_id, "A drawn card must get a new object ID.")
		var drawn: MmGameObject = engine.game_state().object(draw.new_object_id)
		assert_eq(drawn.card_id, draw.card_id, "The card identity must survive the zone change.")
		assert_null(engine.game_state().object(draw.object_id), "The old object must no longer exist.")


func test_drawing_takes_cards_from_the_top_of_the_library() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES, 1, 10, 10))
	engine.submit(ChoosePlayOrDrawDecision.Choice.PLAY)

	# The shuffle happened just before the draws; the log records the order it produced.
	var shuffled_card_ids: Array[int] = []
	for event: MmEvent in engine.event_log():
		var shuffle: ShuffleEvent = event as ShuffleEvent
		if shuffle != null and shuffle.zone_kind == MmZone.Kind.LIBRARY and shuffle.owner_id == engine.hero().id:
			shuffled_card_ids = (event as ShuffleEvent).card_ids_after

	assert_eq(Scenario.card_ids(engine.hero().hand), shuffled_card_ids.slice(0, 7))
	assert_eq(Scenario.card_ids(engine.hero().library), shuffled_card_ids.slice(7))


func test_a_short_library_draws_as_many_cards_as_it_has() -> void:
	# They lose at the first state-based action check (CR 704.5b; see test_encounter_end.gd).
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 1, 5, 40))

	assert_eq(engine.hero().hand.size(), 5)
	assert_eq(engine.hero().library.size(), 0)
	assert_eq(engine.villain().hand.size(), 7)


func _draws(engine: MmEngine) -> Array[ZoneChangeEvent]:
	var result: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		if event is ZoneChangeEvent and (event as ZoneChangeEvent).reason == ZoneChangeEvent.Reason.DRAW:
			result.append(event as ZoneChangeEvent)
	return result
