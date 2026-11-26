extends GutTest
## The Agent and Kishla Trawlers's "you may exile a creature card from your graveyard. When
## you do, return target instant or sorcery card from your graveyard to your hand." (engine
## ADR 0088): it says yes, exiles the creature card worth least, and returns the spell worth
## most. A Bird that taps for {W}{W}{W} pays for a Big Husk (a 0/0 costing {2}) and a Big
## Gift (an instant costing {1}), which end in the graveyard beside a free Husk and Gift.
## And Selfcraft Mechan's "you may sacrifice an artifact. When you do, put a +1/+1 counter on
## target creature and draw a card.": with a Treasure out it says yes, sacrifices the
## Treasure, not the Mechan itself, and puts the counter on a creature of its own.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_it_says_yes_exiles_the_cheapest_creature_card_and_returns_the_dearest_spell() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()),
			AiAgent.new()]:
		var engine: MmEngine = _trawler_question_asked()

		assert_eq(AiScenario.ask(engine, agent), ChooseYesOrNoDecision.Choice.YES)
		assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
		var exiled: MmReference = (engine.pending_decision() as ChooseObjectDecision).candidates[AiScenario.ask(engine, agent)]
		assert_eq(_name_of(engine, exiled), "Husk", "No simulation sees a graveyard: the card worth least goes.")
		assert_eq(engine.submit(0), "")
		assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseTargetDecision), "")

		assert_eq(_name_of(engine, AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))), "Big Gift")


func test_it_sacrifices_a_treasure_for_a_counter_on_its_own_creature_and_a_card() -> void:
	var hoarder: MmCardDefinition = Scenario.creature("Bear", 2, 2,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.create_tokens(load("res://content/tokens/treasure.tres"))])])
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()),
			AiAgent.new()]:
		var engine: MmEngine = AiScenario.ready_with([hoarder], [Scenario.creature("Ogre", 3, 3)], [Scenario.mechan()])
		assert_not_null(engine)
		var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
		assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Mechan")), "")
		assert_eq(Scenario.pass_to_yes_or_no(engine), "")

		assert_eq(AiScenario.ask(engine, agent), ChooseYesOrNoDecision.Choice.YES,
			"A Treasure is worth less than a +1/+1 counter and a card.")
		assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
		assert_true(engine.pending_decision() is ChoosePermanentsDecision)
		assert_eq(AiScenario.ask(engine, agent), [treasure], "The Treasure is worth less than the Mechan.")
		assert_eq(engine.submit([treasure]), "")
		assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseTargetDecision), "")

		var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))
		assert_eq(engine.game_state().object(target.id).controller_id, engine.hero().id, "Its own creature grows.")


## The Hero, with a Bird, having put a Big Husk, a Husk, a Big Gift and a Gift into their
## graveyard and cast a Trawler, asked its "you may".
func _trawler_question_asked() -> MmEngine:
	var hand: Array[MmCardDefinition] = [Scenario.trawler(), Scenario.creature("Big Husk", 0, 0, [], Scenario.mana_cost(2)),
		Scenario.creature("Husk", 0, 0), _gift("Big Gift", 1), _gift("Gift", 0)]
	var engine: MmEngine = AiScenario.ready_with([Scenario.mana_bird()], [], hand)
	assert_not_null(engine)
	for card_name: String in ["Big Husk", "Husk", "Big Gift", "Gift"]:
		assert_eq(Scenario.cast_and_resolve(engine, card_name), "")
		assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), card_name), -1)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Trawler")), "")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")
	return engine


## An instant costing {[param cost]}: "You gain 1 life."
func _gift(card_name: String, cost: int) -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(cost), [], [Scenario.gain_life(1, Scenario.you())])


func _name_of(engine: MmEngine, reference: MmReference) -> String:
	return engine.game_state().characteristics_of(engine.game_state().object(reference.id)).name
