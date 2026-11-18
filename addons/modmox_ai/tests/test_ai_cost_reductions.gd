extends GutTest
## The Agent casts what a cost reduction lets it afford (ADR 0050): what it may cast comes
## from the engine's legal actions, which pay the reduced cost, so it needs no rule of its own.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const W: MmMana.Type = MmMana.Type.WHITE


func test_a_pump_with_affinity_is_cast_for_its_reduced_cost_to_win_a_fight() -> void:
	var claws: MmCardDefinition = Scenario.instant("Claws", Scenario.mana_cost(2, [W, W]), [],
		[Scenario.until_end_of_turn(Scenario.modify_pt(2, 2, Scenario.each_creature(ControlledByFilter.new())))])
	claws.abilities.push_front(Scenario.affinity(Scenario.has_subtype("Cat")))
	var engine: MmEngine = AiScenario.ready_with([_lion(), _lion(), Scenario.elf(), Scenario.elf()],
		[AiScenario.free_alpha("hill_giant")], [claws], [], Step.DECLARE_ATTACKERS)
	assert_not_null(engine)
	var cats: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Lion")
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Hill Giant")
	engine.submit([cats[0]])
	Scenario.pass_to_blockers(engine)
	engine.submit([[giant, cats[0]]])
	AiScenario.pass_to(engine, engine.hero().id, PriorityDecision)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Claws", "Two Elves pay {W}{W}, all {2}{W}{W} costs with two Cats.")


## A 2/2 Cat costing {0}.
func _lion() -> MmCardDefinition:
	var lion: MmCardDefinition = Scenario.creature("Lion", 2, 2)
	lion.subtypes = ["Cat"]
	return lion
