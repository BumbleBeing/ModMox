extends GutTest
## A creature whose "enters" ability works only if an opponent lost life this turn, as Bat
## Whisperer's does (engine ADR 0082's second addendum), is held for its controller's
## postcombat main phase (Timing Tag AFTER_ATTACKING), when an attack has had its chance to
## make them lose it. Whisperer is a 4/2 costing {0}: "When this creature enters, if an
## opponent lost life this turn, you gain 1 life."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const Tag := AiTiming.Tag


func test_casting_it_is_tagged_after_attacking() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [], [Scenario.whisperer()])
	assert_not_null(engine)
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	var index: int = Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), "Whisperer"))

	assert_ne(index, -1)
	if index != -1:
		assert_eq(AiTiming.tag_of_action(engine.game_state(), decision.actions[index]), Tag.AFTER_ATTACKING)


func test_your_own_life_lost_is_not_a_reason_to_wait() -> void:
	var own: MmCardDefinition = Scenario.creature("Mourner", 4, 2, [Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.gain_life(1, Scenario.you())], [], Scenario.lost_life_this_turn(MmTrigger.Whose.YOU))])
	var engine: MmEngine = AiScenario.ready_with([], [], [own])
	assert_not_null(engine)
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision

	var index: int = Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), "Mourner"))

	assert_ne(index, -1)
	if index != -1:
		assert_ne(AiTiming.tag_of_action(engine.game_state(), decision.actions[index]), Tag.AFTER_ATTACKING)


func test_it_waits_in_the_precombat_main_phase() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2)], [], [Scenario.whisperer()])
	assert_not_null(engine)

	var answer: int = AiScenario.ask(engine, AiAgent.new())

	assert_ne(AiScenario.cast_name(engine, answer), "Whisperer", "Cast now, its enters ability would do nothing.")


func test_it_is_cast_in_the_postcombat_main_phase_after_an_attack_deals_damage() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2)], [], [Scenario.whisperer()],
		[], Step.DECLARE_ATTACKERS)
	assert_not_null(engine)
	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Bear")]), "")
	assert_eq(Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN), "")
	assert_gt(engine.villain().life_lost_this_turn, 0, "The Bear's damage made the Villain lose life.")
	var life: int = engine.hero().life

	var agent: AiAgent = AiAgent.new()

	for _answer: int in 12:
		var decision: MmPendingDecision = engine.pending_decision()
		if engine.game_state().step != Step.POSTCOMBAT_MAIN or decision == null:
			break
		assert_eq(AiScenario.let_answer(engine, agent) if decision.player_id == engine.hero().id
			else engine.submit(Scenario.default_answer(decision)), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Whisperer"), -1,
		"Its postcombat main phase cast it.")
	assert_gt(engine.hero().life, life, "Its enters ability resolved; the hand may hold more than one.")
