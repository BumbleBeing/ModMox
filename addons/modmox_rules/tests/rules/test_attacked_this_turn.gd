extends GutTest
## The condition "if you attacked this turn", raid's (engine ADR 0095's addendum): true
## while its controller declared one or more attackers this turn (CR 508.1). Skullhunter is
## a 2/1 costing {0} with "When this creature enters, if you attacked this turn, you gain 1
## life."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_cast_after_attacking_its_enters_ability_gains_life() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var engine: MmEngine = Scenario.combat_ready([bear], [], [Scenario.skullhunter()])
	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Bear")]), "")
	assert_eq(Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN), "")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Skullhunter"), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 1)


func test_cast_before_combat_it_does_not_trigger() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup([bear], [], [Scenario.skullhunter()], []),
		[bear], [], [Scenario.skullhunter()], [], 3, Step.PRECOMBAT_MAIN)
	var triggered_before: int = Scenario.events_of(engine, AbilityTriggeredEvent).size()
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Skullhunter"), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life)
	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), triggered_before,
		"CR 603.4: the condition is false as it enters, so it never triggers.")


func test_declaring_no_attackers_is_not_attacking() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var engine: MmEngine = Scenario.combat_ready([bear], [], [Scenario.skullhunter()])
	assert_eq(Scenario.declare_attackers(engine, []), "")
	assert_eq(Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN), "")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Skullhunter"), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life)


func test_the_other_player_attacking_is_not_you_attacking() -> void:
	var bear: MmCardDefinition = Scenario.creature("Their Bear", 2, 2)
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup([], [bear], [], []), [], [bear], [], [],
		4, Step.DECLARE_ATTACKERS)

	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.villain().id, "Their Bear")]), "")

	var condition: AttackedThisTurnCondition = Scenario.attacked_this_turn()
	var state: MmGameState = engine.game_state()
	assert_true(condition.is_true(state, MmEffectContext.new(engine.villain().id, 0)), "The Villain attacked.")
	assert_false(condition.is_true(state, MmEffectContext.new(engine.hero().id, 0)), "The Hero did not.")


func test_a_new_turn_forgets_the_attack() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var engine: MmEngine = Scenario.combat_ready([bear], [])
	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Bear")]), "")
	assert_true(engine.game_state().player(engine.hero().id).has_attacked_this_turn)

	assert_eq(Scenario.play_until_step(engine, 4, Step.UPKEEP), "")

	assert_false(engine.game_state().player(engine.hero().id).has_attacked_this_turn)


func test_a_copy_of_the_game_state_keeps_the_attack() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var engine: MmEngine = Scenario.combat_ready([bear], [], [])
	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Bear")]), "")

	var copy: MmGameState = engine.game_state().duplicate_state()

	assert_true(copy.player(engine.hero().id).has_attacked_this_turn)
