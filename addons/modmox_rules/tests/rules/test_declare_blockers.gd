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


func test_blocking_matches_only_creatures_that_are_blocking() -> void:
	# CR 509.1g: each creature declared as a blocker becomes a blocking creature.
	var engine: MmEngine = Scenario.combat_ready(_bears(1), _bears(2))
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var defenders: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	var context: MmEffectContext = MmEffectContext.new(engine.villain().id, defenders[0])
	var filter: IsBlockingFilter = IsBlockingFilter.new()
	Scenario.declare_attackers(engine, [attacker])
	Scenario.pass_to_blockers(engine)
	assert_false(filter.matches(engine.game_state(), MmReference.to_object(defenders[0]), context),
		"Nothing blocks before blockers are declared.")

	Scenario.declare_blockers(engine, [[defenders[0], attacker]])

	assert_true(filter.matches(engine.game_state(), MmReference.to_object(defenders[0]), context))
	assert_false(filter.matches(engine.game_state(), MmReference.to_object(defenders[1]), context))
	assert_false(filter.matches(engine.game_state(), MmReference.to_object(attacker), context), "An attacker is not blocking.")
	assert_false(filter.matches(engine.game_state(), MmReference.to_player(engine.villain().id), context))


func test_a_blocker_is_still_blocking_once_its_attacker_has_left() -> void:
	# CR 506.4: only being removed from combat stops a creature blocking.
	var engine: MmEngine = Scenario.combat_ready(_bears(1), _bears(1), [Scenario.exile_spell("Banish")])
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var blocker: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [attacker])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[blocker, attacker]])

	Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(attacker)])

	assert_true(_is_blocking(engine, blocker))


func test_a_regenerated_blocker_is_no_longer_blocking() -> void:
	# CR 701.19a: regenerating removes it from combat.
	var engine: MmEngine = Scenario.combat_ready(_bears(1), _bears(1), [],
		[Scenario.free_regenerate("Mend"), Scenario.free_destroy("Doom")])
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var blocker: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [attacker])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[blocker, attacker]])
	Scenario.pass_priority(engine)
	Scenario.cast_and_resolve(engine, "Mend", [MmReference.to_object(blocker)])
	Scenario.pass_priority(engine)

	Scenario.cast_and_resolve(engine, "Doom", [MmReference.to_object(blocker)])

	assert_not_null(engine.game_state().object(blocker))
	assert_false(_is_blocking(engine, blocker))


func test_nothing_is_blocking_once_combat_is_over() -> void:
	# CR 511.3: every creature is removed from combat.
	var engine: MmEngine = Scenario.combat_ready(_bears(1), _bears(1))
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var blocker: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [attacker])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[blocker, attacker]])

	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)

	assert_false(_is_blocking(engine, blocker))


func test_attacking_or_blocking_creatures_are_the_attackers_and_the_blockers() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(2), _bears(2), [Scenario.free_outflank("Outflank")])
	var attackers: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	var defenders: Array[int] = Scenario.permanents_named(engine, engine.villain().id, "Bear")
	var requirement: TargetRequirement = Scenario.target(Scenario.attacking_or_blocking_creature())
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, attackers[0])
	assert_eq(_target_ids(requirement, engine, context), [], "Nothing attacks or blocks yet.")
	Scenario.declare_attackers(engine, [attackers[0]])
	Scenario.pass_to_blockers(engine)

	Scenario.declare_blockers(engine, [[defenders[1], attackers[0]]])

	assert_eq(_target_ids(requirement, engine, context), [attackers[0], defenders[1]])


func test_outflank_deals_damage_equal_to_the_creatures_its_caster_controls() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(3), [Scenario.creature("Giant", 4, 4)],
		[Scenario.free_outflank("Outflank")])
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Giant")
	Scenario.declare_attackers(engine, [attacker])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[giant, attacker]])

	assert_eq(Scenario.cast_and_resolve(engine, "Outflank", [MmReference.to_object(giant)]), "")

	assert_eq(Scenario.damage_on(engine, giant), 3, "The Hero controls three Bears.")


## The IDs of what [param requirement] may target now, in ID order.
func _target_ids(requirement: TargetRequirement, engine: MmEngine, context: MmEffectContext) -> Array[int]:
	var ids: Array[int] = []
	for found: MmReference in requirement.legal_targets(engine.game_state(), context):
		ids.append(found.id)
	ids.sort()
	return ids


func _is_blocking(engine: MmEngine, object_id: int) -> bool:
	var context: MmEffectContext = MmEffectContext.new(engine.villain().id, object_id)
	return IsBlockingFilter.new().matches(engine.game_state(), MmReference.to_object(object_id), context)


func _bears(count: int) -> Array[MmCardDefinition]:
	return Scenario.copies(Scenario.creature("Bear", 2, 2), count)


func test_no_blockers_decision_when_every_attacker_has_left_combat() -> void:
	var exile: MmCardDefinition = Scenario.exile_spell("Banish")
	var engine: MmEngine = Scenario.combat_ready(_bears(1), _bears(1), [], [exile])
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [attacker])
	Scenario.pass_priority(engine)
	Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(attacker)])

	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision, "No attackers are left to block.")
	assert_eq(engine.game_state().step, Step.DECLARE_BLOCKERS)
