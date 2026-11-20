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


func test_a_sacrifice_for_damage_is_removal() -> void:
	var parcel: ActivatedAbility = Scenario.parcel().abilities[0] as ActivatedAbility

	assert_eq(AiTiming.tag_of_effects(parcel.effects), AiTiming.Tag.REMOVAL)
