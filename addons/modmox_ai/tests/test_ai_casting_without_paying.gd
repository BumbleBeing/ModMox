extends GutTest
## The Agent and Goblin Dark-Dwellers' "you may cast target instant or sorcery card with
## mana value 3 or less from your graveyard without paying its mana cost. If that spell would
## be put into your graveyard, exile it instead." (engine ADR 0104): with a Zap in its
## graveyard ("Zap deals 2 damage to any target", an instant costing {0}) and an opponent's
## 2/2 Ogre out, it says yes and casts the Zap at the Ogre.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_it_casts_the_spell_from_its_graveyard_at_a_creature_it_kills() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()),
			AiAgent.new()]:
		var engine: MmEngine = AiScenario.ready_with([], [Scenario.creature("Ogre", 2, 2)], [Scenario.dweller(), _zap()])
		assert_not_null(engine)
		assert_eq(Scenario.cast_and_resolve(engine, "Zap", [MmReference.to_player(engine.villain().id)]), "")
		assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Zap"), -1)
		assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Dweller")), "")
		assert_eq(Scenario.pass_to_yes_or_no(engine), "")

		assert_eq(AiScenario.ask(engine, agent), ChooseYesOrNoDecision.Choice.YES, "A free spell is worth casting.")
		assert_eq(engine.submit(ChooseYesOrNoDecision.Choice.YES), "")
		assert_true(engine.pending_decision() is ChooseTargetDecision, "The Zap's target.")

		var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))
		assert_true(target.is_object(), "Not a player.")
		assert_eq(engine.game_state().characteristics_of(engine.game_state().object(target.id)).name, "Ogre",
			"2 damage kills the Ogre.")


func _zap() -> MmCardDefinition:
	return Scenario.instant("Zap", Scenario.mana_cost(0), [Scenario.any_target()],
		[Scenario.deal_damage(2, Scenario.targeted(0))])
