extends GutTest
## Destroying (CR 701.8), regeneration shields (CR 701.19) and indestructible (CR 702.12),
## with deathtouch's "since the last check" (CR 704.5h).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_destroy_effect_puts_a_creature_into_its_graveyard() -> void:
	var engine: MmEngine = _main_ready([], [_bear()], [Scenario.free_destroy("Doom")])
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")

	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(bear)])

	assert_null(engine.game_state().object(bear))
	assert_eq(Scenario.names(engine, engine.villain().graveyard), ["Bear"])


func test_a_regenerated_creature_survives_lethal_damage_tapped_and_healed() -> void:
	var engine: MmEngine = _main_ready([_skeleton()], [], [Scenario.free_regenerate("Mend"), Scenario.free_shock("Shock", 3)])
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	Scenario.cast_and_resolve(engine, "Mend", [MmReference.to_object(skeleton)])

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(skeleton)])

	var survivor: MmGameObject = engine.game_state().object(skeleton)
	assert_not_null(survivor, "CR 701.19a: it is not destroyed.")
	assert_true(survivor.is_tapped)
	assert_eq(survivor.damage_marked, 0)
	assert_eq(Scenario.events_of(engine, RegeneratedEvent).size(), 1)
	assert_eq(engine.game_state().replacement_effects, [], "The shield is used up.")


func test_a_regeneration_ability_with_no_mana_cost_makes_a_shield() -> void:
	var engine: MmEngine = _main_ready([_skeleton()], [], [Scenario.free_destroy("Doom")])
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")

	assert_eq(Scenario.activate(engine, skeleton), "")
	Scenario.resolve_stack(engine)
	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(skeleton)])

	assert_not_null(engine.game_state().object(skeleton))


func test_a_regenerated_blocker_is_removed_from_combat_and_its_attacker_stays_blocked() -> void:
	# CR 701.19a removes it from combat; CR 509.1h keeps the attacker blocked, so without
	# trample it deals no damage (CR 510.1c).
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Giant", 5, 5)], [_skeleton()], [],
		[Scenario.free_regenerate("Mend"), Scenario.free_destroy("Doom")])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	var skeleton: int = Scenario.permanent_named(engine, engine.villain().id, "Skeleton")
	Scenario.declare_attackers(engine, [giant])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[skeleton, giant]])
	Scenario.pass_priority(engine)
	Scenario.cast_and_resolve(engine, "Mend", [MmReference.to_object(skeleton)])
	Scenario.pass_priority(engine)

	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(skeleton)])

	assert_false(engine.game_state().combat.is_blocking(skeleton))
	assert_true(engine.game_state().combat.is_blocked(giant))
	assert_eq(Scenario.events_of(engine, RemovedFromCombatEvent).size(), 1)
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	assert_eq(engine.villain().life, 20)
	assert_eq(Scenario.damage_on(engine, skeleton), 0)


func test_an_attacker_that_is_already_tapped_regenerates_without_tapping_again() -> void:
	var engine: MmEngine = Scenario.combat_ready([_skeleton()], [_bear()], [Scenario.free_regenerate("Mend")])
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	Scenario.declare_attackers(engine, [skeleton])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Bear"), skeleton]])
	Scenario.cast_and_resolve(engine, "Mend", [MmReference.to_object(skeleton)])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_not_null(engine.game_state().object(skeleton))
	assert_eq(Scenario.events_of(engine, TapEvent).size(), 1, "Only the attack tapped it.")
	assert_false(engine.game_state().combat.is_attacking(skeleton))


func test_regeneration_does_not_save_a_creature_with_zero_toughness() -> void:
	# CR 704.5f puts it into the graveyard without destroying it.
	var engine: MmEngine = _main_ready([_skeleton()], [], [Scenario.free_regenerate("Mend"), Scenario.pump_spell("Wither", -1, -1)])
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	Scenario.cast_and_resolve(engine, "Mend", [MmReference.to_object(skeleton)])

	Scenario.cast_and_resolve(engine, "Wither", [MmReference.to_object(skeleton)])

	assert_null(engine.game_state().object(skeleton))
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.ZERO_TOUGHNESS)
	assert_eq(Scenario.events_of(engine, RegeneratedEvent), [], "The shield never applied.")


func test_a_destroy_that_cannot_be_regenerated_ignores_the_shield() -> void:
	var engine: MmEngine = _main_ready([_skeleton()], [], [Scenario.free_regenerate("Mend"), Scenario.free_destroy("Doom", false)])
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	Scenario.cast_and_resolve(engine, "Mend", [MmReference.to_object(skeleton)])

	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(skeleton)])

	assert_null(engine.game_state().object(skeleton))
	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Mend", "Skeleton", "Doom"])
	assert_eq(Scenario.events_of(engine, RegeneratedEvent), [])


func test_a_destroy_effect_can_be_regenerated_unless_it_says_otherwise() -> void:
	var effect: DestroyEffect = DestroyEffect.new()

	assert_true(effect.can_be_regenerated)


func test_two_regeneration_shields_need_no_choice_and_one_is_left() -> void:
	var engine: MmEngine = _main_ready([_skeleton()], [],
		[Scenario.free_regenerate("Mend"), Scenario.free_regenerate("Knit"), Scenario.free_destroy("Doom")])
	var skeleton: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Skeleton"))
	Scenario.cast_and_resolve(engine, "Mend", [skeleton])
	var knit: int = engine.game_state().object(Scenario.card_in_hand(engine, engine.hero(), "Knit")).card_id
	Scenario.cast_and_resolve(engine, "Knit", [skeleton])

	Scenario.cast_and_resolve(engine, "Doom", [skeleton])

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_not_null(engine.game_state().object(skeleton.id))
	assert_eq(engine.game_state().replacement_effects.size(), 1)
	assert_eq(engine.game_state().replacement_effects[0].source_card_id, knit, "The earliest shield was used.")


func test_a_regenerated_creature_dealt_deathtouch_damage_is_not_destroyed_again() -> void:
	# CR 704.5h asks about deathtouch damage since the last check, which regeneration ended.
	var viper: MmCardDefinition = Scenario.creature("Viper", 1, 1, [DeathtouchAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([_skeleton(2, 2)], [viper], [Scenario.free_regenerate("Mend")])
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	Scenario.declare_attackers(engine, [skeleton])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Viper"), skeleton]])
	Scenario.cast_and_resolve(engine, "Mend", [MmReference.to_object(skeleton)])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_not_null(engine.game_state().object(skeleton))
	assert_false(engine.game_state().object(skeleton).was_dealt_deathtouch_damage)


func test_an_indestructible_creature_survives_lethal_damage_and_keeps_it_marked() -> void:
	var engine: MmEngine = _main_ready([_statue()], [], [Scenario.free_shock("Shock", 3)])
	var statue: int = Scenario.permanent_named(engine, engine.hero().id, "Statue")

	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(statue)])

	assert_not_null(engine.game_state().object(statue), "CR 702.12b")
	assert_eq(Scenario.damage_on(engine, statue), 3)


func test_an_indestructible_creature_survives_deathtouch_and_the_damage_is_forgotten() -> void:
	var viper: MmCardDefinition = Scenario.creature("Viper", 1, 1, [DeathtouchAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([_statue()], [viper])
	var statue: int = Scenario.permanent_named(engine, engine.hero().id, "Statue")
	Scenario.declare_attackers(engine, [statue])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Viper"), statue]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_not_null(engine.game_state().object(statue))
	assert_false(engine.game_state().object(statue).was_dealt_deathtouch_damage, "Cleared after the check.")


func test_an_indestructible_creature_still_dies_to_zero_toughness() -> void:
	var engine: MmEngine = _main_ready([_statue()], [], [Scenario.pump_spell("Wither", -2, -2)])
	var statue: int = Scenario.permanent_named(engine, engine.hero().id, "Statue")

	Scenario.cast_and_resolve(engine, "Wither", [MmReference.to_object(statue)])

	assert_null(engine.game_state().object(statue))


func test_destroying_an_indestructible_creature_does_nothing_but_the_spell_resolves() -> void:
	var engine: MmEngine = _main_ready([_statue()], [], [Scenario.free_destroy("Doom")])
	var statue: int = Scenario.permanent_named(engine, engine.hero().id, "Statue")

	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(statue)])

	assert_not_null(engine.game_state().object(statue))
	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Doom"], "Only the spell, which resolved.")


func test_an_indestructible_creature_does_not_use_up_its_regeneration_shield() -> void:
	var engine: MmEngine = _main_ready([_statue()], [], [Scenario.free_regenerate("Mend"), Scenario.free_shock("Shock", 3)])
	var statue: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Statue"))
	Scenario.cast_and_resolve(engine, "Mend", [statue])

	Scenario.cast_and_resolve(engine, "Shock", [statue])

	assert_eq(engine.game_state().replacement_effects.size(), 1)
	assert_eq(Scenario.events_of(engine, RegeneratedEvent), [])


func _skeleton(power: int = 1, toughness: int = 1) -> MmCardDefinition:
	return Scenario.creature("Skeleton", power, toughness, [Scenario.regenerate_ability(Scenario.mana_cost(0))])


func _statue() -> MmCardDefinition:
	return Scenario.creature("Statue", 2, 2, [IndestructibleAbility.new()])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _main_ready(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, villain_creatures, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, villain_creatures, hero_extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
