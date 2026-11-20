extends GutTest
## A permanent spell with flash takes the Timing Tag of its own "enters" trigger when that is
## removal or a trick (ADR 0065), so the Agent holds Leyline Binding for the moments it holds
## removal for, rather than casting it whenever it may.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const Tag := AiTiming.Tag


func test_a_flash_permanent_whose_enters_trigger_exiles_is_tagged_removal() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [_ogre()], [_flash(Scenario.free_binding("Binding")),
		Scenario.free_binding("Slow Binding"), _flash(_herald())])
	assert_not_null(engine)

	assert_eq(_tag_of_casting(engine, "Binding"), Tag.REMOVAL)
	assert_eq(_tag_of_casting(engine, "Slow Binding"), Tag.NONE, "Without flash it is cast as any permanent is.")
	assert_eq(_tag_of_casting(engine, "Herald"), Tag.NONE, "Gaining life is neither removal nor a trick.")


func test_it_is_held_in_its_own_beginning_of_combat() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [_ogre()], [_flash(Scenario.free_binding("Binding"))], [],
		Step.BEGINNING_OF_COMBAT)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, answer) is PassAction, "Not a moment removal is looked at.")
	assert_eq(agent.rollout_count(), 0)


func test_it_is_cast_at_the_opposing_creature_in_the_other_players_end_step() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [_ogre()], [_flash(Scenario.free_binding("Binding"))], [], Step.END)
	assert_not_null(engine)
	assert_eq(Scenario.play_until_step(engine, 4, Step.END), "")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, PriorityDecision), "")
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, answer), "Binding")


func _tag_of_casting(engine: MmEngine, card_name: String) -> Tag:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	var index: int = Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), card_name))
	assert_ne(index, -1, "%s may be cast." % card_name)
	return AiTiming.tag_of_action(engine.game_state(), decision.actions[index])


## [param definition] with flash in front of its abilities.
func _flash(definition: MmCardDefinition) -> MmCardDefinition:
	definition.abilities.push_front(FlashAbility.new())
	return definition


## A 1/1 creature costing {0}: "When this creature enters, you gain 2 life."
func _herald() -> MmCardDefinition:
	return Scenario.creature("Herald", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.gain_life(2, Scenario.you())])])


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)
