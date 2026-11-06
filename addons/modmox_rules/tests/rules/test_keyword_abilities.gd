extends GutTest
## Rule-hook keywords: flying (CR 702.9), reach (702.17), vigilance (702.20), haste (702.10),
## defender (702.3) and deathtouch (702.2, with state-based action 704.5h).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_flyer_can_be_blocked_only_by_flyers_and_reach() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bird()], [_bear(), _spider(), Scenario.creature("Hawk", 1, 1, [FlyingAbility.new()])])
	var bird: int = Scenario.permanent_named(engine, engine.hero().id, "Bird")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	var spider: int = Scenario.permanent_named(engine, engine.villain().id, "Spider")
	var hawk: int = Scenario.permanent_named(engine, engine.villain().id, "Hawk")
	Scenario.declare_attackers(engine, [bird])
	Scenario.pass_to_blockers(engine)

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.candidate_blocker_ids, [spider, hawk], "The Bear cannot block anything.")
	assert_ne(engine.submit([[bear, bird]]), "")
	assert_eq(engine.submit([[spider, bird], [hawk, bird]]), "")


func test_a_flyer_can_block_a_ground_creature() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_bird()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)

	assert_eq(engine.submit([[Scenario.permanent_named(engine, engine.villain().id, "Bird"), bear]]), "")


func test_vigilance_keeps_an_attacker_untapped() -> void:
	var angel: MmCardDefinition = Scenario.creature("Angel", 4, 4, [VigilanceAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([angel], [])
	var angel_id: int = Scenario.permanent_named(engine, engine.hero().id, "Angel")

	Scenario.declare_attackers(engine, [angel_id])

	assert_false(engine.game_state().object(angel_id).is_tapped)
	assert_true(engine.game_state().combat.is_attacking(angel_id))


func test_haste_attacks_and_taps_the_turn_it_arrives() -> void:
	var raider: MmCardDefinition = Scenario.creature("Raider", 1, 1, [HasteAbility.new(), Scenario.tap_for_mana(MmMana.Type.RED, 1)])
	var no_cards: Array[MmCardDefinition] = []
	var extras: Array[MmCardDefinition] = [raider]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Raider")
	var raider_id: int = Scenario.permanent_named(engine, engine.hero().id, "Raider")

	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, raider_id), -1)
	assert_false(engine.view_for(engine.hero()).battlefield[0].is_summoning_sick)
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	assert_eq((engine.pending_decision() as DeclareAttackersDecision).candidate_ids, [raider_id])


func test_defender_cannot_attack() -> void:
	var wall: MmCardDefinition = Scenario.creature("Wall", 0, 8, [DefenderAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([wall, _bear()], [])

	var decision: DeclareAttackersDecision = engine.pending_decision() as DeclareAttackersDecision

	assert_eq(decision.candidate_ids, [Scenario.permanent_named(engine, engine.hero().id, "Bear")])


func test_any_damage_from_deathtouch_is_lethal() -> void:
	var viper: MmCardDefinition = Scenario.creature("Viper", 1, 1, [DeathtouchAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Giant", 5, 5)], [viper])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	var viper_id: int = Scenario.permanent_named(engine, engine.villain().id, "Viper")
	Scenario.declare_attackers(engine, [giant])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[viper_id, giant]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_null(engine.game_state().object(giant), "CR 704.5h")
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.DESTROY)
	var dealt: Array[DamageEvent] = Scenario.combat_damage_events(engine)
	assert_true(dealt.any(func(damage: DamageEvent) -> bool: return damage.is_deathtouch))


func test_a_deathtouch_trampler_needs_to_assign_only_one_damage_to_each_blocker() -> void:
	var basilisk: MmCardDefinition = Scenario.creature("Basilisk", 3, 3, [DeathtouchAbility.new(), TrampleAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([basilisk], [Scenario.creature("Wall", 0, 4)])
	var basilisk_id: int = Scenario.permanent_named(engine, engine.hero().id, "Basilisk")
	var wall: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
	Scenario.declare_attackers(engine, [basilisk_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[wall, basilisk_id]])
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	var decision: DivideCombatDamageDecision = engine.pending_decision() as DivideCombatDamageDecision
	assert_eq(decision.lethal_amounts, [1], "CR 702.2c")
	assert_eq(engine.submit([1, 2]), "")

	assert_eq(engine.villain().life, 18)
	assert_null(engine.game_state().object(wall))


func test_ordinary_damage_below_toughness_is_not_lethal() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Giant", 5, 5)], [_bear()])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	Scenario.declare_attackers(engine, [giant])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[Scenario.permanent_named(engine, engine.villain().id, "Bear"), giant]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_not_null(engine.game_state().object(giant))
	assert_false(Scenario.combat_damage_events(engine).any(func(damage: DamageEvent) -> bool: return damage.is_deathtouch))


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _bird() -> MmCardDefinition:
	return Scenario.creature("Bird", 1, 1, [FlyingAbility.new()])


func _spider() -> MmCardDefinition:
	return Scenario.creature("Spider", 2, 4, [ReachAbility.new()])
