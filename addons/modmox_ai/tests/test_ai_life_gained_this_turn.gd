extends GutTest
## A creature that enters with a counter for each life its controller gained this turn, as
## Voracious Wurm does (engine ADR 0082's fourth addendum), is worth more once life has been
## gained, so a play that gains life is made first: the follow-up plan weighs each other play
## before it (AiAgent._plan_follow_ups()). Wurm is a 2/2 costing {0}: "This creature enters
## with X +1/+1 counters on it, where X is the amount of life you've gained this turn." Feast
## is a sorcery costing {0}: "You gain 3 life." The hand holds every copy the cycled deck
## dealt, so each Wurm is checked against all the life gained.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


func test_after_gaining_life_its_turn_casts_the_wurms_with_the_counters() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [], [_feast(), Scenario.wurm()])
	assert_not_null(engine)
	assert_eq(Scenario.cast_and_resolve(engine, "Feast"), "")

	_let_the_turn_play(engine)

	_assert_each_wurm_has_all_the_life_gained(engine)


func test_it_gains_the_life_before_it_casts_a_wurm() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [], [_feast(), Scenario.wurm()])
	assert_not_null(engine)

	_let_the_turn_play(engine)

	_assert_each_wurm_has_all_the_life_gained(engine)


func _assert_each_wurm_has_all_the_life_gained(engine: MmEngine) -> void:
	var wurms: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Wurm")
	var gained: int = engine.hero().life_gained_this_turn
	assert_false(wurms.is_empty(), "Its turn cast the Wurms.")
	assert_gt(gained, 0, "Its turn cast the Feasts.")
	for wurm: int in wurms:
		assert_eq(Scenario.counters_on(engine, wurm, MmCounter.Kind.PLUS_ONE_PLUS_ONE), gained,
			"Cast before a Feast, a Wurm would have entered with fewer.")


## The Agent answers for the Hero, and the default answers for the Villain, until the
## Hero's end step.
func _let_the_turn_play(engine: MmEngine) -> void:
	var agent: AiAgent = AiAgent.new()
	for _answer: int in 40:
		var decision: MmPendingDecision = engine.pending_decision()
		if decision == null or engine.game_state().step == Step.END:
			break
		assert_eq(AiScenario.let_answer(engine, agent) if decision.player_id == engine.hero().id
			else engine.submit(Scenario.default_answer(decision)), "")


func _feast() -> MmCardDefinition:
	return Scenario.sorcery("Feast", Scenario.mana_cost(0), [], [Scenario.gain_life(3, Scenario.you())])
