extends GutTest
## Difficulty (A194, A195): a global setting that only changes how much the AI searches.
## Easy is the milestone 11 Agent; Normal and Hard add Flat Monte Carlo. A Villain's AI
## Profile can scale the budget for itself.

const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const CUSTOM_PATH: String = "user://test_ai_difficulty_custom.tres"


func test_easy_is_one_step_simulation_without_rollouts() -> void:
	var engine: MmEngine = _bolt_ready()
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Lightning Bolt")
	assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)
	assert_eq(agent.rollout_count(), 0)


func test_the_default_difficulty_is_normal() -> void:
	var difficulty: AiDifficulty = AiAgent.new().difficulty

	assert_true(difficulty.uses_monte_carlo)
	assert_eq(difficulty.rollout_candidates, AiDifficulty.normal().rollout_candidates)
	assert_eq(difficulty.rollout_samples, AiDifficulty.normal().rollout_samples)


func test_normal_rolls_out_each_candidate_once_per_sample() -> void:
	var engine: MmEngine = _bolt_ready()
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal())

	AiScenario.ask(engine, agent)

	assert_eq(agent.rollout_count(), _candidates(agent) * AiDifficulty.normal().rollout_samples)


func test_hard_searches_more_than_normal() -> void:
	assert_true(AiDifficulty.hard().rollout_samples > AiDifficulty.normal().rollout_samples)
	assert_false(AiDifficulty.easy().uses_monte_carlo)


func test_a_custom_difficulty_file_is_used_as_given() -> void:
	var custom: AiDifficulty = AiDifficulty.new()
	custom.rollout_samples = 2
	assert_eq(ResourceSaver.save(custom, CUSTOM_PATH), OK)
	var loaded: AiDifficulty = ResourceLoader.load(CUSTOM_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as AiDifficulty
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CUSTOM_PATH))
	var engine: MmEngine = _bolt_ready()
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, loaded)

	AiScenario.ask(engine, agent)

	assert_eq(agent.rollout_count(), _candidates(agent) * 2)


func test_the_shipped_difficulty_files_match_the_built_in_levels() -> void:
	var levels: Dictionary[String, AiDifficulty] = {
		"easy": AiDifficulty.easy(), "normal": AiDifficulty.normal(), "hard": AiDifficulty.hard()}
	for level: String in levels:
		var shipped: AiDifficulty = load("res://content/ai/difficulty_%s.tres" % level) as AiDifficulty
		var built_in: AiDifficulty = levels[level]
		assert_not_null(shipped, level)
		for setting: String in ["uses_monte_carlo", "one_step_samples", "rollout_candidates", "rollout_samples"]:
			assert_eq(shipped.get(setting), built_in.get(setting), "%s %s" % [level, setting])


func test_a_profile_can_double_the_search() -> void:
	var profile: AiProfile = AiProfile.new()
	profile.search_budget_percent = 200
	var engine: MmEngine = _bolt_ready()
	var agent: AiAgent = AiAgent.new(profile, AiAgent.Mode.FULL, AiDifficulty.normal())

	AiScenario.ask(engine, agent)

	assert_eq(agent.rollout_count(), _candidates(agent) * 2 * AiDifficulty.normal().rollout_samples)


func test_a_small_budget_still_takes_one_sample() -> void:
	var profile: AiProfile = AiProfile.new()
	profile.search_budget_percent = 10
	var engine: MmEngine = _bolt_ready()
	var agent: AiAgent = AiAgent.new(profile, AiAgent.Mode.FULL, AiDifficulty.normal())

	AiScenario.ask(engine, agent)

	assert_eq(agent.rollout_count(), _candidates(agent))
	assert_eq(AiDifficulty.scaled(4, 10), 1)
	assert_eq(AiDifficulty.scaled(4, 200), 8)
	assert_eq(AiDifficulty.scaled(0, 100), 1)


func _bolt_ready() -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with([], [AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("lightning_bolt")])
	assert_not_null(engine)
	return engine


## How many candidates the last Monte Carlo decision rolled out.
func _candidates(agent: AiAgent) -> int:
	assert_eq(agent.explain(), AiAgent.Reason.ROLLOUT_SCORE)
	return agent.explain_detail().split(", ").size()


func test_one_step_samples_come_from_the_difficulty() -> void:
	var one: AiDifficulty = AiDifficulty.easy()
	var three: AiDifficulty = AiDifficulty.easy()
	three.one_step_samples = 3
	var engine: MmEngine = _bolt_ready()
	var single: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, one)
	var triple: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, three)

	AiScenario.ask(engine, single)
	AiScenario.ask(engine, triple)

	assert_ne(triple.explain_detail(), single.explain_detail(), "Three samples' totals: %s" % triple.explain_detail())
