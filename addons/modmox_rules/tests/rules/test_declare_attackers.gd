extends GutTest
## CR 508.1: the active player declares attackers, which taps them (CR 508.1f). CR 508.8:
## without attackers, the declare blockers and combat damage steps are skipped.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_attackers_decision_offers_each_untapped_creature_that_is_not_summoning_sick() -> void:
	var elf: MmCardDefinition = Scenario.creature("Elf", 1, 1, [Scenario.tap_for_mana(MmMana.Type.GREEN, 1)])
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(
		Scenario.copies(elf, 40), Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Elf")
	Scenario.cast_and_resolve(engine, "Elf")
	var elves: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Elf")
	Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, elves[0]))
	Scenario.cast_and_resolve(engine, "Elf")

	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)

	var decision: DeclareAttackersDecision = engine.pending_decision() as DeclareAttackersDecision
	assert_not_null(decision)
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.candidate_ids, [elves[1]], "Not the tapped Elf, nor the one cast this turn.")


func test_declaring_attackers_taps_them_and_records_the_declaration() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(2), [])
	var bears: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.declare_attackers(engine, [bears[1]]), "")

	var combat: MmCombat = engine.game_state().combat
	assert_true(combat.is_attacking(bears[1]))
	assert_false(combat.is_attacking(bears[0]))
	assert_eq(combat.defending_player_id, engine.villain().id)
	assert_true(engine.game_state().object(bears[1]).is_tapped)
	assert_false(engine.game_state().object(bears[0]).is_tapped)
	var declared: AttackersDeclaredEvent = _first_event_of(engine, AttackersDeclaredEvent) as AttackersDeclaredEvent
	assert_not_null(declared)
	assert_eq(declared.attacker_ids, [bears[1]])
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(decision.player_id, engine.hero().id, "CR 508.2: the active player then gets priority.")
	assert_eq(engine.game_state().step, Step.DECLARE_ATTACKERS)


func test_declaring_no_attackers_skips_the_blockers_and_damage_steps() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(1), [])

	Scenario.declare_attackers(engine, [])
	Scenario.play_until_game_turn(engine, 4)

	var steps: Array = Scenario.steps_by_game_turn(engine)[3]
	assert_false(steps.has(Step.DECLARE_BLOCKERS))
	assert_false(steps.has(Step.COMBAT_DAMAGE))
	assert_true(steps.has(Step.END_OF_COMBAT))


func test_attacking_leads_to_the_blockers_and_damage_steps() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(1), [])

	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Bear"))
	Scenario.play_until_game_turn(engine, 4)

	var steps: Array = Scenario.steps_by_game_turn(engine)[3]
	assert_true(steps.has(Step.DECLARE_BLOCKERS))
	assert_true(steps.has(Step.COMBAT_DAMAGE))


func test_illegal_attackers_are_rejected_and_change_nothing() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(1), _bears(1))
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var villains_bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	var before: String = engine.fingerprint()

	assert_ne(engine.submit([villains_bear]), "", "Not the attacker's creature.")
	assert_ne(engine.submit([bear, bear]), "", "The same creature twice.")
	assert_ne(engine.submit(bear), "", "Not a list.")
	assert_ne(engine.submit(["bear"]), "", "Not an ID.")

	assert_eq(engine.fingerprint(), before)
	assert_true(engine.pending_decision() is DeclareAttackersDecision)


func test_the_combat_is_over_after_the_end_of_combat_step() -> void:
	var engine: MmEngine = Scenario.combat_ready(_bears(1), [])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [bear])

	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)

	assert_false(engine.game_state().combat.is_attacking(bear), "CR 511.3: removed from combat.")
	assert_not_null(_first_event_of(engine, CombatEndedEvent))


func _bears(count: int) -> Array[MmCardDefinition]:
	return Scenario.copies(Scenario.creature("Bear", 2, 2), count)


func _first_event_of(engine: MmEngine, kind: Script) -> MmEvent:
	for event: MmEvent in engine.event_log():
		if is_instance_of(event, kind):
			return event
	return null
