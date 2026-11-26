extends GutTest
## An ability whose cost sacrifices its source (CR 701.21a) is weighed as any other: its
## Timing Tag comes from its effects, and simulation sees the source gone.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_full_agent_sacrifices_its_artifact_to_kill_the_other_players_creature() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.parcel()], [Scenario.creature("Brute", 4, 4)])
	assert_not_null(engine, "No seed gave the needed board.")
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	var action: ActivateAbilityAction = AiScenario.action_at(engine, answer) as ActivateAbilityAction
	assert_not_null(action, "It activates rather than pass.")
	assert_eq(action.object_id, Scenario.permanent_named(engine, engine.hero().id, "Parcel"))


func test_a_creature_that_sacrifices_itself_deals_its_power_to_kill_a_better_creature() -> void:
	# Heartfire Immolator's "It deals damage equal to its power" (engine ADR 0098's addendum):
	# its 2 power kills the 2/2 flier with lifelink, worth more than an Immolator. Its main
	# phase casts the free Immolators in its hand first.
	var engine: MmEngine = AiScenario.ready_with([Scenario.immolator()], [_angel()])
	assert_not_null(engine, "No seed gave the needed board.")
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	for _answer: int in 48:
		var decision: MmPendingDecision = engine.pending_decision()
		if engine.game_state().step != MmTurn.Step.PRECOMBAT_MAIN or decision == null:
			break
		assert_eq(AiScenario.let_answer(engine, easy) if decision.player_id == engine.hero().id
			else engine.submit(Scenario.default_answer(decision)), "")

	assert_eq(Scenario.permanent_named(engine, engine.villain().id, "Angel"), -1, "An Immolator's power killed it.")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Immolator"), -1, "It sacrificed itself.")


func test_a_sacrifice_for_damage_is_removal() -> void:
	var parcel: ActivatedAbility = Scenario.parcel().abilities[0] as ActivatedAbility

	assert_eq(AiTiming.tag_of_effects(parcel.effects), AiTiming.Tag.REMOVAL)


## A 2/2 costing {0} with flying and lifelink.
func _angel() -> MmCardDefinition:
	return Scenario.creature("Angel", 2, 2, [FlyingAbility.new(), LifelinkAbility.new()])
