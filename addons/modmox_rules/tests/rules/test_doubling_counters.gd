extends GutTest
## CR 701.10e: to double the number of a kind of counters on a permanent is to put on it as
## many more of that kind as it already has. They are put on, as any counters are (CR 122.6).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const MINUS := MmCounter.Kind.MINUS_ONE_MINUS_ONE


func test_two_counters_doubled_are_four_put_on_as_two_more() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.free_counters("Grow", PLUS, 2), _doubler()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(bear)])

	assert_eq(Scenario.cast_and_resolve(engine, "Doubler", [MmReference.to_object(bear)]), "")

	assert_eq(Scenario.counters_on(engine, bear, PLUS), 4)
	assert_eq(Scenario.pt(engine, bear), [6, 6])
	var put: Array[MmEvent] = Scenario.events_of(engine, CountersPutEvent)
	assert_eq(put.size(), 2, "Grow's, then the Doubler's.")
	assert_eq([(put[1] as CountersPutEvent).object_id, (put[1] as CountersPutEvent).kind, (put[1] as CountersPutEvent).amount],
		[bear, PLUS, 2], "CR 701.10e: as many more as it had.")


func test_a_creature_with_no_counters_gets_none() -> void:
	var engine: MmEngine = _hero_main([_bear()], [_doubler()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Doubler", [MmReference.to_object(bear)]), "")

	assert_eq(Scenario.counters_on(engine, bear, PLUS), 0)
	assert_eq(Scenario.events_of(engine, CountersPutEvent).size(), 0, "Nothing was put on.")


func test_only_the_kind_it_names_is_doubled() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.free_counters("Grow", PLUS, 1), _doubler(MINUS)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(bear)])

	Scenario.cast_and_resolve(engine, "Doubler", [MmReference.to_object(bear)])

	assert_eq(Scenario.counters_on(engine, bear, PLUS), 1)
	assert_eq(Scenario.counters_on(engine, bear, MINUS), 0)


## An instant costing {0}: "Double the number of [kind] counters on target creature."
func _doubler(kind: MmCounter.Kind = PLUS) -> MmCardDefinition:
	return Scenario.instant("Doubler", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(CardType.CREATURE))],
		[Scenario.double_counters(kind, Scenario.targeted(0))])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
