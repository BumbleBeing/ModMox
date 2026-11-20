extends GutTest
## Fight (CR 701.14): each of two creatures deals damage equal to its power to the other.
## The creatures themselves are the sources, so deathtouch and lifelink apply, and it is
## not combat damage. If either has left the battlefield, is no longer a creature, or is an
## illegal target, no damage is dealt at all (CR 701.14b).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_each_deals_damage_equal_to_its_power_to_the_other() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Brawler", 3, 5)], [Scenario.creature("Ogre", 2, 4)])
	var brawler: int = Scenario.permanent_named(engine, engine.hero().id, "Brawler")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(Scenario.cast_and_resolve(engine, "Fight", [MmReference.to_object(brawler), MmReference.to_object(ogre)]), "")

	assert_eq(engine.game_state().object(brawler).damage_marked, 2, "CR 701.14a: the Ogre's power.")
	assert_eq(engine.game_state().object(ogre).damage_marked, 3, "CR 701.14a: the Brawler's power.")
	var dealt: Array[MmEvent] = Scenario.events_of(engine, DamageEvent)
	assert_eq(dealt.size(), 2)
	assert_eq([(dealt[0] as DamageEvent).source_object_id, (dealt[1] as DamageEvent).source_object_id], [brawler, ogre],
		"Each creature is the source of its own damage.")


func test_both_die_when_each_is_lethal_to_the_other() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Brawler", 3, 3)], [Scenario.creature("Ogre", 3, 3)])
	var brawler: int = Scenario.permanent_named(engine, engine.hero().id, "Brawler")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	Scenario.cast_and_resolve(engine, "Fight", [MmReference.to_object(brawler), MmReference.to_object(ogre)])

	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Brawler") != -1, true, "Dealt at once (CR 701.14a).")
	assert_eq(Scenario.card_in_graveyard(engine, engine.villain(), "Ogre") != -1, true)


func test_a_deathtouch_fighter_kills_a_bigger_creature() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Asp", 1, 1, [DeathtouchAbility.new()])],
		[Scenario.creature("Giant", 7, 7)])
	var asp: int = Scenario.permanent_named(engine, engine.hero().id, "Asp")
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")

	Scenario.cast_and_resolve(engine, "Fight", [MmReference.to_object(asp), MmReference.to_object(giant)])

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Giant"), -1, "CR 702.2b: any damage from it.")


func test_a_lifelink_fighter_gains_its_controller_life() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Cleric", 2, 4, [LifelinkAbility.new()])],
		[Scenario.creature("Ogre", 2, 4)])
	var cleric: int = Scenario.permanent_named(engine, engine.hero().id, "Cleric")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	Scenario.cast_and_resolve(engine, "Fight", [MmReference.to_object(cleric), MmReference.to_object(ogre)])

	assert_eq(engine.hero().life, 22, "CR 702.15b")


func test_fight_damage_is_not_combat_damage() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Brawler", 3, 5)], [Scenario.creature("Ogre", 2, 4)])
	var brawler: int = Scenario.permanent_named(engine, engine.hero().id, "Brawler")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	Scenario.cast_and_resolve(engine, "Fight", [MmReference.to_object(brawler), MmReference.to_object(ogre)])

	for dealt: MmEvent in Scenario.events_of(engine, DamageEvent):
		assert_false((dealt as DamageEvent).is_combat)


func test_no_damage_is_dealt_when_one_creature_has_left() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Brawler", 3, 5)], [Scenario.creature("Ogre", 2, 4)],
		[Scenario.free_destroy("Destroy")])
	var brawler: int = Scenario.permanent_named(engine, engine.hero().id, "Brawler")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	var fight: int = Scenario.card_in_hand(engine, engine.hero(), "Fight")
	assert_eq(Scenario.cast(engine, fight, [MmReference.to_object(brawler), MmReference.to_object(ogre)]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Destroy", [MmReference.to_object(ogre)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.game_state().object(brawler).damage_marked, 0, "CR 701.14b: no damage is dealt.")
	assert_eq(Scenario.events_of(engine, DamageEvent).size(), 0)


func test_a_creature_with_no_power_deals_none_but_is_still_dealt_damage() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Wall", 0, 5)], [Scenario.creature("Ogre", 2, 4)])
	var wall: int = Scenario.permanent_named(engine, engine.hero().id, "Wall")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	Scenario.cast_and_resolve(engine, "Fight", [MmReference.to_object(wall), MmReference.to_object(ogre)])

	assert_eq(engine.game_state().object(wall).damage_marked, 2)
	assert_eq(engine.game_state().object(ogre).damage_marked, 0, "CR 120.8: 0 damage is not dealt.")


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.free_fight()]
	extras.append_array(hero_extras)
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
