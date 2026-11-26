extends GutTest
## The Agent and Niblis of Frost's "Whenever you cast an instant or sorcery spell, tap target
## creature an opponent controls. That creature doesn't untap during its controller's next
## untap step." (CR 502.3): the trigger is aimed at the other player's creature worth most,
## which is kept out of two of their turns' combats.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_the_trigger_taps_and_freezes_the_opposing_creature_worth_most() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()),
			AiAgent.new()]:
		var engine: MmEngine = AiScenario.ready_with([_niblis()],
			[Scenario.creature("Ogre", 4, 4), Scenario.creature("Squire", 1, 1)], [_gift()])
		assert_not_null(engine, "No seed gave the needed hand.")
		var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
		assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Gift")), "")
		assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseTargetDecision), "")

		var aimed: int = AiScenario.ask(engine, agent)

		assert_eq(AiScenario.chosen_target(engine, aimed).id, ogre)
		assert_eq(engine.submit(aimed), "")
		assert_eq(Scenario.resolve_stack(engine), "")
		assert_true(engine.game_state().object(ogre).is_tapped)
		assert_true(engine.game_state().object(ogre).skips_next_untap)


## A 3/3 costing {0} with Niblis of Frost's trigger.
func _niblis() -> MmCardDefinition:
	var spells: AnyOfFilter = AnyOfFilter.new()
	spells.filters = [Scenario.of_type(MmCardTypes.CardType.INSTANT), Scenario.of_type(MmCardTypes.CardType.SORCERY)]
	var cast: SpellCastTrigger = SpellCastTrigger.new()
	cast.whose = MmTrigger.Whose.YOU
	cast.filter = spells
	var freezes: TriggeredAbility = Scenario.triggered(cast,
		[Scenario.tap(Scenario.targeted(0)), Scenario.doesnt_untap(Scenario.targeted(0))],
		[Scenario.target(Scenario.creature_you_dont_control())])
	return Scenario.creature("Niblis", 3, 3, [freezes])


## An instant costing {0}: "You gain 1 life."
func _gift() -> MmCardDefinition:
	return Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
