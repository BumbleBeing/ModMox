extends GutTest
## "The number of [kind] counters on [selection]" (CR 122) is a CounterCountValue, as in
## Lion Sash's "Equipped creature gets +1/+1 for each +1/+1 counter on this Equipment".

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const MINUS := MmCounter.Kind.MINUS_ONE_MINUS_ONE


func test_with_no_counters_the_equipped_creature_gets_nothing() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.lion_sash()], [], [])
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Lion Sash")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.equip_and_resolve(engine, sash, bear), "")

	assert_eq(Scenario.attached_to(engine, sash), bear)
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_the_equipped_creature_gets_plus_one_plus_one_for_each_counter_and_follows_new_ones() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.lion_sash()], [],
		[Scenario.free_counters("Grow", PLUS, 2), _artifact_counters("Polish")])
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Lion Sash")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Grow", [_object(sash)])
	assert_eq(Scenario.pt(engine, sash), [3, 3], "Unattached, a 1/1 with two counters.")

	Scenario.equip_and_resolve(engine, sash, bear)

	assert_eq(Scenario.pt(engine, bear), [4, 4])
	Scenario.cast_and_resolve(engine, "Polish", [_object(sash)])
	assert_eq(Scenario.pt(engine, bear), [5, 5], "Worked out again as the counters change.")


func test_only_counters_of_its_kind_on_what_it_selects_are_counted() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.creature("Ogre", 4, 4)], [],
		[Scenario.free_counters("Grow", PLUS, 2), Scenario.free_counters("Wither", MINUS, 1), Scenario.free_counters("Swell", PLUS, 3)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.hero().id, "Ogre")
	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Wither", [_object(ogre)])
	Scenario.cast_and_resolve(engine, "Swell", [_object(ogre)])
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, bear)

	assert_eq(Scenario.counters_of(PLUS, SourceSelection.new()).evaluate(engine.game_state(), context), 2,
		"Not the Ogre's.")
	assert_eq(Scenario.counters_of(MINUS, SourceSelection.new()).evaluate(engine.game_state(), context), 0)
	var both: EachSelection = Scenario.each(Scenario.of_type(CardType.CREATURE))
	assert_eq(Scenario.counters_of(PLUS, both).evaluate(engine.game_state(), context), 4,
		"Summed over everything it selects; the Ogre's -1/-1 counter cancelled one of its three (CR 704.5q).")


func test_a_permanent_that_has_left_is_counted_as_it_last_was() -> void:
	# CR 608.2h.
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Grow", PLUS, 2), Scenario.free_destroy("Murder")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])

	Scenario.cast_and_resolve(engine, "Murder", [_object(bear)])

	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0, [_object(bear)] as Array[MmReference])
	assert_eq(Scenario.counters_of(PLUS, Scenario.targeted(0)).evaluate(engine.game_state(), context), 2)


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


## An instant costing {0}: "Put a +1/+1 counter on target artifact."
func _artifact_counters(card_name: String) -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(CardType.ARTIFACT))],
		[Scenario.put_counters(PLUS, 1, Scenario.targeted(0))])


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
