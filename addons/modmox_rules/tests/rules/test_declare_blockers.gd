extends GutTest
## CR 509.1: the defending player declares blockers with their untapped creatures, each
## blocking one attacker. CR 509.1h: an attacker with blockers becomes blocked.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_blockers_decision_offers_the_defenders_untapped_creatures_and_the_attackers() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(2), _bears(2))
	var attackers: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	var blockers: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [attackers[0]])

	assert_eq(Scenario.pass_to_blockers(engine), "")

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.player_id, engine.villain().id)
	assert_eq(decision.candidate_blocker_ids, blockers)
	assert_eq(decision.attacker_ids, [attackers[0]])
	assert_eq(engine.game_state().step, Step.DECLARE_BLOCKERS)


func test_declaring_blockers_records_the_blocks_and_the_blocked_attacker() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(2), _bears(1))
	var attackers: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	var blocker: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, attackers)
	Scenario.pass_to_blockers(engine)

	assert_eq(Scenario.declare_blockers(engine, [[blocker, attackers[1]]]), "")

	var combat: MmCombat = engine.game_state().combat
	assert_true(combat.is_blocked(attackers[1]))
	assert_false(combat.is_blocked(attackers[0]))
	assert_eq(combat.blockers_of(engine.game_state(), attackers[1]), [blocker])
	assert_eq(combat.attackers_blocked_by(engine.game_state(), blocker), [attackers[1]])
	assert_false(engine.game_state().object(blocker).is_tapped, "Blocking does not tap.")
	assert_eq((engine.pending_decision() as PriorityDecision).player_id, engine.hero().id,
		"CR 509.4: the active player then gets priority.")


func test_several_creatures_may_block_one_attacker() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(1), _bears(2))
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var blockers: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [attacker])
	Scenario.pass_to_blockers(engine)

	assert_eq(Scenario.declare_blockers(engine, [[blockers[1], attacker], [blockers[0], attacker]]), "")

	assert_eq(engine.game_state().combat.blockers_of(engine.game_state(), attacker), blockers, "In ID order.")


func test_illegal_blocks_are_rejected_and_change_nothing() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(2), _bears(1))
	var attackers: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	var blocker: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [attackers[0]])
	Scenario.pass_to_blockers(engine)
	var before: String = engine.fingerprint()

	assert_ne(engine.submit([[attackers[1], attackers[0]]]), "", "Not the defender's creature.")
	assert_ne(engine.submit([[blocker, attackers[1]]]), "", "That creature is not attacking.")
	assert_ne(engine.submit([[blocker, attackers[0]], [blocker, attackers[0]]]), "", "The same blocker twice.")
	assert_ne(engine.submit([[blocker]]), "", "Not a pair.")
	assert_ne(engine.submit([blocker, attackers[0]]), "", "Not a list of pairs.")
	assert_ne(engine.submit(blocker), "", "Not a list.")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is DeclareBlockersDecision)


func test_a_tapped_creature_cannot_block() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(1), _bears(1))
	var heros_bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var villains_bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [heros_bear])
	Scenario.play_until_step(engine, 4, Step.DECLARE_ATTACKERS)
	assert_true(engine.game_state().object(heros_bear).is_tapped, "Still tapped from attacking.")
	Scenario.declare_attackers(engine, [villains_bear])

	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision, "Nothing could block, so nobody is asked.")


func test_no_blockers_decision_when_the_defender_has_no_untapped_creatures() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(1), [])
	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Bear"))

	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision)


func _bears(count: int) -> Array[MmCardDefinition]:
	return Scenario.copies(Scenario.creature("Bear", 2, 2), count)
