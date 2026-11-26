extends GutTest
## A card with a choice of additional costs, as Bayou Groff's "sacrifice a creature or pay
## {3}" (engine ADR 0086's second addendum), is offered a cast for each, and the Agent weighs
## them as any two plays: simulation sees the creature sacrificed, or the mana spent. Groff is
## a 5/4 costing {0} with that ability; the Mana Rock an artifact costing {0}, "{T}: Add
## {W}{W}{W}."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


func test_with_mana_to_spare_it_pays_rather_than_sacrifice_its_ogre() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Ogre", 4, 4), _mana_rock()], [], [Scenario.groff()],
		[], Step.POSTCOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed board.")
	var groff: int = Scenario.card_in_hand(engine, engine.hero(), "Groff")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_ne(Scenario.cast_index_other_additional(decision, groff, false), -1, "It could sacrifice the Ogre.")

	var answer: int = AiScenario.ask(engine, AiAgent.new())

	var cast: CastSpellAction = AiScenario.action_at(engine, answer) as CastSpellAction
	assert_not_null(cast, "It casts a Groff.")
	if cast != null:
		assert_true(cast.is_for_other_additional_cost, "It pays {3}, keeping the Ogre.")


func test_with_no_mana_it_sacrifices_a_squirrel_for_a_groff() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Squirrel", 1, 1)], [], [Scenario.groff()], [],
		Step.POSTCOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed board.")

	var answer: int = AiScenario.ask(engine, AiAgent.new())

	var cast: CastSpellAction = AiScenario.action_at(engine, answer) as CastSpellAction
	assert_not_null(cast, "A 5/4 is worth a 1/1.")
	if cast != null:
		assert_false(cast.is_for_other_additional_cost)


## An artifact costing {0}: "{T}: Add {W}{W}{W}."
func _mana_rock() -> MmCardDefinition:
	return Scenario.artifact("Mana Rock", [Scenario.tap_for_mana(MmMana.Type.WHITE, 3)])
