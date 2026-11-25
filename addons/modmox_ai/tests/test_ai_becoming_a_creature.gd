extends GutTest
## The Agent and Bring to Life's "Target noncreature artifact you control becomes a 0/0
## artifact creature. Put four +1/+1 counters on it." (engine ADR 0091): an effect with no
## duration is no trick, so its Timing Tag is none and it is cast as a sorcery is, when the
## simulation says the 4/4 is worth more than the artifact was.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_an_effect_with_no_duration_is_no_trick() -> void:
	var animate: SpellAbility = Scenario.free_animate().abilities[0] as SpellAbility

	assert_eq(AiTiming.tag_of_effects(animate.effects), AiTiming.Tag.NONE)


func test_it_makes_a_four_four_of_its_own_artifact() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()), AiAgent.new()]:
		var trinket: MmCardDefinition = Scenario.artifact("Trinket", [])
		var engine: MmEngine = AiScenario.ready_with([trinket], [], [Scenario.free_animate()])
		assert_not_null(engine)

		var play: int = AiScenario.ask(engine, agent)

		assert_eq(AiScenario.cast_name(engine, play), "Animate")
