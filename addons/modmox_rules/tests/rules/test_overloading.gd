extends GutTest
## Overload (CR 702.96b, ADR 0014): a spell whose every "target" has become "each" affects
## each player, permanent, spell, ability or card it could have targeted. What it finds is
## fixed once as it begins to resolve and shared by every effect, it targets nothing, so
## ward never triggers, and it always resolves.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CREATURE := MmCardTypes.CardType.CREATURE


func test_an_overloaded_bolt_deals_damage_to_each_creature_and_each_player() -> void:
	var shock: MmCardDefinition = Scenario.overloaded(Scenario.free_shock("Shock", 3))
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [Scenario.creature("Ogre", 2, 4)], [shock])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.cast_and_resolve(engine, "Shock"), "", "Cast with no target to choose.")

	assert_eq([engine.hero().life, engine.villain().life], [17, 17], "Each player, its controller too.")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Bear"), -1, "Each creature, its controller's too.")
	assert_eq(engine.game_state().object(ogre).damage_marked, 3)


func test_an_overloaded_spell_targets_nothing_so_ward_does_not_trigger() -> void:
	var shock: MmCardDefinition = Scenario.overloaded(Scenario.free_shock("Shock", 3))
	var engine: MmEngine = _hero_main([], [Scenario.warden()], [shock])
	var cast_shock: int = Scenario.card_in_hand(engine, engine.hero(), "Shock")

	assert_eq(Scenario.cast(engine, cast_shock), "")

	assert_eq(Scenario.stack_ids(engine).size(), 1, "CR 702.21a: only becoming a target triggers ward.")
	Scenario.resolve_stack(engine)
	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Warden"), -1)


func test_an_overloaded_counter_counters_each_other_spell() -> void:
	var counter: MmCardDefinition = Scenario.overloaded(Scenario.free_counter("Counter"))
	var engine: MmEngine = _hero_main([], [], [Scenario.free_shock("Shock", 3), Scenario.free_shock("Zap", 1), counter])
	var villain: MmReference = MmReference.to_player(engine.villain().id)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [villain]), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Zap"), [villain]), "")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Counter")), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().life, 20, "Both spells were countered, its controller's own too.")
	for card_name: String in ["Shock", "Zap", "Counter"]:
		assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), card_name), -1, card_name)


func test_an_overloaded_stifle_counters_each_ability_and_no_spell() -> void:
	var stifle: MmCardDefinition = Scenario.overloaded(Scenario.free_stifle("Stifle"))
	var engine: MmEngine = _hero_main([], [Scenario.warden()], [Scenario.free_shock("Shock", 3), stifle])
	var warden: int = Scenario.permanent_named(engine, engine.villain().id, "Warden")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [MmReference.to_object(warden)]), "")
	assert_eq(Scenario.stack_ids(engine).size(), 2, "Ward triggered above the Shock.")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Stifle")), "")
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Warden"), -1, "Ward was countered, the Shock was not.")


func test_an_overloaded_raise_returns_each_creature_card_from_your_graveyard() -> void:
	var destroy: MmCardDefinition = Scenario.overloaded(Scenario.free_destroy("Destroy"))
	var raise: MmCardDefinition = Scenario.overloaded(Scenario.free_raise("Raise"))
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2), Scenario.creature("Elk", 2, 2)],
		[Scenario.creature("Ogre", 2, 4)], [destroy, raise])
	assert_eq(Scenario.cast_and_resolve(engine, "Destroy"), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Raise"), "")

	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Bear"), -1)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Elk"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Ogre"), -1, "Only cards in your graveyard.")


func test_an_overloaded_spell_that_finds_nothing_still_resolves() -> void:
	var stifle: MmCardDefinition = Scenario.overloaded(Scenario.free_stifle("Stifle"))
	var engine: MmEngine = _hero_main([], [], [stifle])

	assert_eq(Scenario.cast_and_resolve(engine, "Stifle"), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Stifle"), -1, "It resolved, finding nothing.")


func test_what_it_finds_is_fixed_once_and_each_one_is_counted() -> void:
	var disarm: MmCardDefinition = Scenario.instant("Disarm", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(CREATURE))],
		[Scenario.exile(Scenario.targeted(0)), Scenario.gain_life(3, Scenario.controller_of(Scenario.targeted(0)))])
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2), Scenario.creature("Elk", 2, 2)],
		[Scenario.creature("Ogre", 2, 4)], [Scenario.overloaded(disarm)])

	assert_eq(Scenario.cast_and_resolve(engine, "Disarm"), "")

	assert_eq(engine.hero().life, 26, "3 life for each of their two creatures, though both had left.")
	assert_eq(engine.villain().life, 23)
	var gains: Array[MmEvent] = Scenario.events_of(engine, LifeGainedEvent)
	assert_eq(gains.size(), 2, "One life gain for each player.")


func test_each_mode_of_an_overloaded_modal_spell_is_overloaded() -> void:
	var charm: MmCardDefinition = Scenario.overloaded(Scenario.free_charm("Charm", 2))
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [Scenario.creature("Ogre", 2, 4)], [charm])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.cast_mode(engine, Scenario.card_in_hand(engine, engine.hero(), "Charm"), 0), "")
	Scenario.resolve_stack(engine)

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Bear"), -1)
	assert_eq(engine.game_state().object(ogre).damage_marked, 2)


func test_up_to_two_targets_becomes_each() -> void:
	var gird: MmCardDefinition = Scenario.overloaded(Scenario.free_gird("Gird"))
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2), Scenario.creature("Elk", 2, 2)],
		[Scenario.creature("Ogre", 2, 4)], [gird])

	assert_eq(Scenario.cast_and_resolve(engine, "Gird"), "")

	for found: Array in [[engine.hero().id, "Bear"], [engine.hero().id, "Elk"], [engine.villain().id, "Ogre"]]:
		var permanent: int = Scenario.permanent_named(engine, found[0] as int, found[1] as String)
		assert_eq(Scenario.counters_on(engine, permanent, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 1, found[1] as String)


func test_each_creature_you_control_fights_each_creature_you_dont() -> void:
	var fight: MmCardDefinition = Scenario.overloaded(Scenario.free_fight("Fight"))
	var engine: MmEngine = _hero_main([Scenario.creature("Brawler", 3, 9), Scenario.creature("Scout", 1, 9)],
		[Scenario.creature("Ogre", 2, 9), Scenario.creature("Troll", 2, 9)], [fight])

	assert_eq(Scenario.cast_and_resolve(engine, "Fight"), "")

	for found: Array in [[engine.hero().id, "Brawler", 4], [engine.hero().id, "Scout", 4],
			[engine.villain().id, "Ogre", 4], [engine.villain().id, "Troll", 4]]:
		var permanent: int = Scenario.permanent_named(engine, found[0] as int, found[1] as String)
		assert_eq(engine.game_state().object(permanent).damage_marked, found[2] as int, found[1] as String)
	assert_eq(Scenario.events_of(engine, DamageEvent).size(), 8, "Each deals its power to each on the other side.")


func test_no_creature_fights_when_the_other_side_has_none() -> void:
	var fight: MmCardDefinition = Scenario.overloaded(Scenario.free_fight("Fight"))
	var engine: MmEngine = _hero_main([Scenario.creature("Brawler", 3, 5)], [], [fight])

	assert_eq(Scenario.cast_and_resolve(engine, "Fight"), "")

	assert_eq(Scenario.events_of(engine, DamageEvent).size(), 0, "CR 701.14b")


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
