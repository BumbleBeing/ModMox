extends GutTest
## ADR 0006 / ADR 0010: an encounter is exactly reproducible from its setup and decisions.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_replaying_the_decision_log_reproduces_the_state_exactly() -> void:
	var setup: MmEncounterSetup = Scenario.setup(Scenario.Rule.RANDOM_CHOOSER, 1234)
	var original: MmEngine = MmEngine.start(setup)
	var keep_or_mulligan: Array = [
		KeepOrMulliganDecision.Choice.MULLIGAN,
		KeepOrMulliganDecision.Choice.KEEP,
		KeepOrMulliganDecision.Choice.KEEP,
	]
	assert_eq(original.submit(ChoosePlayOrDrawDecision.Choice.DRAW), "")
	for answer: Variant in keep_or_mulligan:
		assert_eq(original.submit(answer), "")
	var bottom: ChooseCardsToBottomDecision = original.pending_decision() as ChooseCardsToBottomDecision
	assert_eq(original.submit(bottom.candidate_ids.slice(2, 3)), "")

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())
	assert_eq(replayed.decision_log(), original.decision_log())


func test_replaying_several_turns_reproduces_the_state_exactly() -> void:
	var setup: MmEncounterSetup = Scenario.setup(Scenario.Rule.RANDOM_CHOOSER, 77)
	var original: MmEngine = MmEngine.start(setup)
	assert_eq(Scenario.play_until_game_turn(original, 6), "")

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())
	assert_eq(replayed.game_state().game_turn, 6)


func test_replaying_turns_with_land_plays_reproduces_the_state_exactly() -> void:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var setup: MmEncounterSetup = Scenario.setup_with(forests, forests.duplicate(), Scenario.Rule.RANDOM_CHOOSER, 5)
	var original: MmEngine = MmEngine.start(setup)
	assert_eq(Scenario.play_until_game_turn(original, 6, true), "")
	assert_eq(original.game_state().battlefield.size(), 5, "Five turns, one land each.")

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())


func test_the_fingerprint_changes_when_the_state_changes() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	var before: String = engine.fingerprint()

	engine.submit(KeepOrMulliganDecision.Choice.MULLIGAN)

	assert_ne(engine.fingerprint(), before)


func test_the_decision_log_holds_plain_data_answers() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES))

	engine.submit(ChoosePlayOrDrawDecision.Choice.PLAY)
	engine.submit(KeepOrMulliganDecision.Choice.KEEP)

	assert_eq(engine.decision_log(), [ChoosePlayOrDrawDecision.Choice.PLAY, KeepOrMulliganDecision.Choice.KEEP])
