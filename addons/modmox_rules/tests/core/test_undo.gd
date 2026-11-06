extends GutTest
## ADR 0015: recent decisions can be undone back to the last undo barrier: hidden
## information revealed, randomness used, the other player deciding, or the stack resolving.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_undoing_a_mana_ability_untaps_the_land_and_empties_the_mana() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	var mountain: int = Scenario.first_permanent_of(engine, engine.hero().id)
	var before: String = engine.fingerprint()
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, mountain))

	assert_eq(engine.undo(), "")

	assert_eq(engine.fingerprint(), before)
	assert_false(engine.game_state().object(mountain).is_tapped)
	assert_eq(engine.hero().mana_pool().size(), 0)


func test_undoing_a_land_play_returns_the_land_to_hand() -> void:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var before: String = engine.fingerprint()
	Scenario.play_first_land(engine)

	assert_eq(engine.undo(), "")

	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.game_state().battlefield.size(), 0)
	assert_eq(engine.hero().hand.size(), 7)


func test_several_undos_in_a_row_step_back_one_decision_each() -> void:
	var engine: MmEngine = _hero_with_bolt(3, 2)
	var lands: Array[int] = engine.game_state().battlefield.object_ids()
	var start: String = engine.fingerprint()
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, lands[0]))
	var after_one: String = engine.fingerprint()
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, lands[1]))

	assert_eq(engine.undo(), "")
	assert_eq(engine.fingerprint(), after_one)
	assert_eq(engine.undo(), "")
	assert_eq(engine.fingerprint(), start)


func test_nothing_can_be_undone_once_the_other_player_has_priority() -> void:
	var engine: MmEngine = _hero_with_bolt(1)

	Scenario.pass_priority(engine)

	assert_false(engine.can_undo())
	assert_ne(engine.undo(), "")


func test_nothing_can_be_undone_past_a_draw() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	Scenario.play_until_step(engine, 3, Step.DRAW)

	assert_false(engine.can_undo(), "Drawing revealed a card.")


func test_canceling_a_cast_while_choosing_targets_restores_the_game_exactly() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	var bolt: int = Scenario.card_in_hand(engine, engine.hero(), "Bolt")
	var before: String = engine.fingerprint()
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, bolt))
	assert_true(engine.is_casting())

	assert_eq(engine.cancel_cast(), "")

	assert_false(engine.is_casting())
	assert_eq(engine.fingerprint(), before)
	assert_eq(Scenario.card_in_hand(engine, engine.hero(), "Bolt"), bolt, "The same card, with the same ID, is back in hand.")


func test_canceling_a_cast_mid_payment_untaps_the_lands_tapped_for_it() -> void:
	var engine: MmEngine = _hero_with_bolt(3, 2)
	var lands: Array[int] = engine.game_state().battlefield.object_ids()
	var before: String = engine.fingerprint()
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Bolt")))
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))
	assert_true(engine.pending_decision() is PayManaDecision)

	assert_eq(engine.cancel_cast(), "")

	assert_eq(engine.fingerprint(), before)
	for land: int in lands:
		assert_false(engine.game_state().object(land).is_tapped)


func test_undoing_during_a_cast_steps_back_one_choice() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Bolt")))
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))

	assert_eq(engine.undo(), "")

	assert_true(engine.pending_decision() is ChooseTargetDecision, "Back to choosing the target.")
	assert_true(engine.is_casting())


func test_undone_decisions_leave_the_decision_log_and_replay_still_matches() -> void:
	var engine: MmEngine = _hero_with_bolt(1)
	var mountain: int = Scenario.first_permanent_of(engine, engine.hero().id)
	var logged: int = engine.decision_log().size()
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, mountain))
	engine.undo()
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])

	assert_eq(engine.decision_log().size(), logged + 3, "Cast, target and payment; the undone tap is gone.")


func test_a_replay_of_a_game_with_undos_matches_the_original() -> void:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)
	var setup: MmEncounterSetup = Scenario.setup_with(cards, cards.duplicate())
	var original: MmEngine = Scenario.find_engine(setup,
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, "Bolt"))
	var mountain: int = Scenario.first_permanent_of(original, original.hero().id)
	original.submit(Scenario.activate_index(original.pending_decision() as PriorityDecision, mountain))
	original.undo()
	Scenario.cast(original, Scenario.card_in_hand(original, original.hero(), "Bolt"), [MmReference.to_player(original.villain().id)])
	Scenario.pass_priority(original)
	Scenario.pass_priority(original)

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())
	assert_eq(replayed.villain().life, 17)


func _hero_with_bolt(game_turn: int, lands: int = 1) -> MmEngine:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, game_turn, lands, "Bolt"))
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
