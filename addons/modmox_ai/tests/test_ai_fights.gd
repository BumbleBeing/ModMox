extends GutTest
## A fight (CR 701.14) is removal that the Agent's own creature deals: a CHEAP Agent sends in
## its most powerful creature and aims at what that creature would kill; a FULL Agent
## simulates, and chooses a modal spell's fight when it wins the fight.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_fight_is_removal() -> void:
	var spell: SpellAbility = Scenario.free_fight().abilities[0] as SpellAbility

	assert_eq(AiTiming.tag_of_spell(spell), AiTiming.Tag.REMOVAL)


func test_a_cheap_agent_sends_its_most_powerful_creature_into_the_fight() -> void:
	var engine: MmEngine = _casting_fight([Scenario.creature("Bear", 2, 2), Scenario.creature("Brute", 4, 4)],
		[Scenario.creature("Ogre", 3, 3)])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(AiScenario.chosen_target(engine, answer).id, Scenario.permanent_named(engine, engine.hero().id, "Brute"))


func test_a_cheap_agent_fights_what_its_creature_can_kill() -> void:
	var engine: MmEngine = _casting_fight([Scenario.creature("Brute", 4, 4)],
		[Scenario.creature("Giant", 6, 6), Scenario.creature("Ogre", 3, 3)])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)
	assert_eq(engine.submit(AiScenario.ask(engine, cheap)), "", "The Brute, the only one.")

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(AiScenario.chosen_target(engine, answer).id, Scenario.permanent_named(engine, engine.villain().id, "Ogre"),
		"The Giant is worth more, but the Brute's 4 can't kill it.")


func test_a_full_agent_chooses_to_fight_when_its_creature_wins() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Brute", 4, 4)], [Scenario.creature("Bear", 2, 2)],
		[_bushwhack()])
	assert_not_null(engine, "No seed gave the needed hand.")
	var bushwhack: int = Scenario.card_in_hand(engine, engine.hero(), "Bushwhack")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, bushwhack)), "")
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_eq((engine.pending_decision() as ChooseModeDecision).modes[answer], 1, "The fight kills the Bear for nothing.")


## Bushwhack as a sorcery costing {0}: "Choose one — • Search your library for a basic land
## card, reveal it, put it into your hand, then shuffle. • Target creature you control
## fights target creature you don't control."
func _bushwhack() -> MmCardDefinition:
	return Scenario.free_modal("Bushwhack", [
		Scenario.ability_mode([], [Scenario.search(Scenario.basic_land_card())]),
		Scenario.ability_mode([Scenario.target(Scenario.creature_you_control()), Scenario.target(Scenario.creature_you_dont_control())],
			[Scenario.fight(Scenario.targeted(0), Scenario.targeted(1))]),
	])


## The Hero, with [param hero_creatures], has begun casting a free fight against the
## Villain's [param villain_creatures], and is choosing its first target.
func _casting_fight(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with(hero_creatures, villain_creatures, [Scenario.free_fight()])
	assert_not_null(engine, "No seed gave the needed hand.")
	var fight: int = Scenario.card_in_hand(engine, engine.hero(), "Fight")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, fight)), "")
	assert_true(engine.pending_decision() is ChooseTargetDecision)
	return engine
