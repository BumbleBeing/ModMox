extends GutTest
## CR 117: priority. The active player receives priority in each step except untap and
## cleanup; the step ends when both players pass in succession with an empty stack.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_non_active_player_gets_priority_after_the_active_player_passes() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	Scenario.keep_all(engine)

	_pass_priority(engine)

	assert_eq(engine.pending_decision().player_id, engine.villain().id)
	assert_eq(engine.game_state().step, Step.UPKEEP, "One pass does not end the step.")


func test_the_step_ends_when_both_players_pass_in_succession() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	Scenario.keep_all(engine)

	_pass_priority(engine)
	_pass_priority(engine)

	assert_eq(engine.game_state().step, Step.PRECOMBAT_MAIN, "Turn 1 has no draw step (CR 103.8a).")
	assert_eq(engine.pending_decision().player_id, engine.hero().id, "The active player receives priority first.")


func test_untap_and_cleanup_never_grant_priority() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	Scenario.keep_all(engine)
	var steps_with_priority: Dictionary[int, bool] = {}

	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		if running.pending_decision() is PriorityDecision:
			steps_with_priority[running.game_state().step] = true
		return running.game_state().game_turn > 4)

	assert_false(steps_with_priority.has(Step.UNTAP))
	assert_false(steps_with_priority.has(Step.CLEANUP))
	for step: Step in [Step.UPKEEP, Step.DRAW, Step.PRECOMBAT_MAIN, Step.BEGINNING_OF_COMBAT,
			Step.DECLARE_ATTACKERS, Step.END_OF_COMBAT, Step.POSTCOMBAT_MAIN, Step.END]:
		assert_true(steps_with_priority.has(step), "%s should grant priority." % Step.find_key(step))


func test_passing_is_the_only_action_for_now() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	Scenario.keep_all(engine)

	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	assert_eq(decision.actions.size(), 1)
	assert_true(decision.actions[0] is PassAction)


func test_invalid_priority_answers_are_rejected_and_change_nothing() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	Scenario.keep_all(engine)
	var before: String = engine.fingerprint()
	var logged: int = engine.decision_log().size()

	for bad_answer: Variant in [1, -1, "pass", null, [0], 0.0]:
		assert_ne(engine.submit(bad_answer), "", "Answer %s should be rejected." % [bad_answer])

	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.decision_log().size(), logged)


func _pass_priority(engine: MmEngine) -> void:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_not_null(decision, "Expected a priority decision.")
	assert_eq(engine.submit(Scenario.pass_index(decision)), "")
