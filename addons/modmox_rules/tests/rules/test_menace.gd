extends GutTest
## Menace (CR 702.111b): a creature with menace can't be blocked except by two or more
## creatures. It restricts the whole declaration, so it is checked once every block is
## made (CR 509.1b), never blocker by blocker as flying is.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_menace_attacker_blocked_by_one_creature_is_refused_and_changes_nothing() -> void:
	var engine: MmEngine = Scenario.combat_ready([_brute()], _bears(2))
	var brute: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	var bears: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [brute])
	Scenario.pass_to_blockers(engine)
	var before: String = engine.fingerprint()

	assert_ne(engine.submit([[bears[0], brute]]), "")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is DeclareBlockersDecision)


func test_the_blockers_decision_says_a_menace_attacker_needs_two_blockers() -> void:
	var engine: MmEngine = Scenario.combat_ready([_brute(), _bear()], _bears(2))
	var brute: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [brute, bear])

	Scenario.pass_to_blockers(engine)

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.least_blockers_of(brute), 2)
	assert_eq(decision.least_blockers_of(bear), 1)


func test_a_menace_attacker_may_be_blocked_by_two_creatures_and_divides_its_damage() -> void:
	var engine: MmEngine = Scenario.combat_ready([_brute()], _bears(2))
	var brute: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	var bears: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [brute])
	Scenario.pass_to_blockers(engine)

	assert_eq(Scenario.declare_blockers(engine, [[bears[0], brute], [bears[1], brute]]), "")
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_eq(engine.game_state().combat.blockers_of(engine.game_state(), brute), bears)
	assert_true(engine.pending_decision() is DivideCombatDamageDecision, "CR 510.1c: two blockers to divide among.")


func test_an_unblocked_menace_attacker_deals_its_damage_to_the_player() -> void:
	var engine: MmEngine = Scenario.combat_ready([_brute()], _bears(2))
	var brute: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	Scenario.declare_attackers(engine, [brute])
	Scenario.pass_to_blockers(engine)

	assert_eq(Scenario.declare_blockers(engine, []), "")
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 17)


func test_a_lone_blocker_can_block_another_attacker_but_not_the_menace_one() -> void:
	var engine: MmEngine = Scenario.combat_ready([_brute(), _bear()], _bears(1))
	var brute: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	var attacking_bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var blocker: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [brute, attacking_bear])
	Scenario.pass_to_blockers(engine)

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.candidate_blocker_ids, [blocker])
	assert_ne(engine.submit([[blocker, brute]]), "")
	assert_eq(engine.submit([[blocker, attacking_bear]]), "")


func test_a_creature_blocking_two_attackers_is_still_one_blocker_of_the_menace_one() -> void:
	var sentinel: MmCardDefinition = Scenario.creature("Sentinel", 2, 4, [_one_more_block()])
	var engine: MmEngine = Scenario.combat_ready([_brute(), _bear()], [sentinel])
	var brute: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var sentinel_id: int = Scenario.permanent_named(engine, engine.villain().id, "Sentinel")
	Scenario.declare_attackers(engine, [brute, bear])
	Scenario.pass_to_blockers(engine)

	assert_ne(engine.submit([[sentinel_id, brute], [sentinel_id, bear]]), "")
	assert_eq(engine.submit([[sentinel_id, bear]]), "")


func test_a_menace_deathtoucher_blocked_by_two_needs_assign_only_one_damage_to_each() -> void:
	var stalker: MmCardDefinition = Scenario.creature("Stalker", 2, 2, [MenaceAbility.new(), DeathtouchAbility.new()])
	var giant: MmCardDefinition = Scenario.creature("Giant", 3, 3)
	var engine: MmEngine = Scenario.combat_ready([stalker], [giant, giant])
	var stalker_id: int = Scenario.permanent_named(engine, engine.hero().id, "Stalker")
	var giants: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Giant")
	Scenario.declare_attackers(engine, [stalker_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[giants[0], stalker_id], [giants[1], stalker_id]])
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	var decision: DivideCombatDamageDecision = engine.pending_decision() as DivideCombatDamageDecision
	assert_eq(decision.lethal_amounts, [1, 1], "CR 702.2c")
	assert_eq(engine.submit([1, 1]), "")

	assert_null(engine.game_state().object(giants[0]))
	assert_null(engine.game_state().object(giants[1]))


## A 3/3 with menace.
func _brute() -> MmCardDefinition:
	return Scenario.creature("Brute", 3, 3, [MenaceAbility.new()])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _bears(count: int) -> Array[MmCardDefinition]:
	var bears: Array[MmCardDefinition] = []
	for index: int in count:
		bears.append(_bear())
	return bears


func _one_more_block() -> BlockAdditionalAbility:
	var more: BlockAdditionalAbility = BlockAdditionalAbility.new()
	more.count = 1
	return more
