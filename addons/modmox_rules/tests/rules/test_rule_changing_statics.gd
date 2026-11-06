extends GutTest
## Static abilities that change rules rather than characteristics: blocking additional
## creatures (CR 509.1a, damage divided per CR 510.1d), damage that stays through cleanup
## (CR 514.2), and additional land plays (CR 305.2).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_creature_may_block_an_additional_attacker() -> void:
	var engine: MmEngine = _two_bears_into_a_guard(1)
	var bears: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	var guard: int = Scenario.permanent_named(engine, engine.villain().id, "Guard")

	assert_ne(engine.submit([[guard, bears[0]], [guard, bears[0]]]), "", "Not the same attacker twice.")
	assert_eq(engine.submit([[guard, bears[0]], [guard, bears[1]]]), "")

	assert_eq(engine.game_state().combat.attackers_blocked_by(engine.game_state(), guard), bears)


func test_blocking_more_attackers_than_allowed_is_rejected() -> void:
	var engine: MmEngine = _three_bears_into_a_guard(1)
	var bears: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	var guard: int = Scenario.permanent_named(engine, engine.villain().id, "Guard")

	assert_ne(engine.submit([[guard, bears[0]], [guard, bears[1]], [guard, bears[2]]]), "")


func test_an_ordinary_creature_blocks_only_one_attacker() -> void:
	var engine: MmEngine = _two_bears_into_a_guard(0)
	var bears: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	var guard: int = Scenario.permanent_named(engine, engine.villain().id, "Guard")

	assert_ne(engine.submit([[guard, bears[0]], [guard, bears[1]]]), "")


func test_the_defending_player_divides_the_damage_of_a_creature_blocking_two_attackers() -> void:
	var engine: MmEngine = _two_bears_into_a_guard(1)
	var bears: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	var guard: int = Scenario.permanent_named(engine, engine.villain().id, "Guard")
	engine.submit([[guard, bears[0]], [guard, bears[1]]])

	Scenario.pass_until_step(engine, Step.COMBAT_DAMAGE)

	var decision: DivideCombatDamageDecision = engine.pending_decision() as DivideCombatDamageDecision
	assert_not_null(decision)
	assert_eq(decision.player_id, engine.villain().id)
	assert_eq(decision.source_id, guard)
	assert_false(decision.includes_player())
	assert_eq(engine.submit([0, 3]), "")
	assert_eq(Scenario.damage_on(engine, bears[0]), 0)
	assert_null(engine.game_state().object(bears[1]), "3 damage killed it.")
	assert_eq(Scenario.damage_on(engine, guard), 4, "Both Bears dealt their damage.")


func test_damage_stays_on_a_creature_that_keeps_it() -> void:
	var stubborn: MmCardDefinition = Scenario.creature("Stubborn", 1, 5, [DamageStaysAbility.new()])
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bear", 2, 2)], [stubborn])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var stubborn_id: int = Scenario.permanent_named(engine, engine.villain().id, "Stubborn")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_to_blockers(engine)
	Scenario.declare_blockers(engine, [[stubborn_id, bear]])

	Scenario.play_until_game_turn(engine, 4)

	assert_eq(Scenario.damage_on(engine, stubborn_id), 2)
	assert_eq(Scenario.damage_on(engine, bear), 0)


func test_an_emblem_granting_an_additional_land_play_allows_two_lands_on_your_turns() -> void:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var setup: MmEncounterSetup = Scenario.setup_with(forests, forests.duplicate())
	var extra: AdditionalLandPlaysAbility = AdditionalLandPlaysAbility.new()
	extra.count = 1
	setup.hero.emblems = [Scenario.emblem("Explorer", [extra])]
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	assert_ne(Scenario.play_first_land(engine), -1)
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_eq(Scenario.play_first_land(engine), -1, "Only one additional land.")
	Scenario.play_until_step(engine, 2, Step.PRECOMBAT_MAIN)
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_eq(Scenario.play_first_land(engine), -1, "The Villain has no Emblem.")


func _guard(additional: int) -> MmCardDefinition:
	var abilities: Array[MmAbility] = []
	if additional > 0:
		var more: BlockAdditionalAbility = BlockAdditionalAbility.new()
		more.count = additional
		abilities.append(more)
	return Scenario.creature("Guard", 3, 6, abilities)


func _two_bears_into_a_guard(additional: int) -> MmEngine:
	return _bears_into_a_guard(2, additional)


func _three_bears_into_a_guard(additional: int) -> MmEngine:
	return _bears_into_a_guard(3, additional)


func _bears_into_a_guard(bear_count: int, additional: int) -> MmEngine:
	var bears: Array[MmCardDefinition] = Scenario.copies(Scenario.creature("Bear", 2, 2), bear_count)
	var engine: MmEngine = Scenario.combat_ready(bears, [_guard(additional)])
	assert_not_null(engine, "No seed gave the needed hands.")
	Scenario.declare_attackers(engine, Scenario.permanents_named(engine, engine.hero().id, "Bear"))
	Scenario.pass_to_blockers(engine)
	return engine
