extends GutTest
## Evolve (CR 702.100a): "Whenever a creature you control enters, if that creature has
## greater power or toughness than this creature, put a +1/+1 counter on this creature."
## Its powers and toughnesses are compared as it triggers and again as it resolves
## (CR 702.100b), and each instance triggers on its own (CR 702.100d).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS_ONE: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_a_creature_with_greater_power_entering_puts_a_counter_on_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.evolver()], [Scenario.creature("Striker", 1, 1)])
	var raptor: int = Scenario.permanent_named(engine, engine.hero().id, "Raptor")

	assert_eq(Scenario.cast_and_resolve(engine, "Striker"), "")

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_true(stacked[0].ability is EvolveAbility)
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.counters_on(engine, raptor, PLUS_ONE), 1)
	assert_eq(Scenario.pt(engine, raptor), [1, 2])


func test_a_creature_with_greater_toughness_alone_entering_puts_a_counter_on_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.evolver()], [Scenario.creature("Wall", 0, 2)])
	var raptor: int = Scenario.permanent_named(engine, engine.hero().id, "Raptor")

	Scenario.cast_and_resolve(engine, "Wall")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.counters_on(engine, raptor, PLUS_ONE), 1, "0 power is not greater, but 2 toughness is.")


func test_a_creature_neither_stronger_nor_tougher_does_not_trigger_it() -> void:
	# CR 603.4: the intervening "if" does not hold, so it does not trigger at all.
	var engine: MmEngine = _hero_main([Scenario.evolver("Raptor", 1, 2)], [Scenario.creature("Moth", 1, 1)])
	var raptor: int = Scenario.permanent_named(engine, engine.hero().id, "Raptor")

	Scenario.cast_and_resolve(engine, "Moth")

	assert_eq(_triggers_of(engine, "Raptor"), 0)
	assert_eq(Scenario.counters_on(engine, raptor, PLUS_ONE), 0)


func test_its_own_entering_does_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.evolver()], [])
	var raptor: int = Scenario.permanent_named(engine, engine.hero().id, "Raptor")

	assert_eq(_triggers_of(engine, "Raptor"), 0, "It is not greater than itself.")
	assert_eq(Scenario.counters_on(engine, raptor, PLUS_ONE), 0)


func test_an_opponents_creature_entering_does_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.evolver()], [], [Scenario.creature("Ogre", 3, 3)])
	var raptor: int = Scenario.permanent_named(engine, engine.hero().id, "Raptor")

	assert_eq(Scenario.permanents_named(engine, engine.villain().id, "Ogre").size(), 1)
	assert_eq(_triggers_of(engine, "Raptor"), 0, "\"A creature you control\".")
	assert_eq(Scenario.counters_on(engine, raptor, PLUS_ONE), 0)


func test_a_noncreature_permanent_entering_does_not_trigger_it() -> void:
	# CR 702.100c: a noncreature permanent has no power or toughness to compare.
	var engine: MmEngine = _hero_main([Scenario.evolver()], [Scenario.artifact("Trinket", [])])

	assert_eq(Scenario.cast_and_resolve(engine, "Trinket"), "")

	assert_eq(_triggers_of(engine, "Raptor"), 0)


func test_it_compares_again_as_it_resolves() -> void:
	# CR 702.100b: two 1/1s entering at once both trigger it, but once the first has made it
	# a 1/2, the second is no longer greater.
	var engine: MmEngine = _hero_main([Scenario.evolver()], [Scenario.free_tokens("Pair", Scenario.cat(), 2)])
	var raptor: int = Scenario.permanent_named(engine, engine.hero().id, "Raptor")

	assert_eq(Scenario.cast_and_resolve(engine, "Pair"), "")
	Scenario.resolve_stack(engine)

	assert_eq(_triggers_of(engine, "Raptor"), 2)
	assert_eq(Scenario.counters_on(engine, raptor, PLUS_ONE), 1)
	assert_eq(Scenario.pt(engine, raptor), [1, 2])


func test_a_creature_that_has_left_is_compared_as_it_last_existed() -> void:
	# CR 702.100b and 608.2h: last-known information.
	var engine: MmEngine = _hero_main([Scenario.evolver()], [Scenario.creature("Bear", 2, 2), Scenario.free_bounce("Bounce")])
	var raptor: int = Scenario.permanent_named(engine, engine.hero().id, "Raptor")
	Scenario.cast_and_resolve(engine, "Bear")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [MmReference.to_object(bear)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear").size(), 0)
	assert_eq(Scenario.counters_on(engine, raptor, PLUS_ONE), 1)


func test_two_instances_each_trigger_and_each_compares_on_its_own() -> void:
	# CR 702.100d: the first makes it a 1/2, and the 2/2 still has greater power.
	var twin: MmCardDefinition = Scenario.evolver("Twin", 0, 1, [EvolveAbility.new()])
	var engine: MmEngine = _hero_main([twin], [Scenario.creature("Bear", 2, 2)])
	var raptor: int = Scenario.permanent_named(engine, engine.hero().id, "Twin")

	Scenario.cast_and_resolve(engine, "Bear")
	Scenario.resolve_stack(engine)

	assert_eq(_triggers_of(engine, "Twin"), 2)
	assert_eq(Scenario.counters_on(engine, raptor, PLUS_ONE), 2)
	assert_eq(Scenario.pt(engine, raptor), [2, 3])


func test_evolve_is_saved_with_its_card() -> void:
	var path: String = "user://test_evolve.tres"
	assert_eq(ResourceSaver.save(Scenario.evolver(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var evolve: EvolveAbility = loaded.abilities[0] as EvolveAbility
	assert_not_null(evolve)
	assert_true(evolve.trigger is ZoneChangeTrigger)
	assert_not_null(evolve.condition)
	assert_eq(evolve.effects.size(), 1)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## Stops at the Hero's precombat main phase on Game Turn 3, with [param hero_permanents] cast
## on Game Turn 1, [param villain_permanents] on Game Turn 2 and [param hero_extras] in hand.
func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras,
		no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## How many times an ability of the permanent named [param source_name] has triggered.
func _triggers_of(engine: MmEngine, source_name: String) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == source_name:
			count += 1
	return count
