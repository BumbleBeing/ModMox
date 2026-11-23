extends GutTest
## X chosen as a spell is cast (engine ADR 0076): both Agents choose the most X they could
## pay. And "you may remove a +1/+1 counter from this creature. If you do, ..." is a "you
## may" like any other: a FULL Agent simulates yes and no. Neither knows any card's name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const PLUS: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_it_casts_x_spells_with_the_most_x_it_could_pay() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())]:
		var engine: MmEngine = _x_asked()
		var asked: ChooseXDecision = engine.pending_decision() as ChooseXDecision
		assert_eq(asked.most, 6, "Two Mana Birds make six.")

		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(answer, 6)
		assert_eq(engine.submit(answer), "")
		assert_true(engine.pending_decision() is PayManaDecision, "X is then paid.")


func test_it_removes_a_counter_to_spread_it_only_when_it_has_other_creatures() -> void:
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	var with_friends: MmEngine = _guide_asks([Scenario.creature("Bear", 2, 2), Scenario.creature("Wolf", 2, 2)])
	var alone: MmEngine = _guide_asks([])

	assert_eq(AiScenario.ask(with_friends, agent), ChooseYesOrNoDecision.Choice.YES, "One counter becomes two.")
	assert_eq(AiScenario.ask(alone, agent), ChooseYesOrNoDecision.Choice.NO, "A counter lost for nothing.")


## The Hero, with two Mana Birds ("{T}: Add {W}{W}{W}") on the battlefield, begins casting
## Bounty, a sorcery costing {X}: "You gain X life." X is asked.
func _x_asked() -> MmEngine:
	var birds: Array[MmCardDefinition] = [Scenario.mana_bird(), Scenario.mana_bird()]
	var bounty: Array[MmCardDefinition] = [Scenario.x_gain()]
	var ogre: Array[MmCardDefinition] = [Scenario.creature("Ogre", 3, 3)]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(birds, ogre, bounty), birds, ogre, bounty,
		no_cards, 3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	var cast: int = Scenario.cast_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(engine, engine.hero(), "Bounty"))
	assert_eq(engine.submit(cast), "")
	return engine


## The Hero controls a Guide (a 0/1 with two +1/+1 counters and Guiding Hydra's second
## ability) and [param others]; its trigger asks at the beginning of combat on Game Turn 3.
func _guide_asks(others: Array[MmCardDefinition]) -> MmEngine:
	var yours: ControlledByFilter = ControlledByFilter.new()
	var each_other: MmSelection = Scenario.each_creature(Scenario.all_of([yours, Scenario.is_not(IsSourceFilter.new())]))
	var spreading: TriggeredAbility = Scenario.triggered(Scenario.at_step(MmTurn.Step.BEGINNING_OF_COMBAT, MmTrigger.Whose.YOU),
		[Scenario.may_pay(Scenario.remove_counters(), Scenario.put_counters(PLUS, 1, each_other))])
	var guide: MmCardDefinition = Scenario.creature("Guide", 0, 1, [Scenario.enters_with_counters(Scenario.constant(2)), spreading])
	var hero: Array[MmCardDefinition] = [guide]
	hero.append_array(others)
	var ogre: Array[MmCardDefinition] = [Scenario.creature("Ogre", 3, 3)]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(hero, ogre), hero, ogre, no_cards, no_cards, 3,
		MmTurn.Step.BEGINNING_OF_COMBAT)
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseYesOrNoDecision), "")
	return engine
