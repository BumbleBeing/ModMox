extends GutTest
## "You may [cost]. If you do, [effect]." (CR 603.5, 608.2d, ADR 0076): as the effect begins
## its controller is asked yes or no, only if they could pay the cost now. Yes pays it at
## once and then [effect] happens; no does nothing. "Remove a +1/+1 counter from this
## creature" is such a cost (RemoveCountersCost, CR 118.3), as on Guiding Hydra. So is mana,
## as Myrsmith's "you may pay {1}": yes is paid one PayManaDecision at a time, as ward's cost
## is (ADR 0062), and then [effect] happens.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_yes_removes_a_counter_and_puts_one_on_each_other_creature_you_control() -> void:
	var engine: MmEngine = _combat_begins([_guide(2), _bear()])
	var guide: int = Scenario.permanent_named(engine, engine.hero().id, "Guide")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")
	var asked: ChooseYesOrNoDecision = engine.pending_decision() as ChooseYesOrNoDecision
	assert_true(asked.resolution_cost is RemoveCountersCost, "What yes pays.")

	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.counters_on(engine, guide, PLUS), 1)
	assert_eq(Scenario.counters_on(engine, bear, PLUS), 1)
	assert_eq(Scenario.counters_on(engine, ogre, PLUS), 0, "Only creatures you control.")
	assert_eq(Scenario.events_of(engine, CountersRemovedEvent).size(), 1)


func test_no_does_nothing() -> void:
	var engine: MmEngine = _combat_begins([_guide(2), _bear()])
	var guide: int = Scenario.permanent_named(engine, engine.hero().id, "Guide")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")

	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.NO), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.counters_on(engine, guide, PLUS), 2)
	assert_eq(Scenario.counters_on(engine, bear, PLUS), 0)


func test_with_no_counter_to_remove_nothing_is_asked_and_nothing_happens() -> void:
	var engine: MmEngine = _combat_begins([_guide(0), _bear()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(engine.game_state().stack.size(), 1, "The trigger, waiting.")

	while not engine.game_state().stack.is_empty():
		assert_false(engine.pending_decision() is ChooseYesOrNoDecision, "Nothing to pay, so nothing asked.")
		assert_eq(Scenario.pass_priority(engine), "")

	assert_false(engine.pending_decision() is ChooseYesOrNoDecision)
	assert_eq(Scenario.counters_on(engine, bear, PLUS), 0)


func test_a_zero_toughness_creature_removing_its_last_counter_dies_and_the_rest_still_happens() -> void:
	var engine: MmEngine = _combat_begins([_guide(1, 0), _bear()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.pass_to_yes_or_no(engine), "")

	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Guide"), -1, "CR 704.5f, once it has resolved.")
	assert_eq(Scenario.counters_on(engine, bear, PLUS), 1)


func test_a_cost_to_remove_counters_can_be_paid_only_with_enough_of_them() -> void:
	var engine: MmEngine = _combat_begins([_guide(2), _bear()])
	var guide: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Guide"))
	var bear: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Bear"))

	assert_true(Scenario.remove_counters(2).can_pay(engine.game_state(), guide, engine.hero().id))
	assert_false(Scenario.remove_counters(3).can_pay(engine.game_state(), guide, engine.hero().id))
	assert_false(Scenario.remove_counters(1).can_pay(engine.game_state(), bear, engine.hero().id))
	assert_false(Scenario.remove_counters(1, MmCounter.Kind.MINUS_ONE_MINUS_ONE).can_pay(engine.game_state(), guide, engine.hero().id))


func test_an_activated_ability_can_cost_a_counter() -> void:
	# "Remove a +1/+1 counter from this creature: You gain 2 life."
	var gain: ActivatedAbility = Scenario.activated(null, [Scenario.remove_counters()], [Scenario.gain_life(2, Scenario.you())])
	var pouch: MmCardDefinition = Scenario.creature("Pouch", 1, 1, [Scenario.enters_with_counters(Scenario.constant(1)), gain])
	var no_cards: Array[MmCardDefinition] = []
	var hero: Array[MmCardDefinition] = [pouch]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(hero, no_cards), hero, no_cards, no_cards,
		no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine)
	var id: int = Scenario.permanent_named(engine, engine.hero().id, "Pouch")
	var life: int = engine.hero().life

	assert_eq(Scenario.activate(engine, id), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 2)
	assert_eq(Scenario.counters_on(engine, id, PLUS), 0)
	assert_eq(Scenario.activate(engine, id), "Object %d has no ability to activate." % id, "No counter left to remove.")


func test_may_pay_is_saved_with_its_card() -> void:
	var path: String = "user://test_may_pay.tres"
	assert_eq(ResourceSaver.save(_guide(1), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var paying: MayPayEffect = (loaded.abilities[1] as TriggeredAbility).effects[0] as MayPayEffect
	assert_not_null(paying)
	assert_eq((paying.cost as RemoveCountersCost).amount, 1)
	assert_true(paying.effect is PutCountersEffect)
	DirAccess.remove_absolute(path)


func test_it_reaches_what_it_affects_through_the_effect_it_wraps() -> void:
	var tap: TapEffect = Scenario.tap(Scenario.targeted(0))
	var paying: MayPayEffect = Scenario.may_pay(Scenario.remove_counters(), tap)

	assert_eq(paying.selections(), tap.selections())
	assert_true(paying.has_targets())
	assert_false(paying.adds_mana())


func test_yes_to_a_mana_cost_pays_it_and_then_the_effect_happens() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird("Mana Bird", 1)], [_smith()])
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")
	var life: int = engine.hero().life
	assert_eq(Scenario.cast_and_resolve(engine, "Smith"), "")
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	var asked: ChooseYesOrNoDecision = engine.pending_decision() as ChooseYesOrNoDecision
	assert_eq(asked.player_id, engine.hero().id, "Its controller is asked.")
	assert_eq(asked.cost.generic, 1, "What yes pays.")
	assert_true(asked.effect is GainLifeEffect, "What yes offers.")

	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
	assert_true(engine.pending_decision() is PayManaDecision, "Paid as a cast's mana is.")
	assert_eq(Scenario.auto_pay(engine), "")
	Scenario.resolve_stack(engine)

	assert_true(engine.game_state().object(bird).is_tapped)
	assert_eq(engine.hero().life, life + 3)


func test_no_to_a_mana_cost_pays_nothing_and_nothing_happens() -> void:
	var engine: MmEngine = _hero_main([Scenario.mana_bird("Mana Bird", 1)], [_smith()])
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Mana Bird")
	var life: int = engine.hero().life
	assert_eq(Scenario.cast_and_resolve(engine, "Smith"), "")
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")

	assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.NO), "")
	Scenario.resolve_stack(engine)

	assert_false(engine.game_state().object(bird).is_tapped)
	assert_eq(engine.hero().life, life)


func test_a_mana_cost_that_cannot_be_paid_is_not_asked() -> void:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main(no_cards, [_smith()])
	var life: int = engine.hero().life
	assert_eq(Scenario.cast_and_resolve(engine, "Smith"), "")

	while not engine.game_state().stack.is_empty():
		assert_false(engine.pending_decision() is ChooseYesOrNoDecision, "CR 118.3: nothing to pay with, so nothing asked.")
		assert_eq(Scenario.pass_priority(engine), "")

	assert_eq(engine.hero().life, life)


func test_a_mana_cost_is_saved_with_its_card() -> void:
	var path: String = "user://test_may_pay_mana.tres"
	assert_eq(ResourceSaver.save(_smith(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var paying: MayPayEffect = (loaded.abilities[0] as TriggeredAbility).effects[0] as MayPayEffect
	assert_null(paying.cost)
	assert_eq(paying.mana_cost.generic, 1)
	assert_true(paying.effect is GainLifeEffect)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## A 2/1 creature costing {0}: "When this creature enters, you may pay {1}. If you do, you
## gain 3 life."
func _smith() -> MmCardDefinition:
	var paying: MayPayEffect = Scenario.may_pay_mana(Scenario.mana_cost(1), Scenario.gain_life(3, Scenario.you()))
	return Scenario.creature("Smith", 2, 1, [Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [paying])])


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand].
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(hero_permanents, no_cards, hand), hero_permanents,
		no_cards, hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## A [param toughness]-toughness creature costing {0} that enters with [param counters]
## +1/+1 counters, with Guiding Hydra's second ability.
func _guide(counters: int, toughness: int = 1) -> MmCardDefinition:
	var yours: ControlledByFilter = ControlledByFilter.new()
	var others: MmSelection = Scenario.each_creature(Scenario.all_of([yours, Scenario.is_not(IsSourceFilter.new())]))
	var each_other: PutCountersEffect = Scenario.put_counters(PLUS, 1, others)
	var guide: TriggeredAbility = Scenario.triggered(Scenario.at_step(Step.BEGINNING_OF_COMBAT, MmTrigger.Whose.YOU),
		[Scenario.may_pay(Scenario.remove_counters(), each_other)])
	return Scenario.creature("Guide", 0, toughness, [Scenario.enters_with_counters(Scenario.constant(counters)), guide])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


## [param hero_permanents] for the Hero and an Ogre for the Villain, stopped at the first
## decision of the Hero's beginning of combat step on Game Turn 3.
func _combat_begins(hero_permanents: Array[MmCardDefinition]) -> MmEngine:
	var villain: Array[MmCardDefinition] = [Scenario.creature("Ogre", 3, 3)]
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(hero_permanents, villain), hero_permanents,
		villain, no_cards, no_cards, 3, Step.BEGINNING_OF_COMBAT)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
