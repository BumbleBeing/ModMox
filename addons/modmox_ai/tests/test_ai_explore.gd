extends GutTest
## The Agent and explore (engine ADR 0090): the choice is a SurveilDecision of the one
## nonland card revealed, so the Agent answers it by its surveil rule, keeping a spell it
## could cast soon on top and putting one it couldn't into its graveyard. Explorers are 1/1s
## costing {0}, "When this creature enters, it explores."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_it_keeps_a_cheap_spell_on_top_and_graveyards_a_costly_one_at_every_level() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()),
			AiAgent.new()]:
		for revealed: String in ["Gift", "Dragon"]:
			var engine: MmEngine = _explore_asked(revealed)
			var card: int = (engine.pending_decision() as ExploreDecision).card_ids[0]

			var answer: Array = AiScenario.ask(engine, agent) as Array

			if revealed == "Gift":
				assert_eq(answer, [[], [card]], "A spell costing {0} is worth drawing.")
			else:
				assert_eq(answer, [[card], []], "A spell costing {6} is far out of reach.")


## The Hero in their first main phase of Game Turn 3 with a Bear, having cast an Explorer
## whose explore reveals [param revealed] and asks what to do with it.
func _explore_asked(revealed: String) -> MmEngine:
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var dragon: MmCardDefinition = Scenario.creature("Dragon", 6, 6, [], Scenario.mana_cost(6))
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var deck: Array[MmCardDefinition] = [bear, Scenario.explorer(), gift, dragon]
	var hand: Array[MmCardDefinition] = [Scenario.explorer()]
	var permanents: Array[MmCardDefinition] = [bear]
	var engine: MmEngine = Scenario.top_ready(Scenario.setup_with(Scenario.cycled(deck), Scenario.cycled([])), permanents,
		hand, [revealed])
	assert_not_null(engine, "No seed gave the needed hand and library.")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Explorer")), "")
	assert_eq(Scenario.pass_to_explore(engine), "")
	return engine
