extends GutTest
## Casting by one-step simulation (A161, A181): every play is weighed against passing, and
## targets against each other. Timing Tags hold tricks and removal for their windows (A164).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


func test_lightning_bolt_goes_at_the_creature_it_kills() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("lightning_bolt")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)
	assert_eq(AiScenario.cast_name(engine, play), "Lightning Bolt")
	assert_eq(agent.explain(), AiAgent.Reason.ROLLOUT_SCORE)
	engine.submit(play)

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))
	assert_eq(target.id, Scenario.permanent_named(engine, engine.villain().id, "Grizzly Bears"))


func test_lightning_bolt_goes_to_the_face_when_that_is_lethal() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [AiScenario.free_alpha("grizzly_bears")],
		[AiScenario.free_alpha("lightning_bolt")], [], Step.PRECOMBAT_MAIN, 3)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()
	engine.submit(AiScenario.ask(engine, agent))

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

	assert_true(target.is_player())
	assert_eq(target.id, engine.villain().id)


func test_lightning_bolt_is_held_when_it_would_only_hit_the_face() -> void:
	# A real Bolt: a card in hand is worth more than 3 damage to a player at 20 (A179).
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures,
		[AiScenario.alpha("mountain"), AiScenario.alpha("lightning_bolt")])
	assert_not_null(engine)
	Scenario.play_first_land(engine)
	var agent: AiAgent = AiAgent.new()
	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Lightning Bolt")))
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var play: int = AiScenario.ask(engine, agent)
	var easy_play: int = AiScenario.ask(engine, easy)

	assert_true(AiScenario.action_at(engine, play) is PassAction)
	assert_true(AiScenario.action_at(engine, easy_play) is PassAction)
	assert_eq(easy.explain(), AiAgent.Reason.SCORES_WORSE_THAN_PASS)


func test_terror_is_never_aimed_at_its_own_creature() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("grizzly_bears")],
		[AiScenario.free_alpha("hill_giant")], [AiScenario.free_alpha("terror")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()
	assert_eq(AiScenario.cast_name(engine, AiScenario.ask(engine, agent)), "Terror")
	engine.submit(AiScenario.ask(engine, agent))

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

	assert_eq(target.id, Scenario.permanent_named(engine, engine.villain().id, "Hill Giant"))


func test_a_creature_is_cast_rather_than_held() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures, [AiScenario.free_alpha("hill_giant")])
	assert_not_null(engine)

	assert_eq(AiScenario.cast_name(engine, AiScenario.ask(engine, AiAgent.new())), "Hill Giant")


func test_giant_growth_waits_for_combat() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, [AiScenario.free_alpha("grizzly_bears")],
		[AiScenario.free_alpha("giant_growth")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is PassAction)
	assert_eq(agent.explain(), AiAgent.Reason.WAIT_FOR_COMBAT)


func test_giant_growth_saves_a_blocked_attacker_and_kills_its_blocker() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("grizzly_bears")],
		[AiScenario.free_alpha("hill_giant")], [AiScenario.free_alpha("giant_growth")], [], Step.DECLARE_ATTACKERS)
	assert_not_null(engine)
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Hill Giant")
	engine.submit([bears])
	Scenario.pass_to_blockers(engine)
	engine.submit([[giant, bears]])
	AiScenario.pass_to(engine, engine.hero().id, PriorityDecision)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Giant Growth")
	engine.submit(play)
	assert_eq(AiScenario.chosen_target(engine, AiScenario.ask(engine, agent)).id, bears)


func test_fog_is_held_until_combat_damage_would_be_lethal() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("craw_wurm")], [], [],
		[AiScenario.free_alpha("fog")], Step.DECLARE_ATTACKERS, 6)
	assert_not_null(engine)
	var wurm: int = Scenario.permanent_named(engine, engine.hero().id, "Craw Wurm")
	var agent: AiAgent = AiAgent.new()
	engine.submit([wurm])
	AiScenario.pass_to(engine, engine.villain().id, PriorityDecision)
	assert_eq(engine.game_state().step, Step.DECLARE_ATTACKERS)
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PassAction, "Not before blocks.")
	engine.submit(AiScenario.ask(engine, agent))
	AiScenario.pass_to(engine, engine.villain().id, PriorityDecision)
	assert_eq(engine.game_state().step, Step.DECLARE_BLOCKERS)

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Fog")


func test_fog_is_not_cast_against_damage_it_can_afford() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("grizzly_bears")], [], [],
		[AiScenario.free_alpha("fog")], Step.DECLARE_ATTACKERS)
	assert_not_null(engine)
	engine.submit([Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")])
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.game_state().step == Step.DECLARE_BLOCKERS and running.pending_decision().player_id == running.villain().id)

	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, AiAgent.new())) is PassAction)


func test_uthden_troll_regenerates_only_when_it_would_die() -> void:
	for is_blocked: bool in [true, false]:
		var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("uthden_troll")],
			[AiScenario.free_alpha("hill_giant")], [AiScenario.alpha("mountain")])
		assert_not_null(engine)
		Scenario.play_first_land(engine)
		var troll: int = Scenario.permanent_named(engine, engine.hero().id, "Uthden Troll")
		var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Hill Giant")
		Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
		engine.submit([troll])
		Scenario.pass_to_blockers(engine)
		engine.submit([[giant, troll]] if is_blocked else [])
		AiScenario.pass_to(engine, engine.hero().id, PriorityDecision)
		var agent: AiAgent = AiAgent.new()

		var play: int = AiScenario.ask(engine, agent)

		var activates: bool = AiScenario.action_at(engine, play) is ActivateAbilityAction
		assert_eq(activates, is_blocked, "Blocked by the Giant: %s" % is_blocked)


func test_a_play_that_scores_no_better_than_passing_is_never_made() -> void:
	# A161: a regeneration shield on an unblocked Troll changes nothing, so it ties with
	# passing, and a tie never goes to the play, whatever the AI RNG says.
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("uthden_troll")], [],
		[AiScenario.alpha("mountain")])
	assert_not_null(engine)
	Scenario.play_first_land(engine)
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	engine.submit([Scenario.permanent_named(engine, engine.hero().id, "Uthden Troll")])
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.game_state().step == Step.DECLARE_BLOCKERS and running.pending_decision().player_id == running.hero().id)
	assert_true(engine.pending_decision() is PriorityDecision)
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	var normal: AiAgent = AiAgent.new()

	for ai_seed: int in 12:
		var source: MmSimulationSource = MmSimulationSource.new(engine, engine.hero().id, ai_seed, true)
		var play: int = easy.answer(engine.pending_decision(), null, source)
		assert_true(AiScenario.action_at(engine, play) is PassAction, "AI seed %d" % ai_seed)
		assert_eq(easy.explain(), AiAgent.Reason.SCORES_WORSE_THAN_PASS)
		play = normal.answer(engine.pending_decision(), null, MmSimulationSource.new(engine, engine.hero().id, ai_seed, true))
		assert_true(AiScenario.action_at(engine, play) is PassAction, "Normal, AI seed %d" % ai_seed)


func test_payment_taps_the_land_whose_color_the_hand_needs_least() -> void:
	assert_eq(_lands_left_after_casting_gray_ogre("giant_growth"), ["Forest"], "Giant Growth in hand still needs green.")
	assert_eq(_lands_left_after_casting_gray_ogre("lightning_bolt"), ["Mountain"], "Lightning Bolt in hand still needs red.")


## Casts Gray Ogre ({2}{R}) with two Mountains and two Forests while holding
## [param kept_file], and returns the names of the lands left untapped.
func _lands_left_after_casting_gray_ogre(kept_file: String) -> Array[String]:
	var kept: MmCardDefinition = AiScenario.alpha(kept_file)
	var mountain: MmCardDefinition = AiScenario.alpha("mountain")
	var forest: MmCardDefinition = AiScenario.alpha("forest")
	var cards: Array[MmCardDefinition] = []
	for index: int in 10:
		cards.append_array([mountain, forest, AiScenario.alpha("gray_ogre"), kept])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			if not Scenario.ready_in_main(running, 7, 4, "Gray Ogre"):
				return false
			return Scenario.permanents_named(running, running.hero().id, "Mountain").size() == 2 \
				and Scenario.permanents_named(running, running.hero().id, "Forest").size() == 2 \
				and Scenario.card_in_hand(running, running.hero(), kept.name) != -1)
	assert_not_null(engine, "No seed gave the lands and hand.")
	var untapped: Array[String] = []
	if engine == null:
		return untapped
	var agent: AiAgent = AiAgent.new()
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Gray Ogre")))
	while engine.pending_decision() is PayManaDecision:
		assert_eq(AiScenario.let_answer(engine, agent), "")
		assert_eq(agent.explain(), AiAgent.Reason.PAYMENT_PLAN)
	for land: int in Scenario.permanents_named(engine, engine.hero().id, "Mountain") + Scenario.permanents_named(engine, engine.hero().id, "Forest"):
		if not engine.game_state().object(land).is_tapped:
			untapped.append(engine.game_state().characteristics_of(engine.game_state().object(land)).name)
	return untapped


func test_payment_spends_pool_mana_before_tapping_lands() -> void:
	var swamp: MmCardDefinition = AiScenario.alpha("swamp")
	var cards: Array[MmCardDefinition] = []
	for index: int in 10:
		cards.append_array([swamp, swamp, AiScenario.alpha("dark_ritual"), AiScenario.alpha("frozen_shade")])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			return Scenario.ready_in_main(running, 3, 2, "Dark Ritual") \
				and Scenario.card_in_hand(running, running.hero(), "Frozen Shade") != -1)
	assert_not_null(engine, "No seed gave the lands and hand.")
	Scenario.cast_and_resolve(engine, "Dark Ritual")
	var agent: AiAgent = AiAgent.new()
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Frozen Shade")))

	while engine.pending_decision() is PayManaDecision:
		assert_eq(AiScenario.let_answer(engine, agent), "")

	var untapped: int = 0
	for land: int in Scenario.permanents_named(engine, engine.hero().id, "Swamp"):
		if not engine.game_state().object(land).is_tapped:
			untapped += 1
	assert_eq(untapped, 1, "One Swamp paid for the Ritual; the Shade used only the Ritual's mana.")
	assert_eq(engine.hero().mana_pool().size(), 0)
