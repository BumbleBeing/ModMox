extends GutTest
## Lifelink (CR 702.15): damage a source with lifelink deals also causes its controller to
## gain that much life, as part of the damage itself (CR 120.3f).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_combat_damage_to_a_player_gains_its_controller_that_much_life() -> void:
	var engine: MmEngine = Scenario.combat_ready([_cleric()], [])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Cleric")])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 17)
	assert_eq(engine.hero().life, 23, "CR 702.15b")
	assert_true(Scenario.combat_damage_events(engine)[0].is_lifelink)


func test_combat_damage_to_a_creature_gains_life_too() -> void:
	var engine: MmEngine = Scenario.combat_ready([_cleric()], [Scenario.creature("Wall", 0, 5)])
	var cleric: int = Scenario.permanent_named(engine, engine.hero().id, "Cleric")
	Scenario.declare_attackers(engine, [cleric])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Wall"), cleric]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.hero().life, 23)
	assert_eq(engine.villain().life, 20)


func test_damage_from_a_source_without_lifelink_gains_nothing() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bear", 2, 2)], [])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Bear")])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.hero().life, 20)
	assert_false(Scenario.combat_damage_events(engine)[0].is_lifelink)


func test_noncombat_damage_from_a_lifelink_source_gains_life() -> void:
	var enters: TriggeredAbility = Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.deal_damage(2, Scenario.targeted(0))], [Scenario.target_player()])
	var engine: MmEngine = _hero_main([], [], [Scenario.creature("Zealot", 1, 1, [LifelinkAbility.new(), enters])])

	Scenario.cast_and_resolve(engine, "Zealot")
	Scenario.choose_target(engine, MmReference.to_player(engine.villain().id))
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().life, 18)
	assert_eq(engine.hero().life, 22, "CR 702.15b: any damage, not only combat damage.")


func test_prevented_damage_gains_nothing() -> void:
	var engine: MmEngine = Scenario.combat_ready([_cleric()], [], [Scenario.free_fog("Fog")])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Cleric")])

	assert_eq(Scenario.cast_and_resolve(engine, "Fog"), "")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.hero().life, 20, "CR 120.3f: only damage dealt gains life.")


func test_partly_prevented_damage_gains_only_what_was_dealt() -> void:
	var engine: MmEngine = Scenario.combat_ready([_cleric()], [], [Scenario.free_shield("Ward", 1)])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Cleric")])

	assert_eq(Scenario.cast_and_resolve(engine, "Ward", [MmReference.to_player(engine.villain().id)]), "")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 18)
	assert_eq(engine.hero().life, 22)


func test_two_instances_of_lifelink_gain_once() -> void:
	var twice: MmCardDefinition = Scenario.creature("Cleric", 3, 3, [LifelinkAbility.new(), LifelinkAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([twice], [])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Cleric")])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.hero().life, 23, "CR 702.15f")


func test_a_lifelink_creature_that_dies_in_combat_still_gains() -> void:
	var engine: MmEngine = Scenario.combat_ready([_cleric()], [Scenario.creature("Giant", 5, 5)])
	var cleric: int = Scenario.permanent_named(engine, engine.hero().id, "Cleric")
	Scenario.declare_attackers(engine, [cleric])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Giant"), cleric]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_null(engine.game_state().object(cleric))
	assert_eq(engine.hero().life, 23)


func test_the_gain_is_at_the_same_time_as_the_damage() -> void:
	var bears: Array[MmCardDefinition] = [Scenario.creature("Bear", 2, 2), Scenario.creature("Wolf", 2, 2)]
	var engine: MmEngine = Scenario.combat_ready(bears, [_cleric()], [Scenario.free_shock("Blast", 19)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wolf: int = Scenario.permanent_named(engine, engine.hero().id, "Wolf")
	Scenario.declare_attackers(engine, [bear, wolf])
	assert_eq(Scenario.cast_and_resolve(engine, "Blast", [MmReference.to_player(engine.villain().id)]), "")
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Cleric"), bear]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_false(engine.is_over(), "At 1 life, 2 damage and 3 life gained at once leave 2 (CR 510.2).")
	assert_eq(engine.villain().life, 2)


func _cleric() -> MmCardDefinition:
	return Scenario.creature("Cleric", 3, 3, [LifelinkAbility.new()])


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
