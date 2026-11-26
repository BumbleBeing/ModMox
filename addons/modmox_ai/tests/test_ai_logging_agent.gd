extends GutTest
## The AI Log (AiLoggingAgent): the Villain's Agent wrapped so that every answer it gives is
## written down with why, so a bad play in a playtest can be read back afterwards. It never
## changes an answer.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const FOLDER: String = "user://test_ai_logging_agent/"
const WRITTEN_AT: String = "2026-11-25T16:50:00"


func after_each() -> void:
	if DirAccess.dir_exists_absolute(FOLDER):
		for file: String in DirAccess.get_files_at(FOLDER):
			DirAccess.remove_absolute(FOLDER + file)
		DirAccess.remove_absolute(FOLDER)


func test_it_answers_exactly_as_the_agent_it_wraps() -> void:
	var engine: MmEngine = _bolt_and_bears()
	var plain: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	var logged: AiLoggingAgent = AiLoggingAgent.new(AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))

	var expected: Variant = AiScenario.ask(engine, plain)

	assert_eq(_ask(engine, logged), expected)


func test_a_priority_answer_is_written_with_the_card_its_reason_and_its_options() -> void:
	var engine: MmEngine = _bolt_and_bears()
	var logged: AiLoggingAgent = AiLoggingAgent.new(AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))

	var play: int = _ask(engine, logged)

	assert_eq(AiScenario.cast_name(engine, play), "Lightning Bolt")
	var entry: String = "\n".join(logged.lines)
	assert_string_contains(entry, "Game Turn 3")
	assert_string_contains(entry, "precombat main")
	assert_string_contains(entry, "chose: %s (Lightning Bolt)" % AiScenario.action_at(engine, play).describe())
	assert_string_contains(entry, "BEST_SCORE")
	assert_string_contains(entry, "options:")
	assert_string_contains(entry, "%d: pass" % _pass_index(engine), "Each option is numbered as the scores are.")
	assert_string_contains(entry, "detail:")


func test_how_long_an_answer_took_is_read_from_the_clock_it_was_given() -> void:
	# A159: the AI never reads the clock itself, so the log is handed one.
	var engine: MmEngine = _bolt_and_bears()
	var ticks: Array[int] = [100, 112]
	var clock: Callable = func() -> int: return ticks.pop_front()
	var timed: AiLoggingAgent = AiLoggingAgent.new(AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()), "", clock)
	var untimed: AiLoggingAgent = AiLoggingAgent.new(AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))

	_ask(engine, timed)
	_ask(engine, untimed)

	assert_string_contains("\n".join(timed.lines), "[BEST_SCORE, 12 ms]")
	assert_string_contains("\n".join(untimed.lines), "[BEST_SCORE]")
	assert_false("\n".join(untimed.lines).contains(" ms"), "No clock, no time.")


func test_a_target_is_written_by_name() -> void:
	var engine: MmEngine = _bolt_and_bears()
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	engine.submit(AiScenario.ask(engine, agent))
	var logged: AiLoggingAgent = AiLoggingAgent.new(agent)

	_ask(engine, logged)

	assert_string_contains("\n".join(logged.lines), "chose: Grizzly Bears")


func test_a_priority_decision_with_nothing_but_pass_is_not_written() -> void:
	var logged: AiLoggingAgent = AiLoggingAgent.new(AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))
	var decision: PriorityDecision = PriorityDecision.new(0, [PassAction.new()] as Array[MmAction])

	assert_eq(logged.answer(decision, null, null), 0)
	assert_eq(logged.lines, PackedStringArray())


func test_a_priority_decision_offering_only_mana_abilities_besides_pass_is_not_written() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures, [AiScenario.alpha("mountain")])
	assert_not_null(engine)
	Scenario.play_first_land(engine)
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_true(decision.actions.size() > 1 and decision.actions.any(func(action: MmAction) -> bool: return action is ActivateAbilityAction),
		"The Mountain's mana ability is offered beside Pass.")
	var logged: AiLoggingAgent = AiLoggingAgent.new(AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))

	_ask(engine, logged)

	assert_eq(logged.lines, PackedStringArray())


func test_a_log_begun_in_a_folder_is_a_file_named_for_its_seed_that_starts_with_the_difficulty() -> void:
	var engine: MmEngine = _bolt_and_bears()
	var logged: AiLoggingAgent = AiLoggingAgent.begin(FOLDER, 77, AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()),
		WRITTEN_AT)

	_ask(engine, logged)

	assert_eq(logged.path, FOLDER + "2026-11-25T16-50-00-77.log", "Named for when it was begun and the seed.")
	var written: String = FileAccess.get_file_as_string(logged.path)
	assert_string_contains(written.get_slice("\n", 0), "Encounter Seed 77")
	assert_string_contains(written.get_slice("\n", 0), "written " + WRITTEN_AT)
	assert_string_contains(written.get_slice("\n", 0), "no Monte Carlo")
	assert_string_contains(written, "(Lightning Bolt)")
	assert_eq(written.strip_edges(), "\n".join(logged.lines).strip_edges(), "The file holds what was written.")


func test_two_logs_begun_at_once_with_one_seed_get_files_of_their_own() -> void:
	var first: AiLoggingAgent = AiLoggingAgent.begin(FOLDER, 5, AiAgent.new(), WRITTEN_AT)
	var second: AiLoggingAgent = AiLoggingAgent.begin(FOLDER, 5, AiAgent.new(), WRITTEN_AT)

	assert_ne(first.path, second.path)
	assert_true(FileAccess.file_exists(first.path))
	assert_true(FileAccess.file_exists(second.path))


## The Hero, in their precombat main phase on Game Turn 3, holding a free Lightning Bolt with
## the Villain's Grizzly Bears on the battlefield.
func _bolt_and_bears() -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with([], [AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("lightning_bolt")])
	assert_not_null(engine)
	return engine


func _ask(engine: MmEngine, agent: AiLoggingAgent) -> Variant:
	var decision: MmPendingDecision = engine.pending_decision()
	return agent.answer(decision, engine.view_for(engine.game_state().player(decision.player_id)),
		engine.simulation_source_for(decision.player_id))


func _pass_index(engine: MmEngine) -> int:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	for index: int in decision.actions.size():
		if decision.actions[index] is PassAction:
			return index
	return -1
