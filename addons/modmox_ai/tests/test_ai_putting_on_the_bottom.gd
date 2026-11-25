extends GutTest
## A card put on the bottom of its owner's library from a graveyard, as Landscaper Colos's
## "enters" trigger puts one from an opponent's: no simulation sees a graveyard, so FULL
## and CHEAP Agents alike take the card the other player could most use, one with flashback
## first, then the creature card that costs the most, then the card that costs the most.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_card_the_other_player_could_cast_again_with_flashback_is_taken_first() -> void:
	var echo: MmCardDefinition = Scenario.flashback_sorcery("Echo", [], [], Scenario.flashback(Scenario.mana_cost(1)))
	var engine: MmEngine = _colos_aiming_at([echo, _bear(), _bolt(), Scenario.basic_land("Mountain")])

	for agent: AiAgent in [AiAgent.new(), AiAgent.new(null, AiAgent.Mode.CHEAP)]:
		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(_name_of(engine, AiScenario.chosen_target(engine, answer)), "Echo", "Though it costs the least.")
		assert_eq(agent.explain(), AiAgent.Reason.MOST_USEFUL_TO_THEM)


func test_without_flashback_the_creature_card_that_costs_the_most_is_taken() -> void:
	var runt: MmCardDefinition = Scenario.creature("Runt", 1, 1, [], Scenario.mana_cost(1))
	var engine: MmEngine = _colos_aiming_at([runt, _bear(), _bolt(), Scenario.basic_land("Mountain")])

	for agent: AiAgent in [AiAgent.new(), AiAgent.new(null, AiAgent.Mode.CHEAP)]:
		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(_name_of(engine, AiScenario.chosen_target(engine, answer)), "Bear", "Not the Runt, nor the Bolt that costs more.")


## The Hero's Colos entering on Game Turn 3, its trigger's target being chosen, after a Mill
## has put [param villain_cards] (a deck cycling through them) into the Villain's graveyard.
func _colos_aiming_at(villain_cards: Array[MmCardDefinition]) -> MmEngine:
	var mill: MmCardDefinition = Scenario.free_mill("Mill", 20, true)
	var engine: MmEngine = AiScenario.ready_with([], [], [Scenario.colos(), mill], villain_cards)
	assert_eq(Scenario.cast_and_resolve(engine, "Mill"), "")
	var dead: Array[String] = Scenario.names(engine, engine.villain().graveyard)
	for card: MmCardDefinition in villain_cards:
		assert_true(dead.has(card.name), "The Mill put a %s into the Villain's graveyard." % card.name)
	assert_eq(Scenario.cast_and_resolve(engine, "Colos"), "")
	assert_true(engine.pending_decision() is ChooseTargetDecision, "The trigger's target is asked.")
	return engine


func _name_of(engine: MmEngine, chosen: MmReference) -> String:
	return engine.game_state().characteristics_of(engine.game_state().object(chosen.id)).name


## A 2/2 creature card with mana value 2.
func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(2))


## An instant with mana value 3 that does nothing.
func _bolt() -> MmCardDefinition:
	return Scenario.instant("Bolt", Scenario.mana_cost(3), [], [])
