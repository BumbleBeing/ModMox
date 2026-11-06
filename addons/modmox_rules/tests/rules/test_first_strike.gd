extends GutTest
## CR 510.4: with a first or double striker in combat there are two combat damage steps.
## CR 702.7: first strike deals damage in the first. CR 702.4: double strike in both.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_first_striker_deals_its_damage_in_an_earlier_combat_damage_step() -> void:
	var engine: MmEngine = Scenario.combat_ready([_archer()], [_goblin()])
	var archer: int = Scenario.permanent_named(engine, engine.hero().id, "Archer")
	var goblin: int = Scenario.permanent_named(engine, engine.villain().id, "Goblin")
	Scenario.declare_attackers(engine, [archer])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[goblin, archer]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_true(engine.game_state().combat.is_first_strike_damage_step)
	assert_eq(Scenario.damage_on(engine, goblin), 1)
	assert_eq(Scenario.damage_on(engine, archer), 0, "The Goblin has not dealt its damage yet.")
	assert_eq((engine.pending_decision() as PriorityDecision).player_id, engine.hero().id,
		"Players get priority between the two damage steps.")

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_eq(engine.game_state().step, Step.COMBAT_DAMAGE)
	assert_false(engine.game_state().combat.is_first_strike_damage_step)
	assert_eq(Scenario.damage_on(engine, archer), 1)
	assert_eq(Scenario.damage_on(engine, goblin), 1, "CR 702.7c: the first striker does not deal damage again.")
	Scenario.play_until_game_turn(engine, 4)
	assert_eq(Scenario.steps_by_game_turn(engine)[3].count(Step.COMBAT_DAMAGE), 2)


func test_a_blocking_first_striker_also_strikes_first() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_archer()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var archer: int = Scenario.permanent_named(engine, engine.villain().id, "Archer")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[archer, bear]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	assert_eq(Scenario.damage_on(engine, bear), 1)
	assert_eq(Scenario.damage_on(engine, archer), 0)
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	assert_eq(Scenario.names(engine, engine.villain().graveyard), ["Archer"], "The Bear's 2 damage killed it.")


func test_without_a_first_striker_there_is_one_combat_damage_step() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear()], [_goblin()])
	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Bear"))

	Scenario.play_until_game_turn(engine, 4)

	assert_eq(Scenario.steps_by_game_turn(engine)[3].count(Step.COMBAT_DAMAGE), 1)


func test_an_unblocked_double_striker_deals_damage_in_both_steps() -> void:
	var engine: MmEngine = Scenario.combat_ready([_duelist()], [])
	var duelist: int = Scenario.permanent_named(engine, engine.hero().id, "Duelist")
	Scenario.declare_attackers(engine, [duelist])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	assert_eq(engine.villain().life, 18)
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(engine.villain().life, 16)
	assert_eq(Scenario.combat_damage_events(engine).size(), 2)


func test_a_blocked_double_striker_damages_its_blocker_in_both_steps() -> void:
	var engine: MmEngine = Scenario.combat_ready([_duelist()], [Scenario.creature("Wall", 1, 5)])
	var duelist: int = Scenario.permanent_named(engine, engine.hero().id, "Duelist")
	var wall: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
	Scenario.declare_attackers(engine, [duelist])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[wall, duelist]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	assert_eq(Scenario.damage_on(engine, wall), 2)
	assert_eq(Scenario.damage_on(engine, duelist), 0)
	Scenario.pass_until_step(engine, Step.END_OF_COMBAT)

	assert_eq(Scenario.damage_on(engine, wall), 4)
	assert_eq(Scenario.damage_on(engine, duelist), 1, "The Wall deals its damage once, in the second step.")


func test_a_double_striker_with_trample_reaches_the_player_in_the_second_step() -> void:
	var brute: MmCardDefinition = Scenario.creature("Brute", 3, 3, [DoubleStrikeAbility.new(), TrampleAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([brute], [Scenario.creature("Wall", 0, 5)])
	var brute_id: int = Scenario.permanent_named(engine, engine.hero().id, "Brute")
	var wall: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
	Scenario.declare_attackers(engine, [brute_id])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[wall, brute_id]])
	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)
	assert_eq(Scenario.damage_on(engine, wall), 3, "3 is not lethal to a 0/5, so there was nothing to divide.")
	assert_eq(engine.villain().life, 20)

	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)

	assert_true(engine.pending_decision() is DivideCombatDamageDecision)
	assert_ne(engine.submit([1, 2]), "", "2 more damage is lethal to the Wall now.")
	assert_eq(engine.submit([2, 1]), "")
	assert_eq(engine.villain().life, 19)


func _archer() -> MmCardDefinition:
	return Scenario.creature("Archer", 1, 2, [FirstStrikeAbility.new()])


func _duelist() -> MmCardDefinition:
	return Scenario.creature("Duelist", 2, 2, [DoubleStrikeAbility.new()])


## A 1/3, so it survives a first strike and strikes back.
func _goblin() -> MmCardDefinition:
	return Scenario.creature("Goblin", 1, 3)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)
