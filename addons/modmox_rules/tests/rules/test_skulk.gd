extends GutTest
## Skulk (CR 702.118b): "A creature with skulk can't be blocked by creatures with greater
## power." A restriction on each blocker (CR 509.1b), as flying is, so it is asked as
## blockers are declared, with the powers they have then: a change of power afterward undoes
## no block.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_with_greater_power_cant_block_it() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.skulker()], [_bear()])
	Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Sneak")])

	Scenario.pass_until_step(engine, Step.DECLARE_BLOCKERS)

	assert_true(engine.pending_decision() is PriorityDecision, "The Bear's 2 power is greater than 1.")
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)
	assert_eq(engine.villain().life, 19)


func test_a_creature_with_the_same_power_or_less_can_block_it() -> void:
	var villain_creatures: Array[MmCardDefinition] = [Scenario.creature("Wall", 1, 3), Scenario.creature("Moth", 0, 4)]
	var engine: MmEngine = Scenario.combat_ready([Scenario.skulker()], villain_creatures)
	var sneak: int = Scenario.permanent_named(engine, engine.hero().id, "Sneak")
	var wall: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
	var moth: int = Scenario.permanent_named(engine, engine.villain().id, "Moth")
	Scenario.declare_attackers(engine, [sneak])

	assert_eq(Scenario.pass_to_blockers(engine), "")

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.blockable_by_blocker[wall], [sneak], "1 power is not greater than 1.")
	assert_eq(decision.blockable_by_blocker[moth], [sneak])
	assert_eq(Scenario.declare_blockers(engine, [[wall, sneak]]), "")


func test_a_blocker_with_greater_power_can_block_another_attacker_but_not_it() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.skulker(), _bear()], [Scenario.creature("Ogre", 3, 3)])
	var sneak: int = Scenario.permanent_named(engine, engine.hero().id, "Sneak")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [sneak, bear])
	Scenario.pass_to_blockers(engine)
	var before: String = engine.fingerprint()

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.blockable_by_blocker[ogre], [bear])
	assert_ne(engine.submit([[ogre, sneak]]), "")
	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.submit([[ogre, bear]]), "")


func test_its_power_is_read_as_blockers_are_declared() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.skulker()], [_bear()], [Scenario.pump_spell("Pump", 2, 0)])
	var sneak: int = Scenario.permanent_named(engine, engine.hero().id, "Sneak")
	var bear: int = Scenario.permanent_named(engine, engine.villain().id, "Bear")
	Scenario.declare_attackers(engine, [sneak])

	assert_eq(Scenario.cast_and_resolve(engine, "Pump", [MmReference.to_object(sneak)]), "")
	assert_eq(Scenario.pass_to_blockers(engine), "")

	var decision: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_eq(decision.blockable_by_blocker[bear], [sneak], "The Bear's 2 power is not greater than 3.")


func test_a_blocker_whose_power_grows_after_blocking_still_blocks() -> void:
	# CR 509.1b: a restriction is checked only as blockers are declared.
	var engine: MmEngine = Scenario.combat_ready([Scenario.skulker()], [Scenario.creature("Mite", 1, 1)],
		[Scenario.pump_spell("Pump", 2, 0)])
	var sneak: int = Scenario.permanent_named(engine, engine.hero().id, "Sneak")
	var mite: int = Scenario.permanent_named(engine, engine.villain().id, "Mite")
	Scenario.declare_attackers(engine, [sneak])
	Scenario.pass_to_blockers(engine)
	assert_eq(Scenario.declare_blockers(engine, [[mite, sneak]]), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Pump", [MmReference.to_object(mite)]), "")

	assert_eq(Scenario.pt(engine, mite), [3, 1])
	assert_eq(engine.game_state().combat.blockers_of(engine.game_state(), sneak), [mite])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)
