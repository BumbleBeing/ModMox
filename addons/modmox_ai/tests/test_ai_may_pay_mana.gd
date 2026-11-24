extends GutTest
## "You may pay {1}. If you do, [effect]." (ADR 0076's addendum), as Myrsmith's: an Agent
## pays the mana for what it offers when the mana is spare. A CHEAP Agent says yes to any
## mana it is asked to pay; a FULL one simulates both answers, the payment included. Neither
## knows any card's name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_an_agent_pays_spare_mana_for_a_token() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())]:
		var engine: MmEngine = AiScenario.ready_with([Scenario.mana_bird("Mana Bird", 1), _smith()], [], [Scenario.artifact("Trinket", [])])
		assert_not_null(engine, "No seed gave the needed hand.")
		assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Trinket")), "")
		assert_eq(Scenario.pass_to_pay_or_not(engine), "")

		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(answer, ChooseYesOrNoDecision.Choice.YES, "{1} with nothing else to spend it on buys a 1/1.")
		assert_eq(engine.submit(answer), "")
		assert_true(engine.pending_decision() is PayManaDecision)


## A 2/1 creature costing {0} with Myrsmith's ability: "Whenever you cast an artifact spell,
## you may pay {1}. If you do, create a 1/1 colorless Myr creature token."
func _smith() -> MmCardDefinition:
	var myr: MmCardDefinition = Scenario.token(1, 1, [], ["Myr"])
	var paying: MayPayEffect = Scenario.may_pay_mana(Scenario.mana_cost(1), Scenario.create_tokens(myr))
	var trigger: SpellCastTrigger = Scenario.casts(Scenario.of_type(MmCardTypes.CardType.ARTIFACT), MmTrigger.Whose.YOU)
	return Scenario.creature("Smith", 2, 1, [Scenario.triggered(trigger, [paying])])
