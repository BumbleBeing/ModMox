extends GutTest
## Flat Monte Carlo (milestone 12, A188–A193, A202): a FULL Agent's priority decisions
## compare a few candidate plays by rolling each out on the same re-dealt worlds, keeping
## the one-step pick unless another beats it by the switch margin.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


# --- Where it is used (A188) -------------------------------------------------------

func test_no_rollouts_when_only_passing_is_possible() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PassAction)

	assert_eq(agent.rollout_count(), 0)


func test_no_rollouts_for_a_land_play() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures,
		[AiScenario.alpha("mountain"), AiScenario.free_alpha("hill_giant")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PlayLandAction)

	assert_eq(agent.explain(), AiAgent.Reason.PLAY_LAND)
	assert_eq(agent.rollout_count(), 0)


func test_targets_still_use_one_step_simulation() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("lightning_bolt")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()
	engine.submit(AiScenario.ask(engine, agent))

	AiScenario.ask(engine, agent)

	assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)
	assert_eq(agent.rollout_count(), 0)


func test_a_priority_choice_is_rolled_out_on_every_sample() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("lightning_bolt")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Lightning Bolt")
	assert_eq(agent.explain(), AiAgent.Reason.ROLLOUT_SCORE)
	# Each candidate (passing and the Bolts in hand) on each of Normal's samples.
	var candidates: int = agent.explain_detail().split(", ").size()
	assert_between(candidates, 2, AiDifficulty.normal().rollout_candidates)
	assert_eq(agent.rollout_count(), candidates * AiDifficulty.normal().rollout_samples)
	assert_string_contains(agent.explain_detail(), "W")


# --- Candidates (A189) -------------------------------------------------------------

func test_candidates_always_include_the_one_step_pick_and_passing() -> void:
	var options: Array[int] = [0, 1, 2, 3, 4, 5]
	var scores: Array[int] = [-10, 50, 40, 30, 20, -5]

	var candidates: Array[int] = AiMonteCarlo.candidates(options, scores, 5, 0, 4)

	assert_eq(candidates, [5, 0, 1, 2] as Array[int], "The pick first, then passing, then the best of the rest.")


func test_candidates_with_equal_scores_go_in_action_order() -> void:
	var options: Array[int] = [0, 3, 1, 2]
	var scores: Array[int] = [0, 20, 20, 20]

	var candidates: Array[int] = AiMonteCarlo.candidates(options, scores, 3, 0, 3)

	assert_eq(candidates, [3, 0, 1] as Array[int])


func test_every_option_is_a_candidate_when_they_all_fit() -> void:
	var options: Array[int] = [0, 1, 2]
	var scores: Array[int] = [0, 5, 9]

	var candidates: Array[int] = AiMonteCarlo.candidates(options, scores, 2, 0, 4)

	assert_eq(candidates, [2, 0, 1] as Array[int])


func test_a_pick_that_is_passing_appears_once() -> void:
	var options: Array[int] = [0, 1, 2]
	var scores: Array[int] = [9, 5, 0]

	var candidates: Array[int] = AiMonteCarlo.candidates(options, scores, 0, 0, 2)

	assert_eq(candidates, [0, 1] as Array[int])


# --- The horizon (A190) ------------------------------------------------------------

func test_a_rollout_from_its_own_main_phase_plays_through_the_next_game_turn() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures)
	assert_not_null(engine)
	assert_eq(engine.game_state().game_turn, 3)
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	AiSimulation.roll_out(copy, engine.hero().id, AiProfile.new())

	assert_eq(copy.game_state().game_turn, 5, "The rest of Game Turn 3, all of Game Turn 4, and no further.")


func test_a_rollout_from_the_other_players_end_step_plays_through_its_own_next_turn() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures)
	assert_not_null(engine)
	Scenario.play_until_step(engine, 4, Step.END)
	assert_eq(engine.game_state().step, Step.END)
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	AiSimulation.roll_out(copy, engine.hero().id, AiProfile.new())

	assert_eq(copy.game_state().game_turn, 6, "The Hero's whole Game Turn 5 is played.")


func test_a_pass_that_ends_the_game_turn_is_rolled_out_no_further_than_any_other_answer() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures)
	assert_not_null(engine)
	Scenario.play_until_step(engine, 3, Step.END)
	Scenario.pass_priority(engine)
	var villain_id: int = engine.villain().id
	assert_eq(engine.game_state().game_turn, 3)
	assert_eq(engine.pending_decision().player_id, villain_id, "The Villain's pass ends Game Turn 3.")
	var passing: int = Scenario.pass_index(engine.pending_decision() as PriorityDecision)
	var copy: MmEngine = engine.simulation_copy(villain_id, MmRng.new(1))

	AiSimulation.score_rollout(copy, passing, villain_id, AiProfile.new())

	assert_eq(copy.game_state().game_turn, 5, "A190: the horizon is counted from the decision, not from after the answer.")


func test_a_rollout_stops_when_the_game_ends() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("craw_wurm")], no_creatures, [], [],
		Step.PRECOMBAT_MAIN, 3)
	assert_not_null(engine)
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	AiSimulation.roll_out(copy, engine.hero().id, AiProfile.new())

	assert_true(copy.is_over())
	assert_eq(copy.game_state().game_turn, 3)
	assert_eq(AiBoardEvaluator.score(copy.game_state(), engine.hero().id, AiProfile.new()), AiBoardEvaluator.WIN)


# --- Scoring and choosing (A191, A192) ---------------------------------------------

func test_one_win_outranks_better_boards() -> void:
	var sample_scores: Array = [
		[500, AiBoardEvaluator.WIN],
		[500, -300],
		[500, -300],
		[500, -300],
	]
	var totals: Array[int] = AiMonteCarlo.totals(sample_scores, 2)

	assert_eq(AiMonteCarlo.choose([7, 4] as Array[int], totals, 40, MmRng.new(1)), 4)


func test_with_wins_and_losses_even_the_better_boards_win() -> void:
	var sample_scores: Array = [
		[AiBoardEvaluator.WIN, AiBoardEvaluator.WIN],
		[-AiBoardEvaluator.WIN, -AiBoardEvaluator.WIN],
		[500, -300],
	]
	var totals: Array[int] = AiMonteCarlo.totals(sample_scores, 2)

	assert_eq(AiMonteCarlo.choose([7, 4] as Array[int], totals, 40, MmRng.new(1)), 7)


func test_a_candidate_short_of_the_margin_does_not_replace_the_pick() -> void:
	var totals: Array[int] = [100, 139]

	assert_eq(AiMonteCarlo.choose([7, 4] as Array[int], totals, 40, MmRng.new(1)), 7)


func test_a_candidate_exactly_at_the_margin_replaces_the_pick() -> void:
	var totals: Array[int] = [100, 140]

	assert_eq(AiMonteCarlo.choose([7, 4] as Array[int], totals, 40, MmRng.new(1)), 4)


func test_a_tie_keeps_the_pick_even_with_no_margin() -> void:
	var totals: Array[int] = [100, 100, 99]

	assert_eq(AiMonteCarlo.choose([7, 4, 2] as Array[int], totals, 0, MmRng.new(1)), 7)


func test_the_best_challenger_wins() -> void:
	var totals: Array[int] = [100, 150, 190]

	assert_eq(AiMonteCarlo.choose([7, 4, 2] as Array[int], totals, 40, MmRng.new(1)), 2)


func test_the_margin_counts_once_per_sample() -> void:
	var profile: AiProfile = AiProfile.new()
	profile.rollout_switch_margin = 10

	assert_eq(AiMonteCarlo.margin(profile, 4), 40)


# --- The same seeds for every candidate (A193) -------------------------------------

func test_identical_candidates_score_the_same_in_every_sample() -> void:
	var engine: MmEngine = MmEngine.start(_soak_setup())
	Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN, true)
	assert_true(engine.pending_decision() is PriorityDecision)
	var me: int = engine.pending_decision().player_id
	var passing: int = Scenario.pass_index(engine.pending_decision() as PriorityDecision)
	var source: MmSimulationSource = engine.simulation_source_for(me)
	var answers: Array[int] = [passing, passing]

	var sample_scores: Array = AiMonteCarlo.sample_scores(source, source.ai_rng(), answers, 3, me, AiProfile.new())

	assert_eq(sample_scores.size(), 3)
	for row: Variant in sample_scores:
		assert_eq((row as Array)[0], (row as Array)[1])


func test_the_same_decision_gets_the_same_answer_twice() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("lightning_bolt")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var first: int = AiScenario.ask(engine, agent)
	var first_detail: String = agent.explain_detail()
	var second: int = AiScenario.ask(engine, agent)

	assert_eq(second, first)
	assert_eq(agent.explain_detail(), first_detail)


func test_a_monte_carlo_decision_never_changes_the_real_game() -> void:
	var engine: MmEngine = MmEngine.start(_soak_setup())
	Scenario.play_until_step(engine, 5, Step.PRECOMBAT_MAIN, true)
	var before: String = engine.fingerprint()

	AiScenario.ask(engine, AiAgent.new())

	assert_eq(engine.fingerprint(), before)


func _soak_setup() -> MmEncounterSetup:
	var setup: MmEncounterSetup = MmEncounterSetup.new()
	setup.hero = load("res://content/decks/red_green.tres") as MmPlayerSetup
	setup.villain = load("res://content/decks/white_black.tres") as MmPlayerSetup
	setup.encounter_seed = 5
	setup.starting_player_rule = MmEncounterSetup.StartingPlayerRule.HERO_STARTS
	return setup


func test_the_detail_counts_wins_and_losses() -> void:
	var rows: Array = [
		[AiBoardEvaluator.WIN, -AiBoardEvaluator.WIN],
		[20, -AiBoardEvaluator.WIN],
	]

	assert_eq(AiMonteCarlo.describe([7, 4] as Array[int], rows), "7: %d (1W 0L), 4: %d (0W 2L)" % [
		AiBoardEvaluator.WIN + 20, -2 * AiBoardEvaluator.WIN])


func test_a_rollout_whose_answer_is_rejected_scores_below_any_outcome() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures)
	assert_not_null(engine)
	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))

	assert_eq(AiSimulation.score_rollout(copy, 999, engine.hero().id, AiProfile.new()), AiSimulation.FAILED)
	assert_true(AiSimulation.FAILED < -AiBoardEvaluator.WIN)


func test_room_for_one_candidate_means_no_rollouts() -> void:
	var difficulty: AiDifficulty = AiDifficulty.new()
	difficulty.rollout_candidates = 1
	var engine: MmEngine = AiScenario.ready_with([], [AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("lightning_bolt")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

	assert_eq(AiScenario.cast_name(engine, AiScenario.ask(engine, agent)), "Lightning Bolt")

	assert_eq(agent.rollout_count(), 0)
	assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)
