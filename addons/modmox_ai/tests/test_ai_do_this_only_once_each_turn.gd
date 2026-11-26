extends GutTest
## The Agent and Irreverent Gremlin's "Whenever another creature you control with power 2 or
## less enters, you may discard a card. If you do, draw a card. Do this only once each turn."
## (engine ADR 0054's second addendum): a discard said yes to is a cost, which a FULL Agent
## weighs by simulation, and the card discarded is chosen as cleanup's discard is, the spell
## it is furthest from casting first while it is short of lands. Rock is an instant costing
## {7}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_cheap_agent_loots_away_the_spell_it_is_furthest_from_casting() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.gremlin()], [], [Scenario.creature("Bear", 2, 2), _rock()])
	assert_not_null(engine, "No seed gave the needed hand.")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")

	var answer: int = AiScenario.ask(engine, agent)

	assert_eq(answer, ChooseYesOrNoDecision.Choice.YES)
	assert_eq(engine.submit(answer), "")
	assert_true(engine.pending_decision() is ChooseCardsToDiscardDecision, "Which card is asked once yes is said.")
	var discarded: Array = AiScenario.ask(engine, agent) as Array
	assert_eq(engine.game_state().characteristics_of(engine.game_state().object(discarded[0] as int)).name, "Rock")
	assert_eq(engine.submit(discarded), "")


func test_a_full_agent_answers_the_discard_by_simulation() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.gremlin()], [], [Scenario.creature("Bear", 2, 2), _rock()])
	assert_not_null(engine, "No seed gave the needed hand.")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bear")), "")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")

	AiScenario.ask(engine, agent)

	assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)
	assert_true(agent.explain_detail().contains(":"), "Both answers were simulated: %s" % agent.explain_detail())


## An instant costing {7}: "You gain 1 life."
func _rock() -> MmCardDefinition:
	return Scenario.instant("Rock", Scenario.mana_cost(7), [], [Scenario.gain_life(1, Scenario.you())])
