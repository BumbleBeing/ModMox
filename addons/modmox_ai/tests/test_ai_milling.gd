extends GutTest
## "Put an instant or sorcery card from among them into your hand" (engine ADR 0080): a
## CHEAP Agent takes the card with the greatest mana value, and a FULL one weighs each.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_cheap_agent_takes_the_milled_card_with_the_greatest_mana_value() -> void:
	var engine: MmEngine = _milled()
	var candidates: Array[MmReference] = _instants_in_graveyard(engine)
	assert_gt(candidates.size(), 1, "The mill put both instants in the graveyard.")
	var decision: ChooseObjectDecision = ChooseObjectDecision.new(engine.hero().id, 0, 0, Scenario.instant_or_sorcery(), candidates)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = agent.answer(decision, engine.view_for(engine.hero()), engine.simulation_source_for(engine.hero().id))

	var chosen: MmGameObject = engine.game_state().object(candidates[answer].id)
	assert_eq(engine.game_state().characteristics_of(chosen).name, "Big Ping")


## The Hero in their main phase on Game Turn 3, having milled twenty cards of a deck that
## cycles through Ping ({0}), Big Ping ({2}{W}) and Plains.
func _milled() -> MmEngine:
	var big: MmCardDefinition = Scenario.instant("Big Ping", Scenario.mana_cost(2, [MmMana.Type.WHITE]), [],
		[Scenario.gain_life(3, Scenario.you())])
	var ping: MmCardDefinition = Scenario.instant("Ping", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var extras: Array[MmCardDefinition] = [Scenario.free_mill("Mill Twenty", 20), ping, big, Scenario.basic_land("Plains")]
	var no_cards: Array[MmCardDefinition] = []
	var held: Array[MmCardDefinition] = [extras[0]]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(no_cards, no_cards, extras), no_cards, no_cards,
		held, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	assert_eq(Scenario.cast_and_resolve(engine, "Mill Twenty"), "")
	return engine


func _instants_in_graveyard(engine: MmEngine) -> Array[MmReference]:
	var found: Array[MmReference] = []
	for card: MmGameObject in engine.hero().graveyard.objects():
		if engine.game_state().characteristics_of(card).has_card_type(MmCardTypes.CardType.INSTANT) \
				and engine.game_state().characteristics_of(card).name != "Mill Twenty":
			found.append(MmReference.to_object(card.id))
	return found
