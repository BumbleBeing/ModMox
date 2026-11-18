extends GutTest
## The legend rule's choice (CR 704.5j): a FULL Agent simulates keeping each legend, a CHEAP
## one keeps the most valuable. Neither knows any card's name, and neither is told to avoid
## a second copy of a legend: simulation sees the copy that is lost.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_full_agent_keeps_the_legend_that_can_attack() -> void:
	var engine: MmEngine = _choosing_a_legend()
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Legend")
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_eq(_kept(engine, answer), first, "The new copy has summoning sickness.")
	assert_eq(easy.explain(), AiAgent.Reason.BEST_SCORE)


func test_a_cheap_agent_keeps_its_most_valuable_legend() -> void:
	var engine: MmEngine = _choosing_a_legend()
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Legend")
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(_kept(engine, answer), first)
	assert_eq(engine.submit(answer), "")


func test_a_full_agent_casts_another_creature_rather_than_a_second_copy_of_its_legend() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var engine: MmEngine = AiScenario.ready_with([Scenario.legend()], [], [Scenario.legend(), bear])
	assert_not_null(engine, "No seed gave the needed hand.")
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_eq(AiScenario.cast_name(engine, answer), "Bear")


## The Hero has had a Legend since Game Turn 1, and has just cast a second.
func _choosing_a_legend() -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with([Scenario.legend()], [], [Scenario.legend()])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.cast_and_resolve(engine, "Legend")
	assert_true(engine.pending_decision() is ChooseLegendToKeepDecision)
	return engine


func _kept(engine: MmEngine, answer: int) -> int:
	return (engine.pending_decision() as ChooseLegendToKeepDecision).candidate_ids[answer]
