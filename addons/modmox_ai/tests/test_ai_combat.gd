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


func test_chump_blocks_a_token_put_onto_the_battlefield_attacking_when_its_damage_would_be_lethal() -> void:
	# CR 508.4: Brimaz's Cat was never declared, but it is attacking, so the blockers
	# decision lists it with Brimaz.
	var cub: MmCardDefinition = Scenario.creature("Cub", 1, 1)
	var engine: MmEngine = _villain_to_block([Scenario.brimaz()], [cub, cub], 1)
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]

	var blocks: Array = AiScenario.ask(engine, AiAgent.new())

	var blocked: Array[int] = []
	for pair: Variant in blocks:
		blocked.append((pair as Array)[1] as int)
	assert_eq(blocks.size(), 2)
	assert_true(blocked.has(cat), "Brimaz's 3 or the Cat's 1 would each take the Villain's last life.")


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


func test_attacks_into_an_even_trade_that_path_of_bravery_turns_into_a_win() -> void:
	# The Combat Oracle plays the engine's own combat, so it sees the conditional +1/+1 and
	# the life its trigger gains.
	var path: MmCardDefinition = Scenario.free_copy(load("res://content/cards/magic_2014/path_of_bravery.tres") as MmCardDefinition)
	var engine: MmEngine = Scenario.combat_ready([path, AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("grizzly_bears")])
	assert_not_null(engine)

	var attackers: Array = AiScenario.ask(engine, AiAgent.new())

	assert_eq(attackers.size(), 1, "A 3/3 Bears kills a 2/2 blocker and survives.")


func test_attacks_into_an_even_trade_that_its_own_attack_trigger_turns_into_a_win() -> void:
	# The Combat Oracle resolves "whenever this creature attacks" before blockers, as the
	# engine does.
	var counter: PutCountersEffect = Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, SourceSelection.new())
	var charger: MmCardDefinition = Scenario.creature("Charger", 2, 2, [Scenario.triggered(Scenario.attacks(), [counter])])
	var engine: MmEngine = Scenario.combat_ready([charger], [AiScenario.free_alpha("grizzly_bears")])
	assert_not_null(engine)

	var attackers: Array = AiScenario.ask(engine, AiAgent.new())

	assert_eq(attackers.size(), 1, "With its +1/+1 counter, a 3/3 kills a 2/2 blocker and survives.")


func test_blocks_with_a_creature_its_own_block_trigger_lets_survive_and_kill() -> void:
	# The Combat Oracle resolves "whenever this creature blocks a creature" before combat
	# damage, as the engine does. Without it, the 2/2 would be a chump block at safe life.
	var grow: CreateContinuousEffect = Scenario.until_end_of_turn(Scenario.modify_pt(3, 3, SourceSelection.new()))
	var bulwark: MmCardDefinition = Scenario.creature("Bulwark", 2, 2, [Scenario.triggered(Scenario.blocks_a_creature(), [grow])])
	var engine: MmEngine = _villain_to_block([AiScenario.free_alpha("hill_giant")], [bulwark])
	var agent: AiAgent = AiAgent.new()

	var blocks: Array = AiScenario.ask(engine, agent)

	assert_eq(blocks.size(), 1, "As a 5/5 it kills the 3/3 Giant and survives.")
	assert_eq(agent.explain(), AiAgent.Reason.SAFE_BLOCKS)


func test_blocks_with_brimaz_whose_token_blocking_too_makes_the_block_kill() -> void:
	# The Combat Oracle resolves Brimaz's trigger, so the Cat that enters blocking the Ox adds
	# its 1 to Brimaz's 3. Without it both blockers would only survive, and the cheaper Wall
	# would block.
	var engine: MmEngine = _villain_to_block([Scenario.creature("Ox", 2, 4)], [Scenario.blocking_brimaz(), Scenario.creature("Wall", 0, 5)])
	var ox: int = Scenario.permanent_named(engine, engine.hero().id, "Ox")
	var brimaz: int = Scenario.permanent_named(engine, engine.villain().id, "Brimaz")

	var blocks: Array = AiScenario.ask(engine, AiAgent.new())

	assert_eq(blocks, [[brimaz, ox]], "Brimaz and its Cat deal 4 to the 2/4 Ox, which can't kill Brimaz.")


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
func test_a_creature_defining_its_power_attacks_for_lethal_by_that_power() -> void:
	# A */3 such as Nishoba Brawler, printed with power 0: its power is worked out (CR 604.3).
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.power = Scenario.constant(3)
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Brawler", 0, 3, [defining])], no_creatures, [], [],
		Step.DECLARE_ATTACKERS, 3)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	assert_eq((AiScenario.ask(engine, agent) as Array).size(), 1)
	assert_eq(agent.explain(), AiAgent.Reason.LETHAL_ATTACK, "Its 3 power is the Villain's last 3 life.")


func test_attacking_with_a_creature_that_triggers_on_becoming_tapped_sets_off_its_trigger() -> void:
	# Zar Ojanen's ability: the attack taps it, and the trigger resolves before blockers.
	var scion: MmCardDefinition = Scenario.scion()
	var cub: MmCardDefinition = Scenario.creature("Cub", 1, 1)
	var hero_creatures: Array[MmCardDefinition] = [scion, cub]
	var no_creatures: Array[MmCardDefinition] = []
	var fetch: Array[MmCardDefinition] = [Scenario.free_land_fetch()]
	var lands: Array[MmCardDefinition] = [Scenario.basic_land("Plains"), Scenario.basic_land("Forest")]
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_creatures, no_creatures, fetch + lands)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_creatures, no_creatures, fetch, no_creatures, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Forest"]), "")
	assert_eq(Scenario.play_until_step(engine, 3, Step.DECLARE_ATTACKERS), "")
	var scion_id: int = Scenario.permanent_named(engine, engine.hero().id, "Scion")

	var attackers: Array = AiScenario.ask(engine, AiAgent.new())

	assert_true(attackers.has(scion_id), "Into an empty board.")
	assert_eq(engine.submit(attackers), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	var cub_id: int = Scenario.permanent_named(engine, engine.hero().id, "Cub")
	assert_eq(Scenario.counters_on(engine, cub_id, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 1, "Toughness 1 is less than Domain 2.")


func _villain_to_block(hero_creatures: Array[MmCardDefinition], villain_creatures: Array[MmCardDefinition],
		villain_life: int = 20) -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with(hero_creatures, villain_creatures, [], [], Step.DECLARE_ATTACKERS, villain_life)
	assert_not_null(engine)
	engine.submit((engine.pending_decision() as DeclareAttackersDecision).candidate_ids.duplicate())
	Scenario.pass_to_blockers(engine)
	return engine
