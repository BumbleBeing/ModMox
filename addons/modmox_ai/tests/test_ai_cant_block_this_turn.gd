extends GutTest
## The Agent and Arena Athlete's Heroic, "Whenever you cast a spell that targets this
## creature, target creature an opponent controls can't block this turn." (CR 509.1a): it is
## aimed as a tap is, at the other player's creature worth most among those that could block.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_the_trigger_keeps_the_opposing_creature_worth_most_from_blocking() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()),
			AiAgent.new()]:
		var engine: MmEngine = AiScenario.ready_with([_athlete()],
			[Scenario.creature("Ogre", 4, 4), Scenario.creature("Squire", 1, 1)], [_pump()])
		assert_not_null(engine, "No seed gave the needed hand.")
		var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
		var athlete: int = Scenario.permanent_named(engine, engine.hero().id, "Athlete")
		assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Pump"),
			[MmReference.to_object(athlete)]), "")
		assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseTargetDecision), "")

		var aimed: int = AiScenario.ask(engine, agent)

		assert_eq(AiScenario.chosen_target(engine, aimed).id, ogre)
		assert_eq(engine.submit(aimed), "")
		assert_eq(Scenario.resolve_stack(engine), "")
		assert_eq(engine.game_state().object(ogre).cant_block_in_game_turn, engine.game_state().game_turn)


func test_cant_block_this_turn_is_aimed_as_a_tap_is() -> void:
	var effects: Array[MmEffect] = [Scenario.cant_block_this_turn(Scenario.targeted(0))]

	assert_true(AiTiming.is_harmful(effects), "It is aimed at the other player's creatures.")
	assert_true(AiTiming.taps(effects), "Scored once the turn is over, and wasted on a tapped creature.")


## A 2/1 costing {0} with Arena Athlete's Heroic.
func _athlete() -> MmCardDefinition:
	var heroic: TriggeredAbility = Scenario.triggered(Scenario.casts(Scenario.targets_source(), MmTrigger.Whose.YOU),
		[Scenario.cant_block_this_turn(Scenario.targeted(0))], [Scenario.target(Scenario.creature_you_dont_control())])
	return Scenario.creature("Athlete", 2, 1, [heroic])


## An instant costing {0}: "Target creature gets +1/+1 until end of turn."
func _pump() -> MmCardDefinition:
	return Scenario.instant("Pump", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, Scenario.targeted(0)))])
