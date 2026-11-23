extends GutTest
## "You may [cost]. If you do, [effect]." (CR 603.5, 608.2d, ADR 0076): as the effect begins
## its controller is asked yes or no, only if they could pay the cost now. Yes pays it at
## once and then [effect] happens; no does nothing. "Remove a +1/+1 counter from this
## creature" is such a cost (RemoveCountersCost, CR 118.3), as on Guiding Hydra.

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


# --- Helpers ---------------------------------------------------------------------------


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
