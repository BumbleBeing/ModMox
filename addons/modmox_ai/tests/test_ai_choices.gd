extends GutTest
## A choice made as a spell or ability resolves, "return a creature you control to its
## owner's hand" (CR 608.2d). A FULL Agent simulates each candidate, as it does a target; a
## CHEAP Agent takes its own least valuable permanent. Neither knows any card's name.
## Saying yes or no to a "you may" (CR 603.5): a CHEAP Agent does a harmful effect only to
## the other player's things; a FULL Agent simulates both answers with that as the default.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_a_full_agent_returns_the_lion_rather_than_its_angel() -> void:
	var engine: MmEngine = _choosing_with([AiScenario.free_alpha("serra_angel")])
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_eq(_chosen_name(engine, answer), "Lion", "A 2/2 back in hand costs less than a 4/4 flier.")
	assert_eq(easy.explain(), AiAgent.Reason.BEST_SCORE)


func test_a_cheap_agent_returns_its_least_valuable_creature() -> void:
	var engine: MmEngine = _choosing_with([AiScenario.free_alpha("serra_angel"), AiScenario.free_alpha("hill_giant")])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(_chosen_name(engine, answer), "Lion")
	assert_eq(engine.submit(answer), "")


func test_with_one_candidate_it_answers_at_once() -> void:
	var engine: MmEngine = _choosing_with([])
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	assert_eq(answer, 0)
	assert_eq(agent.explain(), AiAgent.Reason.ONLY_CHOICE)
	assert_eq(agent.rollout_count(), 0, "Nothing to compare, so nothing is simulated.")


func test_a_you_may_tap_is_aimed_at_an_opposing_creature_and_answered_yes() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal()),
			AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())]:
		var engine: MmEngine = _snarer_targeting([Scenario.creature("Scout", 2, 2)], [Scenario.creature("Wall", 0, 4)])
		var wall: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
		var aimed: int = AiScenario.ask(engine, agent)
		assert_eq(AiScenario.chosen_target(engine, aimed).id, wall, "Seen through the \"you may\": a tap is harmful.")
		assert_eq(engine.submit(aimed), "")
		assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseYesOrNoDecision), "")

		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(answer, ChooseYesOrNoDecision.Choice.YES)
		assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)
		assert_eq(engine.submit(answer), "")
		assert_true(engine.game_state().object(wall).is_tapped)


func test_with_only_its_own_creatures_to_target_it_answers_no() -> void:
	# CR 603.3d: the trigger must target a creature if there is one, though only its
	# controller's own are there; tapping one of them only keeps it from attacking.
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal())]:
		var no_creatures: Array[MmCardDefinition] = []
		var engine: MmEngine = _snarer_targeting([Scenario.creature("Scout", 2, 2)], no_creatures)
		assert_eq(engine.submit(AiScenario.ask(engine, agent)), "")
		assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseYesOrNoDecision), "")
		var target: int = (engine.game_state().object((engine.pending_decision() as ChooseYesOrNoDecision).stack_object_id)
			.targets[0] as MmReference).id

		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(answer, ChooseYesOrNoDecision.Choice.NO)
		assert_eq(engine.submit(answer), "")
		assert_false(engine.game_state().object(target).is_tapped)


## The Hero, with [param creatures] on the battlefield and the Villain's [param theirs]
## opposite, has cast Snarer ("When this creature enters, you may tap target creature."),
## and its trigger's target is asked.
func _snarer_targeting(creatures: Array[MmCardDefinition], theirs: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with(creatures, theirs, [Scenario.snarer()])
	assert_not_null(engine, "No seed gave the needed hand.")
	var card: int = Scenario.card_in_hand(engine, engine.hero(), "Snarer")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, card)), "")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseTargetDecision), "")
	return engine


## The Hero with [param creatures] on the battlefield has cast the Lion, and is choosing
## which creature its ability returns.
func _choosing_with(creatures: Array[MmCardDefinition]) -> MmEngine:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	var lion: MmCardDefinition = Scenario.creature("Lion", 2, 2, [Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.return_to_hand(Scenario.chosen(Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), yours])))])])
	var engine: MmEngine = AiScenario.ready_with(creatures, [], [lion])
	assert_not_null(engine, "No seed gave the needed hand.")
	Scenario.cast_and_resolve(engine, "Lion")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseObjectDecision), "")
	return engine


func _chosen_name(engine: MmEngine, answer: int) -> String:
	var chosen: MmReference = (engine.pending_decision() as ChooseObjectDecision).candidates[answer]
	return engine.game_state().characteristics_of(engine.game_state().object(chosen.id)).name
