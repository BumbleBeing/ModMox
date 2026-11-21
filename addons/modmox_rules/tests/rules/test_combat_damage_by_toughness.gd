extends GutTest
## Assigning combat damage by toughness (CR 510.1a), as Bark of Doran's "As long as equipped
## creature's toughness is greater than its power, it assigns combat damage equal to its
## toughness rather than its power" (AssignsCombatDamageByToughnessAbility). Only the amount of
## combat damage changes: power is unchanged for everything else, and the creature gains no
## ability (ADR 0018).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_an_unblocked_equipped_creature_deals_damage_equal_to_its_toughness() -> void:
	var engine: MmEngine = _barked(_oak(1, 3))
	var oak: int = _hero_permanent(engine, "Oak")
	assert_eq(Scenario.pt(engine, oak), [1, 4])

	Scenario.declare_attackers(engine, [oak])
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 16)
	var events: Array[DamageEvent] = Scenario.combat_damage_events(engine)
	assert_eq(events.size(), 1)
	assert_eq(events[0].amount, 4)


func test_a_blocked_attacker_deals_damage_equal_to_its_toughness_to_its_blocker() -> void:
	var engine: MmEngine = _barked(_oak(1, 3), [Scenario.creature("Ogre", 2, 5)])
	var oak: int = _hero_permanent(engine, "Oak")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [oak])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[ogre, oak]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, ogre), 4)
	assert_eq(Scenario.damage_on(engine, oak), 2, "The Ogre assigns its power as ever.")


func test_a_blocker_that_assigns_by_toughness_deals_its_toughness_to_the_attacker_it_blocks() -> void:
	# CR 510.1d, with "This creature assigns combat damage equal to its toughness rather than its power".
	var wall: MmCardDefinition = Scenario.creature("Wall", 0, 4, [Scenario.by_toughness()])
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Ox", 2, 6)], [wall])
	assert_not_null(engine)
	var ox: int = _hero_permanent(engine, "Ox")
	var wall_id: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
	Scenario.declare_attackers(engine, [ox])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[wall_id, ox]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, ox), 4)
	assert_eq(Scenario.damage_on(engine, wall_id), 2)


func test_a_creature_with_no_power_assigns_damage_equal_to_its_toughness() -> void:
	# CR 510.1a: only a creature that would assign 0 or less assigns none, and this one would
	# assign 4.
	var engine: MmEngine = _barked(_oak(0, 3))
	Scenario.declare_attackers(engine, [_hero_permanent(engine, "Oak")])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 16)


func test_a_creature_whose_toughness_is_not_greater_than_its_power_assigns_its_power() -> void:
	var engine: MmEngine = _barked(_oak(4, 1))
	var oak: int = _hero_permanent(engine, "Oak")
	assert_eq(Scenario.pt(engine, oak), [4, 2])
	Scenario.declare_attackers(engine, [oak])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 16, "Its power, 4, not its toughness, 2.")


func test_whether_it_assigns_by_toughness_is_asked_as_combat_damage_is_assigned() -> void:
	# A 1/4 attacks, then grows to 5/4 before damage: its toughness is no longer greater.
	var engine: MmEngine = _barked(_oak(1, 3), [], [Scenario.pump_spell("Might", 4, 0)])
	var oak: int = _hero_permanent(engine, "Oak")
	Scenario.declare_attackers(engine, [oak])
	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)
	assert_eq(Scenario.cast_and_resolve(engine, "Might", [MmReference.to_object(oak)]), "")
	assert_eq(Scenario.pt(engine, oak), [5, 4])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 15)


func test_a_creature_that_assigns_by_toughness_still_fights_with_its_power() -> void:
	# CR 701.14a: fighting is not combat damage.
	var engine: MmEngine = _hero_main([_oak(1, 3), Scenario.bark()], [Scenario.creature("Bear", 2, 4)], [Scenario.free_fight()])
	var oak: int = _hero_permanent(engine, "Oak")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	assert_eq(Scenario.equip_and_resolve(engine, _hero_permanent(engine, "Bark"), oak), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Fight", [MmReference.to_object(oak), MmReference.to_object(bear)]), "")

	assert_eq(Scenario.damage_on(engine, bear), 1)
	assert_eq(Scenario.now(engine, oak).power, 1, "Its power is unchanged.")


func test_a_creature_that_loses_all_its_abilities_still_assigns_by_toughness() -> void:
	# The ability is the Equipment's, not the creature's.
	var hush: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Hush", Scenario.lose_all_abilities(Scenario.targeted(0)))
	var engine: MmEngine = _hero_main([_oak(1, 3), Scenario.bark()], [], [hush])
	var oak: int = _hero_permanent(engine, "Oak")
	assert_eq(Scenario.equip_and_resolve(engine, _hero_permanent(engine, "Bark"), oak), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Hush", [MmReference.to_object(oak)]), "")
	assert_eq(Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS), "")
	Scenario.declare_attackers(engine, [oak])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 16)


func test_a_trampler_that_assigns_by_toughness_divides_its_toughness() -> void:
	var engine: MmEngine = _barked(_oak(1, 4, [TrampleAbility.new()]), [Scenario.creature("Bear", 1, 2)])
	var oak: int = _hero_permanent(engine, "Oak")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [oak])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[bear, oak]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	var decision: DivideCombatDamageDecision = engine.pending_decision() as DivideCombatDamageDecision
	assert_not_null(decision, "5 is more than the Bear's lethal 2, so the Hero chooses.")
	assert_eq(decision.amount, 5)
	assert_eq(decision.lethal_amounts, [2])
	assert_eq(engine.submit([2, 3]), "")
	assert_eq(engine.villain().life, 17)


func test_an_unattached_equipment_makes_nothing_assign_by_toughness() -> void:
	var engine: MmEngine = _hero_main([_oak(1, 3), Scenario.bark()], [], [])
	assert_eq(Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS), "")
	Scenario.declare_attackers(engine, [_hero_permanent(engine, "Oak")])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 19)


func _oak(power: int, toughness: int, abilities: Array[MmAbility] = []) -> MmCardDefinition:
	return Scenario.creature("Oak", power, toughness, abilities)


func _hero_permanent(engine: MmEngine, card_name: String) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, card_name)


## The Hero's precombat main phase on Game Turn 3, with [param hero_permanents] and
## [param villain_permanents] on the battlefield and [param hero_extras] in hand.
func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## [param oak] equipped with Scenario.bark() in the Hero's main phase on Game Turn 3, then
## on to the Hero's attackers decision.
func _barked(oak: MmCardDefinition, villain_creatures: Array[MmCardDefinition] = [],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = _hero_main([oak, Scenario.bark()], villain_creatures, hero_extras)
	assert_eq(Scenario.equip_and_resolve(engine, _hero_permanent(engine, "Bark"), _hero_permanent(engine, "Oak")), "")
	assert_eq(Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS), "")
	return engine
