extends GutTest
## The Agent casts a spell with improvise (engine ADR 0099): the engine offers its cast once
## its artifacts can help pay, so the Agent needs no rule of its own to choose it, and the
## payment planner taps an artifact that loses nothing by it before a creature that could
## block.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const B: MmMana.Type = MmMana.Type.BLACK


func test_a_creature_with_improvise_is_cast_with_two_artifacts_helping_pay_and_a_bird_left_to_block() -> void:
	var scrapper: MmCardDefinition = Scenario.creature("Scrapper", 4, 4, [ImproviseAbility.new()], Scenario.mana_cost(4, [B]))
	var permanents: Array[MmCardDefinition] = [_bird(), _bird(), _bird(), _bird(),
		Scenario.artifact("Trinket", []), Scenario.artifact("Bauble", [])]
	var engine: MmEngine = AiScenario.ready_with(permanents, [], [scrapper])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Scrapper", "Four Birds alone make only four of its five mana.")
	assert_eq(engine.submit(play), "")
	while engine.pending_decision() is PayManaDecision:
		assert_eq(engine.submit(AiScenario.ask(engine, agent)), "")
	assert_true(engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Trinket")).is_tapped)
	assert_true(engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Bauble")).is_tapped)
	var untapped: int = 0
	for bird: int in Scenario.permanents_named(engine, engine.hero().id, "Bird"):
		if not engine.game_state().object(bird).is_tapped:
			untapped += 1
	assert_eq(untapped, 1, "The artifacts paid before the creatures did.")


## A 0/1 creature that taps for {B}.
func _bird() -> MmCardDefinition:
	return Scenario.creature("Bird", 0, 1, [Scenario.tap_for_mana(B, 1)])
