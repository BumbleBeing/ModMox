extends GutTest
## The Agent casts a spell for its alternative cost when that is what it can pay (CR 118.9,
## engine ADR 0093): the cast is one of the engine's legal actions, so it needs no rule of
## its own.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_djinn_is_cast_for_its_alternative_cost_when_its_mana_cost_is_out_of_reach() -> void:
	# Four Elves can't pay {4}{W}{W}; they pay {3}{W}, with the Lamp tapped.
	var lamp: MmCardDefinition = Scenario.artifact("Lamp", [])
	var engine: MmEngine = AiScenario.ready_with([Scenario.elf(), Scenario.elf(), Scenario.elf(), Scenario.elf(), lamp],
		[], [Scenario.djinn()])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var play: CastSpellAction = AiScenario.action_at(engine, AiScenario.ask(engine, agent)) as CastSpellAction

	assert_not_null(play)
	assert_eq(engine.game_state().characteristics_of(engine.game_state().object(play.object_id)).name, "Djinn")
	assert_true(play.is_for_alternative_cost)
