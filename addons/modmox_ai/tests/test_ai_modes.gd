extends GutTest
## A modal spell (CR 700.2): when it is worth considering, and which mode the Agent
## chooses. A FULL Agent simulates each mode, as it does a target; a CHEAP Agent takes the
## first mode that reaches something of the other player's. Neither knows any card's name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_full_agent_kills_the_other_players_creature_rather_than_destroy_a_blank_enchantment() -> void:
	var engine: MmEngine = _choosing_mode([Scenario.creature("Ogre", 2, 2), Scenario.enchantment("Glory", [])], [])
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_eq((engine.pending_decision() as ChooseModeDecision).modes[answer], 1, "The damage mode kills the Ogre.")
	assert_eq(easy.explain(), AiAgent.Reason.BEST_SCORE)


func test_a_cheap_agent_takes_the_first_mode_that_reaches_the_other_players_things() -> void:
	var engine: MmEngine = _choosing_mode([Scenario.creature("Ogre", 2, 2)], [Scenario.enchantment("Own Glory", [])])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq((engine.pending_decision() as ChooseModeDecision).modes[answer], 1,
		"The first mode could only destroy its own enchantment.")
	assert_eq(engine.submit(answer), "")


func test_a_modal_spell_whose_modes_are_all_removal_is_removal() -> void:
	var spell: SpellAbility = _charm().abilities[0] as SpellAbility

	assert_eq(AiTiming.tag_of_spell(spell), AiTiming.Tag.REMOVAL)


func test_a_modal_spell_whose_modes_differ_is_considered_whenever_it_may_be_cast() -> void:
	var spell: SpellAbility = Scenario.free_modal("Mixed", [
		Scenario.spell_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT))], [Scenario.destroy(Scenario.targeted(0))]),
		Scenario.spell_mode([], [Scenario.draw_cards(1, YouSelection.new())]),
	]).abilities[0] as SpellAbility

	assert_eq(AiTiming.tag_of_spell(spell), AiTiming.Tag.NONE)


## "Choose one — • Destroy target enchantment. • 2 damage to target creature."
func _charm() -> MmCardDefinition:
	return Scenario.free_modal("Charm", [
		Scenario.spell_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT))], [Scenario.destroy(Scenario.targeted(0))]),
		Scenario.spell_mode([Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [Scenario.deal_damage(2, Scenario.targeted(0))]),
	])


## The Hero, with [param hero_permanents], has begun casting the Charm against the
## Villain's [param villain_permanents], and is choosing its mode.
func _choosing_mode(villain_permanents: Array[MmCardDefinition], hero_permanents: Array[MmCardDefinition]) -> MmEngine:
	var hero: Array[MmCardDefinition] = [Scenario.creature("Bears", 2, 2)]
	hero.append_array(hero_permanents)
	var engine: MmEngine = AiScenario.ready_with(hero, villain_permanents, [_charm()])
	assert_not_null(engine, "No seed gave the needed hand.")
	var charm: int = Scenario.card_in_hand(engine, engine.hero(), "Charm")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, charm)), "")
	assert_true(engine.pending_decision() is ChooseModeDecision)
	return engine
