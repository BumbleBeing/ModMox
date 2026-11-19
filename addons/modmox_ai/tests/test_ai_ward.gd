extends GutTest
## Ward (CR 702.21a, ADR 0062): an Agent pays ward to keep its own spell from being
## countered, and a CHEAP Agent aims a harmful spell at a warded permanent only when it
## could pay both the spell and the ward. A FULL Agent simulates either way, the ward
## trigger and its payment included. Neither knows any card's name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_an_agent_pays_ward_to_keep_its_spell() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())]:
		var engine: MmEngine = _hero_main([Scenario.mana_bird()], [Scenario.warden(), _cub()])
		var warden: int = Scenario.permanent_named(engine, engine.villain().id, "Warden")
		assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Zap"), [MmReference.to_object(warden)]), "")
		assert_eq(Scenario.pass_to_pay_or_not(engine), "")

		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(answer, ChooseYesOrNoDecision.Choice.YES, "Paying {2} keeps a Zap that kills the Warden.")
		assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)
		assert_eq(engine.submit(answer), "")
		assert_true(engine.pending_decision() is PayManaDecision)


func test_a_cheap_agent_aims_away_from_a_ward_it_cannot_pay() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = _zap_aimed(no_creatures)
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(_name_of(engine, answer), "Cub", "With no mana for ward, the Zap would only be countered.")


func test_a_cheap_agent_aims_at_a_warded_creature_when_it_can_pay_the_ward() -> void:
	var engine: MmEngine = _zap_aimed([Scenario.mana_bird()])
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var answer: int = AiScenario.ask(engine, cheap)

	assert_eq(_name_of(engine, answer), "Warden", "The more valuable creature, and the Bird pays its ward.")


## A 1/1 creature costing {0}, worth less than the Warden.
func _cub() -> MmCardDefinition:
	return Scenario.creature("Cub", 1, 1)


## The Hero with [param creatures], and the Villain with [param theirs], in the Hero's main
## phase of Game Turn 3 with a Zap in hand: an instant costing {0}, 2 damage to any target.
func _hero_main(creatures: Array[MmCardDefinition], theirs: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with(creatures, theirs, [Scenario.free_shock("Zap", 2)])
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


## The Hero with [param creatures] has begun casting Zap against a Villain with a Warden
## (ward {2}) and a Cub, and its target is asked.
func _zap_aimed(creatures: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = _hero_main(creatures, [Scenario.warden(), _cub()])
	var zap: int = Scenario.card_in_hand(engine, engine.hero(), "Zap")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, zap)), "")
	assert_true(engine.pending_decision() is ChooseTargetDecision)
	return engine


func _name_of(engine: MmEngine, answer: int) -> String:
	var chosen: MmReference = AiScenario.chosen_target(engine, answer)
	return engine.game_state().characteristics_of(engine.game_state().object(chosen.id)).name if chosen.is_object() else "a player"
