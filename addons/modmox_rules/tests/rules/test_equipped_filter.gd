extends GutTest
## "Equipped" (CR 301.5): a permanent with an Equipment attached to it, as in "Equipped
## creatures you control get +1/+1" (Kemba, Kha Enduring), "As long as this creature is
## equipped, it has first strike and lifelink" (Sunspear Shikari) and "Equipped creatures
## you control gain indestructible until end of turn" (Resistance Reunited).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType


func test_equipped_creatures_you_control_get_the_bonus_and_unequipped_ones_do_not() -> void:
	var engine: MmEngine = _hero_main([Scenario.kemba(), _bear(), _wolf(), Scenario.sword("Sword", 0)], [], [])
	var kemba: int = Scenario.permanent_named(engine, engine.hero().id, "Kemba")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wolf: int = Scenario.permanent_named(engine, engine.hero().id, "Wolf")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	assert_eq(Scenario.pt(engine, bear), [2, 2], "Nothing is equipped yet.")

	Scenario.equip_and_resolve(engine, sword, bear)

	assert_eq(Scenario.pt(engine, bear), [3, 3])
	assert_eq(Scenario.pt(engine, wolf), [3, 3], "Unequipped.")
	assert_eq(Scenario.pt(engine, kemba), [2, 2], "Unequipped.")


func test_an_opponents_equipped_creature_does_not_get_the_bonus() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword", 0)], [Scenario.kemba()], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")

	Scenario.equip_and_resolve(engine, sword, bear)

	assert_eq(Scenario.pt(engine, bear), [2, 2], "The Villain's Kemba gives only the Villain's creatures.")


func test_a_creature_with_two_equipment_is_equipped_once() -> void:
	var engine: MmEngine = _hero_main([Scenario.kemba(), _bear(), Scenario.sword("Sword", 0), Scenario.sword("Axe", 0)], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), bear)
	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Axe"), bear)

	assert_eq(Scenario.pt(engine, bear), [3, 3])


func test_the_bonus_follows_the_equipment_to_another_creature() -> void:
	var engine: MmEngine = _hero_main([Scenario.kemba(), _bear(), _wolf(), Scenario.sword("Sword", 0)], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wolf: int = Scenario.permanent_named(engine, engine.hero().id, "Wolf")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)

	Scenario.equip_and_resolve(engine, sword, wolf)

	assert_eq(Scenario.pt(engine, bear), [2, 2])
	assert_eq(Scenario.pt(engine, wolf), [4, 4])


func test_a_creature_whose_equipment_is_destroyed_is_no_longer_equipped() -> void:
	var smash: MmCardDefinition = Scenario.instant("Smash", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(CardType.ARTIFACT))], [Scenario.destroy(Scenario.targeted(0))])
	var engine: MmEngine = _hero_main([Scenario.kemba(), _bear(), Scenario.sword("Sword", 0)], [], [smash])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)

	Scenario.cast_and_resolve(engine, "Smash", [_object(sword)])

	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_a_creature_that_leaves_and_returns_is_not_equipped() -> void:
	# ADR 0008, CR 400.7: the creature that comes back is a new object.
	var engine: MmEngine = _hero_main([Scenario.kemba(), _bear(), Scenario.sword("Sword", 0)], [], [Scenario.free_bounce("Bounce")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), bear)

	Scenario.cast_and_resolve(engine, "Bounce", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Bear")

	assert_eq(Scenario.pt(engine, Scenario.permanent_named(engine, engine.hero().id, "Bear")), [2, 2])


func test_it_never_matches_a_player_or_an_unattached_equipment() -> void:
	var engine: MmEngine = _hero_main([_bear(), Scenario.sword("Sword", 0)], [], [])
	var state: MmGameState = engine.game_state()
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, Scenario.permanent_named(engine, engine.hero().id, "Bear"))

	assert_false(Scenario.equipped().matches(state, MmReference.to_player(engine.hero().id), null))
	assert_false(Scenario.equipped().matches(state, _object(sword), null), "The Equipment itself is not equipped.")


func test_unequipped_matches_only_creatures_with_nothing_attached() -> void:
	var unequipped_anthem: MmCardDefinition = Scenario.enchantment("Banner",
		[Scenario.continuous_static([Scenario.modify_pt(1, 1, Scenario.each_creature(Scenario.is_not(Scenario.equipped())))])])
	var engine: MmEngine = _hero_main([unequipped_anthem, _bear(), _wolf(), Scenario.sword("Sword", 0)], [], [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wolf: int = Scenario.permanent_named(engine, engine.hero().id, "Wolf")

	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), bear)

	assert_eq(Scenario.pt(engine, bear), [2, 2])
	assert_eq(Scenario.pt(engine, wolf), [4, 4])


func test_as_long_as_it_is_equipped_it_has_first_strike_and_lifelink() -> void:
	var engine: MmEngine = _hero_main([Scenario.shikari(), Scenario.sword("Sword", 0)], [], [])
	var shikari: int = Scenario.permanent_named(engine, engine.hero().id, "Shikari")
	assert_false(Scenario.now(engine, shikari).has_ability(FirstStrikeAbility))
	assert_false(Scenario.now(engine, shikari).has_ability(LifelinkAbility))

	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), shikari)

	assert_true(Scenario.now(engine, shikari).has_ability(FirstStrikeAbility))
	assert_true(Scenario.now(engine, shikari).has_ability(LifelinkAbility))


func test_it_loses_first_strike_and_lifelink_once_unequipped() -> void:
	var engine: MmEngine = _hero_main([Scenario.shikari(), _bear(), Scenario.sword("Sword", 0)], [], [])
	var shikari: int = Scenario.permanent_named(engine, engine.hero().id, "Shikari")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, shikari)

	Scenario.equip_and_resolve(engine, sword, Scenario.permanent_named(engine, engine.hero().id, "Bear"))

	assert_false(Scenario.now(engine, shikari).has_ability(FirstStrikeAbility))
	assert_false(Scenario.now(engine, shikari).has_ability(LifelinkAbility))


func test_an_equipped_shikari_strikes_first_and_its_controller_gains_the_life() -> void:
	# CR 702.7b, 702.15b.
	var engine: MmEngine = _hero_main([Scenario.shikari(), Scenario.sword("Sword")], [_wolf()], [])
	var shikari: int = Scenario.permanent_named(engine, engine.hero().id, "Shikari")
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")
	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), shikari)
	var life: int = engine.hero().life
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	Scenario.declare_attackers(engine, [shikari])
	Scenario.pass_to_blockers(engine)

	Scenario.declare_blockers(engine, [[wolf, shikari]])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.permanents_named(engine, engine.villain().id, "Wolf"), [] as Array[int])
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Shikari"), [shikari], "The Wolf died before it dealt damage.")
	assert_eq(engine.hero().life, life + 3)


func test_equipped_creatures_gain_indestructible_until_end_of_turn() -> void:
	var engine: MmEngine = _hero_main([_bear(), _wolf(), Scenario.sword("Sword", 0)], [],
		[Scenario.free_reunite(), Scenario.free_destroy("Murder")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wolf: int = Scenario.permanent_named(engine, engine.hero().id, "Wolf")
	Scenario.equip_and_resolve(engine, Scenario.permanent_named(engine, engine.hero().id, "Sword"), bear)

	Scenario.cast_and_resolve(engine, "Reunite")

	assert_true(Scenario.now(engine, bear).has_ability(IndestructibleAbility))
	assert_false(Scenario.now(engine, wolf).has_ability(IndestructibleAbility))
	Scenario.cast_and_resolve(engine, "Murder", [_object(bear)])
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear"), [bear])


func test_what_gains_indestructible_is_fixed_as_it_resolves() -> void:
	# CR 611.2c: a creature equipped later does not gain it, and one unequipped later keeps it.
	var engine: MmEngine = _hero_main([_bear(), _wolf(), Scenario.sword("Sword", 0)], [], [Scenario.free_reunite()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wolf: int = Scenario.permanent_named(engine, engine.hero().id, "Wolf")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	Scenario.equip_and_resolve(engine, sword, bear)
	Scenario.cast_and_resolve(engine, "Reunite")

	Scenario.equip_and_resolve(engine, sword, wolf)

	assert_true(Scenario.now(engine, bear).has_ability(IndestructibleAbility))
	assert_false(Scenario.now(engine, wolf).has_ability(IndestructibleAbility))


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _wolf() -> MmCardDefinition:
	return Scenario.creature("Wolf", 3, 3)


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
