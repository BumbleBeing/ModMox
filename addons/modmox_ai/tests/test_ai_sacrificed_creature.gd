extends GutTest
## An ability that reads "the sacrificed creature" (engine ADR 0098) is played by what its
## simulation shows: Disciple is a 2/1 costing {0} with Disciple of Bolas's ability, "When
## this creature enters, sacrifice another creature. You gain X life and draw X cards, where
## X is that creature's power."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_it_casts_the_disciple_to_trade_a_creature_for_cards() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Brute", 3, 1)], [], [Scenario.disciple()])
	assert_not_null(engine)
	var life: int = engine.hero().life
	var agent: AiAgent = AiAgent.new()

	for _answer: int in 16:
		var decision: MmPendingDecision = engine.pending_decision()
		if engine.game_state().step != MmTurn.Step.PRECOMBAT_MAIN or decision == null:
			break
		assert_eq(AiScenario.let_answer(engine, agent) if decision.player_id == engine.hero().id
			else engine.submit(Scenario.default_answer(decision)), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Disciple"), -1, "Its main phase cast it.")
	assert_eq(engine.hero().life, life + 3, "Its ability sacrificed a 3/1 and gained its power in life.")
