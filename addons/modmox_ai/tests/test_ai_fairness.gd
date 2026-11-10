extends GutTest
## The AI never cheats (A155, ADR 0020): it answers the same whatever the cards it cannot
## see are, and the same after a save and reload (A158).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const DECISIONS_CHECKED: int = 25


func test_answers_do_not_depend_on_the_heros_hidden_cards() -> void:
	var engine: MmEngine = MmEngine.start(_setup())
	var villain: int = engine.villain().id
	var agent: AiAgent = AiAgent.new()
	var checked: int = 0
	while checked < DECISIONS_CHECKED and not engine.is_over():
		var decision: MmPendingDecision = engine.pending_decision()
		if decision.player_id != villain:
			engine.submit(Scenario.default_answer(decision, true))
			continue
		# The same game with the Hero's hand and library dealt differently.
		var rearranged: MmEngine = engine.simulation_copy(villain, MmRng.new(checked + 100))
		var seed: int = engine.decision_count()

		var real_answer: Variant = agent.answer(decision, null, MmSimulationSource.new(engine, villain, seed, true))
		var other_answer: Variant = agent.answer(rearranged.pending_decision(), null, MmSimulationSource.new(rearranged, villain, seed, true))

		assert_eq(other_answer, real_answer, "Decision %d: %s" % [engine.decision_count(), decision.describe()])
		engine.submit(real_answer)
		checked += 1


func test_the_same_decision_gets_the_same_answer_after_a_reload() -> void:
	var setup: MmEncounterSetup = _setup()
	var engine: MmEngine = MmEngine.start(setup)
	var agents: Dictionary[int, MmAgent] = {}
	agents[MmEncounterSetup.HERO_PLAYER_ID] = DefaultAnswerAgent.new()
	agents[MmEncounterSetup.VILLAIN_PLAYER_ID] = AiAgent.new()
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, agents)
	driver.run_until(func(running: MmEngine) -> bool:
		return running.game_state().game_turn >= 4 and running.pending_decision().player_id == running.villain().id \
			and running.pending_decision() is PriorityDecision and (running.pending_decision() as PriorityDecision).actions.size() > 1)

	var reloaded: MmEngine = MmEngine.replay(setup, engine.decision_log())

	var agent: AiAgent = AiAgent.new()
	assert_eq(AiScenario.ask(reloaded, agent), AiScenario.ask(engine, agent))
	assert_eq(reloaded.fingerprint(), engine.fingerprint())


func test_thinking_never_changes_the_real_game() -> void:
	var engine: MmEngine = MmEngine.start(_setup())
	Scenario.play_until_step(engine, 3, MmTurn.Step.PRECOMBAT_MAIN, true)
	var before: String = engine.fingerprint()

	AiScenario.ask(engine, AiAgent.new())

	assert_eq(engine.fingerprint(), before)


func _setup() -> MmEncounterSetup:
	var setup: MmEncounterSetup = MmEncounterSetup.new()
	setup.hero = load("res://content/decks/red_green.tres") as MmPlayerSetup
	setup.villain = load("res://content/decks/white_black.tres") as MmPlayerSetup
	setup.encounter_seed = 5
	setup.starting_player_rule = MmEncounterSetup.StartingPlayerRule.HERO_STARTS
	return setup
