extends GutTest
## Protection (CR 702.16): damage from matching sources is prevented, and a protected
## permanent can't be blocked by matching creatures or targeted by matching spells or
## abilities from matching sources. Protection's quality is a Filter, so these tests use
## "protection from Goblins" and "protection from instants" with free cards; the colored
## Alpha Knights are checked in the Content tests.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_damage_from_a_matching_source_is_prevented() -> void:
	var engine: MmEngine = Scenario.combat_ready([_goblin("Goblin", 3, 3)], [_knight()])
	var goblin: int = Scenario.permanent_named(engine, engine.hero().id, "Goblin")
	var knight: int = Scenario.permanent_named(engine, engine.villain().id, "Knight")
	Scenario.declare_attackers(engine, [goblin])
	Scenario.pass_to_blockers(engine)

	assert_eq(Scenario.declare_blockers(engine, [[knight, goblin]]), "", "Protection does not stop it blocking.")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, knight), 0, "CR 702.16e")
	assert_eq(Scenario.damage_on(engine, goblin), 2)
	assert_eq((Scenario.prevented(engine)[0] as DamagePreventedEvent).prevented_by_card_id, Scenario.card_of(engine, knight))


func test_damage_from_a_source_that_does_not_match_is_dealt() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bear", 2, 2)], [_knight()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var knight: int = Scenario.permanent_named(engine, engine.villain().id, "Knight")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[knight, bear]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_null(engine.game_state().object(knight), "A Bear is not a Goblin.")
	assert_eq(Scenario.prevented(engine), [])


func test_protection_and_fog_both_prevent_everything_so_nobody_is_asked() -> void:
	var engine: MmEngine = Scenario.combat_ready([_goblin("Goblin", 3, 3)], [_knight()], [Scenario.free_fog("Fog")])
	var goblin: int = Scenario.permanent_named(engine, engine.hero().id, "Goblin")
	var knight: int = Scenario.permanent_named(engine, engine.villain().id, "Knight")
	Scenario.declare_attackers(engine, [goblin])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[knight, goblin]])
	Scenario.cast_and_resolve(engine, "Fog")

	assert_true(Scenario.pass_until_step_without_replacement_choice(engine, Step.END_OF_COMBAT), "No replacement decision is asked.")

	assert_eq(Scenario.damage_on(engine, knight), 0)
	assert_eq(Scenario.damage_on(engine, goblin), 0)


func test_a_protected_attacker_cannot_be_blocked_by_matching_creatures() -> void:
	var engine: MmEngine = Scenario.combat_ready([_knight()], [_goblin("Goblin", 1, 1), Scenario.creature("Bear", 2, 2)])
	var knight: int = Scenario.permanent_named(engine, engine.hero().id, "Knight")
	Scenario.declare_attackers(engine, [knight])
	Scenario.pass_to_blockers(engine)

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision

	assert_eq(decision.candidate_blocker_ids, [Scenario.permanent_named(engine, engine.villain().id, "Bear")], "CR 702.16c")


func test_a_protected_creature_cannot_be_targeted_by_a_matching_spell() -> void:
	var warded: MmCardDefinition = Scenario.creature("Warded", 2, 2, [Scenario.protection_from(Scenario.of_type(MmCardTypes.CardType.INSTANT))])
	var engine: MmEngine = _main_ready([], [warded, Scenario.creature("Bear", 2, 2)], [Scenario.free_shock("Shock", 3)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision

	var bear: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Bear"))
	var warded_id: int = Scenario.permanent_named(engine, engine.villain().id, "Warded")
	assert_true(_has_candidate(decision, bear))
	assert_false(_has_candidate(decision, MmReference.to_object(warded_id)), "CR 702.16b")


func test_a_protected_creature_cannot_be_targeted_by_an_ability_from_a_matching_source() -> void:
	var pinger: MmCardDefinition = _goblin("Pinger", 1, 1, [_ping_ability()])
	var engine: MmEngine = _main_ready([pinger], [_knight(), Scenario.creature("Bear", 2, 2)], [])
	var pinger_id: int = Scenario.permanent_named(engine, engine.hero().id, "Pinger")

	Scenario.activate(engine, pinger_id)

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_false(_has_candidate(decision, MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Knight"))))
	assert_true(_has_candidate(decision, MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Bear"))))


func test_a_spell_fizzles_when_its_only_target_gains_protection() -> void:
	# CR 608.2b: the target is rechecked on resolution.
	var gift: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Gift",
		Scenario.gain_abilities([Scenario.protection_from(Scenario.of_type(MmCardTypes.CardType.INSTANT))], Scenario.targeted(0)))
	var engine: MmEngine = _main_ready([], [Scenario.creature("Bear", 2, 2)], [Scenario.free_shock("Shock", 3), gift])
	var bear: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Bear"))
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [bear])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift"), [bear])

	Scenario.resolve_stack(engine)

	assert_eq(Scenario.damage_on(engine, bear.id), 0)
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.DID_NOT_RESOLVE)


func test_a_trampler_must_assign_lethal_damage_to_a_protected_blocker() -> void:
	# CR 702.19b: lethal damage is worked out without the prevention that will follow.
	var trampler: MmCardDefinition = _goblin("Trampler", 5, 5, [TrampleAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([trampler], [_knight()])
	var trampler_id: int = Scenario.permanent_named(engine, engine.hero().id, "Trampler")
	var knight: int = Scenario.permanent_named(engine, engine.villain().id, "Knight")
	Scenario.declare_attackers(engine, [trampler_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[knight, trampler_id]])
	Scenario.autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is DivideCombatDamageDecision)

	assert_ne(engine.submit([0, 5]), "", "The Knight must be assigned lethal damage first.")
	assert_eq(engine.submit([2, 3]), "")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 17)
	assert_eq(Scenario.damage_on(engine, knight), 0)


func test_protection_from_creatures_prevents_damage_from_any_creature() -> void:
	var wall: MmCardDefinition = Scenario.creature("Wall", 0, 2, [Scenario.protection_from(Scenario.of_type(MmCardTypes.CardType.CREATURE))])
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bear", 2, 2)], [wall])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var wall_id: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[wall_id, bear]])

	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, wall_id), 0)


func test_protection_and_a_shield_on_one_creature_let_its_controller_choose() -> void:
	# CR 616.1: protection's prevention is one more effect to order.
	var engine: MmEngine = Scenario.combat_ready([_goblin("Goblin", 3, 3)], [_knight()], [], [Scenario.free_shield("Ward", 1)])
	var goblin: int = Scenario.permanent_named(engine, engine.hero().id, "Goblin")
	var knight: int = Scenario.permanent_named(engine, engine.villain().id, "Knight")
	Scenario.declare_attackers(engine, [goblin])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[knight, goblin]])
	Scenario.pass_priority(engine)
	var ward: int = engine.game_state().object(Scenario.card_in_hand(engine, engine.villain(), "Ward")).card_id
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Ward"), [MmReference.to_object(knight)])

	Scenario.pass_to_replacement_choice(engine)

	var decision: ChooseReplacementEffectDecision = engine.pending_decision() as ChooseReplacementEffectDecision
	assert_eq(decision.player_id, engine.villain().id)
	assert_eq(Scenario.choose_replacement_from(engine, Scenario.card_of(engine, knight)), "")
	assert_eq(Scenario.damage_on(engine, knight), 0)
	assert_eq(engine.game_state().replacement_effects.size(), 1, "The Ward shield is kept.")
	assert_eq(engine.game_state().replacement_effects[0].source_card_id, ward)


func _knight() -> MmCardDefinition:
	return Scenario.creature("Knight", 2, 2, [Scenario.protection_from(Scenario.has_subtype("Goblin"))])


func _goblin(card_name: String, power: int, toughness: int, abilities: Array[MmAbility] = []) -> MmCardDefinition:
	var goblin: MmCardDefinition = Scenario.creature(card_name, power, toughness, abilities)
	goblin.subtypes = ["Goblin"]
	return goblin


## "{T}: This deals 1 damage to any target."
func _ping_ability() -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.any_target()]
	ability.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
	return ability


func _has_candidate(decision: ChooseTargetDecision, wanted: MmReference) -> bool:
	for candidate: MmReference in decision.candidates:
		if candidate.equals(wanted):
			return true
	return false


func _main_ready(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, villain_creatures, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, villain_creatures, hero_extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
