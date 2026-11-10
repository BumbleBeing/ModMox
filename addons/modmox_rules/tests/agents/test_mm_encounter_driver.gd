extends GutTest
## The Encounter Driver runs an encounter by asking each player's Agent, and stops for a
## player with no Agent: a human.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const IllegalAnswerAgent := preload("res://addons/modmox_rules/tests/support/illegal_answer_agent.gd")
const Status := MmEncounterDriver.Status


func test_two_agents_play_an_encounter_to_its_end() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.RANDOM_CHOOSER, 3, 20, 20))
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, _agents(DefaultAnswerAgent.new(), DefaultAnswerAgent.new()))

	assert_eq(driver.run(), Status.OVER)

	assert_true(engine.is_over())
	var replayed: MmEngine = MmEngine.replay(Scenario.setup(Scenario.Rule.RANDOM_CHOOSER, 3, 20, 20), engine.decision_log())
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_the_driver_stops_for_a_human_and_carries_on_after_their_answer() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.VILLAIN_CHOOSES, 3))
	var villain_agent: MmAgent = DefaultAnswerAgent.new()
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, _agents(null, villain_agent))

	assert_eq(driver.run(), Status.WAITING_FOR_HUMAN)
	assert_eq(engine.pending_decision().player_id, engine.hero().id)
	assert_gt(villain_agent.answers_given, 0, "The Villain chose to play or draw.")

	assert_eq(engine.submit(KeepOrMulliganDecision.Choice.KEEP), "")
	assert_eq(driver.run(), Status.WAITING_FOR_HUMAN)
	assert_eq(engine.pending_decision().player_id, engine.hero().id)


func test_the_decision_cap_stops_a_long_run() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 3))
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, _agents(DefaultAnswerAgent.new(), DefaultAnswerAgent.new()))
	driver.decision_cap = 10

	assert_eq(driver.run(), Status.CAPPED)

	assert_eq(engine.decision_count(), 10)


func test_a_stop_condition_is_checked_before_each_answer() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 3))
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, _agents(DefaultAnswerAgent.new(), DefaultAnswerAgent.new()))

	var status: Status = driver.run_until(func(running: MmEngine) -> bool: return running.game_state().game_turn == 2)

	assert_eq(status, Status.STOPPED)
	assert_eq(engine.game_state().game_turn, 2)


func test_an_illegal_answer_from_an_agent_stops_the_driver() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 3))
	var before: String = engine.fingerprint()
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, _agents(IllegalAnswerAgent.new(), null))

	assert_eq(driver.run(), Status.REJECTED)

	assert_push_error("not an answer")
	assert_string_contains(driver.rejection, "illegal_answer_agent.gd")
	assert_eq(engine.fingerprint(), before)


func test_each_decision_gets_a_source_for_the_deciding_player() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 3))

	var source: MmSimulationSource = engine.simulation_source_for(engine.villain().id)

	assert_eq(source.player_id, engine.villain().id)
	assert_eq(source.ai_rng().next_int(1000000), source.ai_rng().next_int(1000000), "One stream per decision.")
	var hero_source: MmSimulationSource = engine.simulation_source_for(engine.hero().id)
	assert_ne(hero_source.ai_rng().next_int(1000000), source.ai_rng().next_int(1000000))


func test_a_sources_world_hides_the_other_players_hand() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 3))
	var source: MmSimulationSource = engine.simulation_source_for(engine.villain().id)

	var world: MmGameState = source.world(MmRng.new(4))

	assert_ne(world, engine.game_state())
	assert_eq(source.world(MmRng.new(5)), world, "Made once per decision.")
	assert_ne(Scenario.card_ids(world.player(0).hand), Scenario.card_ids(engine.hero().hand))
	assert_eq(Scenario.card_ids(world.player(1).hand), Scenario.card_ids(engine.villain().hand))


func test_inside_a_copy_the_world_is_the_copy_itself() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 3))
	var copy: MmEngine = engine.simulation_copy(engine.villain().id, MmRng.new(1))

	var source: MmSimulationSource = copy.simulation_source_for(engine.villain().id)

	assert_eq(source.world(MmRng.new(4)), copy.game_state())


func _agents(hero_agent: MmAgent, villain_agent: MmAgent) -> Dictionary[int, MmAgent]:
	var agents: Dictionary[int, MmAgent] = {}
	if hero_agent != null:
		agents[MmEncounterSetup.HERO_PLAYER_ID] = hero_agent
	if villain_agent != null:
		agents[MmEncounterSetup.VILLAIN_PLAYER_ID] = villain_agent
	return agents
