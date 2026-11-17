extends GutTest
## A choice made as a spell or ability resolves, "return a creature you control to its
## owner's hand" (CR 608.2d). A FULL Agent simulates each candidate, as it does a target; a
## CHEAP Agent takes its own least valuable permanent. Neither knows any card's name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_full_agent_returns_the_lion_rather_than_its_angel() -> void:
	var engine: MmEngine = _choosing_with([AiScenario.free_alpha("serra_angel")])
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_eq(_chosen_name(engine, answer), "Lion", "A 2/2 back in hand costs less than a 4/4 flier.")
	assert_eq(easy.explain(), AiAgent.Reason.BEST_SCORE)


func test_a_cheap_agent_returns_its_least_valuable_creature() -> void:
	var engine: MmEngine = _choosing_with([AiScenario.free_alpha("serra_angel"), AiScenario.free_alpha("hill_giant")])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(_chosen_name(engine, answer), "Lion")
	assert_eq(engine.submit(answer), "")


func test_with_one_candidate_it_answers_at_once() -> void:
	var engine: MmEngine = _choosing_with([])
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	assert_eq(answer, 0)
	assert_eq(agent.explain(), AiAgent.Reason.ONLY_CHOICE)
	assert_eq(agent.rollout_count(), 0, "Nothing to compare, so nothing is simulated.")


## The Hero with [param creatures] on the battlefield has cast the Lion, and is choosing
## which creature its ability returns.
func _choosing_with(creatures: Array[MmCardDefinition]) -> MmEngine:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	var lion: MmCardDefinition = Scenario.creature("Lion", 2, 2, [Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.return_to_hand(Scenario.chosen(Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), yours])))])])
	var engine: MmEngine = AiScenario.ready_with(creatures, [], [lion])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.cast_and_resolve(engine, "Lion")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseObjectDecision), "")
	return engine


func _chosen_name(engine: MmEngine, answer: int) -> String:
	var chosen: MmReference = (engine.pending_decision() as ChooseObjectDecision).candidates[answer]
	return engine.game_state().characteristics_of(engine.game_state().object(chosen.id)).name
