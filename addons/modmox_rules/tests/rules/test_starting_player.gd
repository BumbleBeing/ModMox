extends GutTest
## CR 103.1: who plays first. The setup either forces the starting player or names who
## chooses play or draw, with a coin flip (Game RNG) deciding the chooser when random.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_hero_starts_when_forced_without_any_choice() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS))

	assert_eq(engine.game_state().starting_player_id, engine.hero().id)
	var decision: MmPendingDecision = engine.pending_decision()
	assert_true(decision is KeepOrMulliganDecision, "No play/draw choice when the start is forced.")
	assert_eq(decision.player_id, engine.hero().id)


func test_villain_starts_when_forced_without_any_choice() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.VILLAIN_STARTS))

	assert_eq(engine.game_state().starting_player_id, engine.villain().id)
	assert_eq(engine.pending_decision().player_id, engine.villain().id)


func test_hero_choosing_to_play_starts() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES))
	assert_true(engine.pending_decision() is ChoosePlayOrDrawDecision)
	assert_eq(engine.pending_decision().player_id, engine.hero().id)

	var error: String = engine.submit(ChoosePlayOrDrawDecision.Choice.PLAY)

	assert_eq(error, "")
	assert_eq(engine.game_state().starting_player_id, engine.hero().id)


func test_hero_choosing_to_draw_lets_the_villain_start() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES))

	engine.submit(ChoosePlayOrDrawDecision.Choice.DRAW)

	assert_eq(engine.game_state().starting_player_id, engine.villain().id)
	assert_eq(engine.pending_decision().player_id, engine.villain().id, "The starting player decides first.")


func test_villain_chooses_when_the_setup_says_so() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.VILLAIN_CHOOSES))

	assert_true(engine.pending_decision() is ChoosePlayOrDrawDecision)
	assert_eq(engine.pending_decision().player_id, engine.villain().id)


func test_random_chooser_is_the_same_for_the_same_seed() -> void:
	var first: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.RANDOM_CHOOSER, 9))
	var second: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.RANDOM_CHOOSER, 9))

	assert_eq(first.pending_decision().player_id, second.pending_decision().player_id)


func test_random_chooser_can_be_either_player() -> void:
	var choosers: Dictionary[int, bool] = {}
	for encounter_seed: int in range(1, 21):
		var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.RANDOM_CHOOSER, encounter_seed))
		choosers[engine.pending_decision().player_id] = true

	assert_eq(choosers.size(), 2, "Twenty seeds should give each player the choice at least once.")


func test_an_invalid_play_or_draw_answer_is_rejected_and_changes_nothing() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES))
	var before: String = engine.fingerprint()

	for bad_answer: Variant in [5, "play", null, [0]]:
		assert_ne(engine.submit(bad_answer), "", "Answer %s should be rejected." % [bad_answer])

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is ChoosePlayOrDrawDecision)
	assert_eq(engine.decision_log().size(), 0, "Rejected answers are not logged.")


func test_the_decision_says_whether_the_chooser_was_picked_at_random() -> void:
	var flipped: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.RANDOM_CHOOSER))
	var named: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES))

	assert_true((flipped.pending_decision() as ChoosePlayOrDrawDecision).is_chooser_random)
	assert_false((named.pending_decision() as ChoosePlayOrDrawDecision).is_chooser_random)
