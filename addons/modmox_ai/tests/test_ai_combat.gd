extends GutTest
## Attacking and blocking (A163): aggression levels and escalating block passes over the
## Combat Oracle, which runs the engine's own combat on Simulation Copies.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


func test_attacks_with_everything_into_an_empty_board() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.combat_ready([AiScenario.free_alpha("grizzly_bears"), AiScenario.free_alpha("savannah_lions")], no_creatures)
	assert_not_null(engine)

	var attackers: Array = AiScenario.ask(engine, AiAgent.new())

	assert_eq(attackers.size(), 2)


func test_does_not_attack_into_a_blocker_that_kills_it_and_survives() -> void:
	var engine: MmEngine = Scenario.combat_ready([AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("hill_giant")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	assert_eq(AiScenario.ask(engine, agent), [])
	assert_eq(agent.explain(), AiAgent.Reason.AGGRESSION)


func test_attacks_with_everything_when_that_is_lethal() -> void:
	var bears: MmCardDefinition = AiScenario.free_alpha("grizzly_bears")
	var engine: MmEngine = AiScenario.ready_with([bears, bears], [AiScenario.free_alpha("hill_giant")], [], [],
		Step.DECLARE_ATTACKERS, 2)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	assert_eq((AiScenario.ask(engine, agent) as Array).size(), 2, "The Giant can stop only one.")
	assert_eq(agent.explain(), AiAgent.Reason.LETHAL_ATTACK)


func test_a_flyer_attacks_past_ground_blockers() -> void:
	var engine: MmEngine = Scenario.combat_ready([AiScenario.free_alpha("serra_angel")], [AiScenario.free_alpha("hill_giant")])
	assert_not_null(engine)

	assert_eq((AiScenario.ask(engine, AiAgent.new()) as Array).size(), 1)


func test_blocks_when_the_blocker_survives_and_kills() -> void:
	var engine: MmEngine = _villain_to_block([AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("hurloon_minotaur")])

	var blocks: Array = AiScenario.ask(engine, AiAgent.new())

	assert_eq(blocks.size(), 1)


func test_does_not_chump_block_while_life_is_safe() -> void:
	var engine: MmEngine = _villain_to_block([AiScenario.free_alpha("craw_wurm")], [AiScenario.free_alpha("grizzly_bears")])
	var agent: AiAgent = AiAgent.new()

	assert_eq(AiScenario.ask(engine, agent), [])
	assert_eq(agent.explain(), AiAgent.Reason.SAFE_BLOCKS)


func test_chump_blocks_when_the_attack_would_be_lethal() -> void:
	var engine: MmEngine = _villain_to_block([AiScenario.free_alpha("craw_wurm")], [AiScenario.free_alpha("grizzly_bears")], 6)
	var agent: AiAgent = AiAgent.new()

	var blocks: Array = AiScenario.ask(engine, agent)

	assert_eq(blocks.size(), 1)
	assert_eq(agent.explain(), AiAgent.Reason.LIFE_IN_DANGER)


func test_gang_blocks_an_attacker_neither_blocker_could_kill_alone() -> void:
	var bears: MmCardDefinition = AiScenario.free_alpha("grizzly_bears")
	var engine: MmEngine = _villain_to_block([AiScenario.free_alpha("hill_giant")], [bears, bears])

	var blocks: Array = AiScenario.ask(engine, AiAgent.new())

	assert_eq(blocks.size(), 2, "Two Bears kill the Giant, which can kill only one of them.")


func test_does_not_gang_block_an_attacker_the_pair_cannot_kill() -> void:
	var bears: MmCardDefinition = AiScenario.free_alpha("grizzly_bears")
	var engine: MmEngine = _villain_to_block([AiScenario.free_alpha("ironroot_treefolk")], [bears, bears])

	assert_eq(AiScenario.ask(engine, AiAgent.new()), [], "Two Bears deal 4 to a 3/5 and one of them dies.")


func test_does_not_attack_into_an_even_trade_when_the_race_is_even() -> void:
	# Even clocks set the SAFE aggression level: only attacks it survives.
	var engine: MmEngine = Scenario.combat_ready([AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("grizzly_bears")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	assert_eq(AiScenario.ask(engine, agent), [])
	assert_eq(agent.explain_detail(), "aggression %d" % AiAttackPlanner.Aggression.SAFE)


func test_trampling_damage_kills_the_blockers_and_the_rest_goes_to_the_player() -> void:
	var trampler: MmCardDefinition = Scenario.creature("Trampler", 6, 6, [TrampleAbility.new()])
	var engine: MmEngine = _villain_to_block([trampler],
		[AiScenario.free_alpha("grizzly_bears"), AiScenario.free_alpha("hurloon_minotaur")])
	var attacker: int = Scenario.permanent_named(engine, engine.hero().id, "Trampler")
	var blocks: Array = []
	for blocker: int in (engine.pending_decision() as DeclareBlockersDecision).candidate_blocker_ids:
		blocks.append([blocker, attacker])
	engine.submit(blocks)
	AiScenario.pass_to(engine, engine.hero().id, DivideCombatDamageDecision)
	var decision: DivideCombatDamageDecision = engine.pending_decision() as DivideCombatDamageDecision
	var agent: AiAgent = AiAgent.new()

	var amounts: Array = AiScenario.ask(engine, agent)

	assert_eq(decision.validate(amounts), "")
	assert_eq(amounts, [2, 3, 1], "Bears 2 and Minotaur 3 are lethal; 1 tramples over.")
	assert_eq(agent.explain(), AiAgent.Reason.KILL_MOST_VALUABLE)


## The Hero attacks with all of [param hero_creatures]; stops at the Villain's blockers
## decision.
func _villain_to_block(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		villain_life: int = 20) -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with(hero_creatures, villain_creatures, [], [], Step.DECLARE_ATTACKERS, villain_life)
	assert_not_null(engine)
	engine.submit((engine.pending_decision() as DeclareAttackersDecision).candidate_ids.duplicate())
	Scenario.pass_to_blockers(engine)
	return engine
