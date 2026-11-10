extends GutTest
## Simulation Copies (ADR 0020): an engine to look ahead on, as one player might imagine the
## game, that never affects the real one.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_playing_on_a_copy_never_changes_the_real_game() -> void:
	var engine: MmEngine = _engine_in_main_phase()
	var before: String = engine.fingerprint()

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	Scenario.play_until_game_turn(copy, 4, true)

	assert_eq(engine.fingerprint(), before)
	assert_eq(copy.game_state().game_turn, 4)


func test_a_copy_starts_with_an_empty_event_log_and_no_undo() -> void:
	var engine: MmEngine = _engine_in_main_phase()

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var events_at_copy: int = copy.event_log().size()
	Scenario.play_first_land(copy)

	assert_true(copy.is_simulation())
	assert_false(engine.is_simulation())
	assert_eq(events_at_copy, 0)
	assert_gt(copy.event_log().size(), 0)
	assert_false(copy.can_undo())
	assert_eq(copy.undo(), "Nothing can be undone past this point.")


func test_a_copy_counts_the_decisions_made_before_it() -> void:
	var engine: MmEngine = _engine_in_main_phase()

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	Scenario.play_first_land(copy)

	assert_eq(copy.decision_count(), engine.decision_count() + 1)
	assert_eq(copy.decision_log().size(), 1)


func test_a_copy_redeals_only_what_the_viewer_cannot_see() -> void:
	var engine: MmEngine = _engine_in_main_phase()
	var real: MmGameState = engine.game_state()

	var first: MmGameState = engine.simulation_copy(engine.villain().id, MmRng.new(1)).game_state()
	var second: MmGameState = engine.simulation_copy(engine.villain().id, MmRng.new(2)).game_state()

	for copy: MmGameState in [first, second]:
		assert_eq(_card_ids(copy.player(1).hand), _card_ids(real.player(1).hand), "The viewer's own hand is known.")
		assert_eq(copy.player(0).hand.object_ids(), real.player(0).hand.object_ids(), "Objects keep their IDs.")
		assert_eq(copy.player(0).library.size(), real.player(0).library.size())
		assert_eq(copy.player(1).library.size(), real.player(1).library.size())
		assert_eq(_sorted(_card_ids(copy.player(0).hand) + _card_ids(copy.player(0).library)),
			_sorted(_card_ids(real.player(0).hand) + _card_ids(real.player(0).library)), "The same cards, re-dealt.")
	assert_ne(_card_ids(first.player(0).hand) + _card_ids(first.player(0).library),
		_card_ids(second.player(0).hand) + _card_ids(second.player(0).library))
	assert_ne(_card_ids(first.player(1).library), _card_ids(second.player(1).library),
		"The viewer does not know their own library's order either.")


func test_a_redealt_card_keeps_its_own_definition() -> void:
	var engine: MmEngine = _engine_in_main_phase()

	var copy: MmGameState = engine.simulation_copy(engine.villain().id, MmRng.new(3)).game_state()

	for card: MmGameObject in copy.player(0).hand.objects() + copy.player(0).library.objects():
		assert_eq(card.definition.name, copy.run_card_of(card).base.name)


func test_a_copy_reseeds_the_game_rng() -> void:
	var engine: MmEngine = _engine_in_main_phase()

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	assert_ne(copy.game_state().game_rng.describe_state(), engine.game_state().game_rng.describe_state())


func test_states_differing_only_in_hidden_cards_are_redealt_identically() -> void:
	# The fairness property (A155): the re-deal never depends on where the hidden cards were.
	var engine: MmEngine = _engine_in_main_phase()
	var real: MmGameState = engine.game_state().duplicate_state()
	var rearranged: MmGameState = engine.game_state().duplicate_state()
	rearranged.randomize_hidden_cards(engine.villain().id, MmRng.new(99))
	assert_ne(_card_ids(rearranged.player(0).hand), _card_ids(real.player(0).hand))

	real.randomize_hidden_cards(engine.villain().id, MmRng.new(5))
	rearranged.randomize_hidden_cards(engine.villain().id, MmRng.new(5))

	assert_eq(rearranged.fingerprint(), real.fingerprint())


func test_a_copy_can_keep_its_hidden_cards() -> void:
	var engine: MmEngine = _engine_in_main_phase()

	var copy: MmGameState = engine.simulation_copy(engine.villain().id, MmRng.new(1), true).game_state()

	assert_eq(_card_ids(copy.player(0).hand), _card_ids(engine.game_state().player(0).hand))


func test_triggers_that_look_back_work_on_a_copy() -> void:
	# The copy starts with an empty event log, so trigger detection must never read further
	# back than the current batch (ADR 0017, ADR 0020).
	var watcher: MmCardDefinition = Scenario.artifact("Watcher", [Scenario.triggered(
		Scenario.dies(Scenario.of_type(CardType.CREATURE)), [Scenario.gain_life(1, Scenario.you())])])
	var goblin: MmCardDefinition = Scenario.creature("Goblin", 1, 1)
	var shock: MmCardDefinition = Scenario.free_shock("Shock", 3)
	var no_extras: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup([watcher], [goblin], [shock]),
		[watcher], [goblin], [shock], no_extras, 3, Step.PRECOMBAT_MAIN)
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)
	var target: int = Scenario.permanent_named(copy, copy.villain().id, "Goblin")

	assert_eq(Scenario.cast_and_resolve(copy, "Shock", [MmReference.to_object(target)]), "")
	assert_eq(Scenario.resolve_stack(copy), "")

	assert_eq(copy.hero().life, 21)
	assert_eq(engine.hero().life, 20)


func test_a_cast_begun_on_a_copy_can_still_be_canceled() -> void:
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(
		Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20),
		Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 3, 1, "Bolt"))
	assert_not_null(engine)
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)
	var before: String = copy.fingerprint()

	assert_eq(copy.submit(Scenario.cast_index(copy.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(copy, copy.hero(), "Bolt"))), "")
	assert_true(copy.is_casting())

	assert_eq(copy.cancel_cast(), "")
	assert_eq(copy.fingerprint(), before)


func test_a_cast_begun_before_the_copy_cannot_be_canceled_on_it() -> void:
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(
		Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20),
		Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 3, 1, "Bolt"))
	assert_not_null(engine)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(engine, engine.hero(), "Bolt")))
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)
	var before: String = copy.fingerprint()

	assert_eq(copy.cancel_cast(), "This cast began before this Simulation Copy was made.")
	assert_eq(copy.fingerprint(), before)
	assert_eq(engine.cancel_cast(), "", "The real engine still can.")


func _engine_in_main_phase() -> MmEngine:
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.deck_of(Scenario.basic_land("Forest"), 20, Scenario.vanilla("Bear"), 20),
		Scenario.deck_of(Scenario.basic_land("Forest"), 20, Scenario.vanilla("Bear"), 20), Scenario.Rule.HERO_STARTS, 11))
	assert_eq(Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN, true), "")
	return engine


func _card_ids(zone: MmZone) -> Array[int]:
	return Scenario.card_ids(zone)


func _sorted(ids: Array) -> Array:
	var copy: Array = ids.duplicate()
	copy.sort()
	return copy
