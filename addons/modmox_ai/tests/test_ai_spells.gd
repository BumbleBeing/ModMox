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


func test_a_cheap_agent_holds_removal_that_could_only_hit_its_own_creature() -> void:
	# Terror cannot target an artifact creature, so the Hero's own Bears is all it could hit.
	var golem: MmCardDefinition = Scenario.creature("Golem", 2, 2)
	golem.card_types.append(MmCardTypes.CardType.ARTIFACT)
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("grizzly_bears")], [golem],
		[AiScenario.free_alpha("terror")])
	assert_not_null(engine)
	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Terror")))

	var play: int = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))

	assert_ne(AiScenario.cast_name(engine, play), "Terror", "It casts another card or passes.")


func test_a_cheap_agent_casts_removal_with_an_opposing_creature_to_aim_at() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("grizzly_bears")],
		[AiScenario.free_alpha("hill_giant")], [AiScenario.free_alpha("terror")])
	assert_not_null(engine)

	var play: int = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))

	assert_eq(AiScenario.cast_name(engine, play), "Terror")


func test_a_cheap_agent_aims_counted_damage_at_the_creature_it_kills() -> void:
	# Artillery Blast's "1 plus [Domain]" is worked out on the Agent's world: with a Plains
	# and a Mountain it deals 3, enough for the Ogre but not the more valuable Wurm.
	var blast: DealDamageEffect = Scenario.deal_damage(0, Scenario.targeted(0))
	blast.amount = Scenario.sum([Scenario.constant(1), Scenario.domain()])
	var spell: MmCardDefinition = Scenario.instant("Blast", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [blast])
	var no_creatures: Array[MmCardDefinition] = []
	var villain_creatures: Array[MmCardDefinition] = [Scenario.creature("Ogre", 3, 3), Scenario.creature("Wurm", 6, 6)]
	var hero_extras: Array[MmCardDefinition] = [Scenario.free_land_fetch(), spell]
	var lands: Array[MmCardDefinition] = [Scenario.basic_land("Plains"), Scenario.basic_land("Mountain")]
	var setup: MmEncounterSetup = Scenario.combat_setup(no_creatures, villain_creatures, hero_extras + lands)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_creatures, villain_creatures, hero_extras, no_creatures,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine)
	assert_eq(Scenario.fetch_lands(engine, ["Plains", "Mountain"]), "")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	engine.submit(Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), "Blast")))

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)))

	assert_eq(target.id, Scenario.permanent_named(engine, engine.villain().id, "Ogre"))


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


func test_outflank_is_cast_at_an_attacker_once_blockers_are_declared() -> void:
	# Removal aimed at "attacking or blocking": nothing to aim at before combat, the attacker
	# once blocks are in.
	var outflank: MmCardDefinition = Scenario.free_outflank("Outflank")
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("grizzly_bears")],
		[AiScenario.free_alpha("savannah_lions"), AiScenario.free_alpha("savannah_lions")], [], [outflank])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	AiScenario.pass_to(engine, engine.villain().id, PriorityDecision)
	assert_eq(engine.game_state().step, Step.PRECOMBAT_MAIN)
	var outflank_id: int = Scenario.card_in_hand(engine, engine.villain(), "Outflank")
	assert_false(Scenario.offers_cast(engine, outflank_id), "Nothing attacks or blocks in a main phase.")
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	engine.submit([bears])
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.game_state().step == Step.DECLARE_BLOCKERS and running.pending_decision() is PriorityDecision \
			and running.pending_decision().player_id == running.villain().id)

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Outflank")
	engine.submit(play)
	assert_eq(AiScenario.chosen_target(engine, AiScenario.ask(engine, agent)).id, bears)


func test_slash_of_light_is_cast_at_the_creature_its_sum_kills() -> void:
	# Two Bears alone would deal 2; the Sword makes it 3, enough for the Giant.
	var engine: MmEngine = AiScenario.ready_with(
		[Scenario.creature("Bear", 2, 2), Scenario.creature("Bear", 2, 2), Scenario.sword("Sword")],
		[Scenario.creature("Giant", 3, 3)], [Scenario.free_slash("Slash")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)
	assert_eq(AiScenario.cast_name(engine, play), "Slash")
	engine.submit(play)

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))
	assert_eq(target.id, Scenario.permanent_named(engine, engine.villain().id, "Giant"))


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


func test_payment_taps_a_land_before_a_creature_for_a_colored_symbol() -> void:
	var twin: MmCardDefinition = Scenario.creature("Twin Bear", 2, 2, [], Scenario.mana_cost(0, [MmMana.Type.GREEN, MmMana.Type.GREEN]))
	var forest: MmCardDefinition = AiScenario.alpha("forest")
	var cards: Array[MmCardDefinition] = []
	for index: int in 10:
		cards.append_array([forest, forest, AiScenario.free_alpha("llanowar_elves"), twin])
	# The Elves come between the two Forests, so going by age alone would tap them second.
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool:
			if not Scenario.ready_in_main(running, 1, 1, "Llanowar Elves"):
				return false
			if Scenario.cast_and_resolve(running, "Llanowar Elves") != "":
				return false
			return Scenario.ready_in_main(running, 3, 3, "Twin Bear") \
				and Scenario.permanents_named(running, running.hero().id, "Forest").size() == 2)
	assert_not_null(engine, "No seed gave the lands and hand.")
	if engine == null:
		return
	var elves: int = Scenario.permanent_named(engine, engine.hero().id, "Llanowar Elves")
	var forests: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Forest")
	assert_between(elves, forests.min() as int, forests.max() as int, "The Elves are older than one Forest.")
	var agent: AiAgent = AiAgent.new()
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Twin Bear")))

	while engine.pending_decision() is PayManaDecision:
		assert_eq(AiScenario.let_answer(engine, agent), "")

	assert_false(engine.game_state().object(elves).is_tapped, "A creature is the last thing tapped, for a color too.")
	for land: int in forests:
		assert_true(engine.game_state().object(land).is_tapped)


# --- Spells that only add mana -----------------------------------------------------

func test_mana_is_not_added_in_the_other_players_end_step_with_nothing_to_spend_it_on() -> void:
	var engine: MmEngine = _engine_holding_a_ritual(4, Step.END, ["Black Knight"])
	assert_not_null(engine, "No seed gave the lands and hand.")
	if engine == null:
		return
	Scenario.pass_priority(engine)
	assert_eq(engine.pending_decision().player_id, engine.hero().id, "The Hero's pass ends the Villain's turn.")
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, answer) is PassAction, "The mana would empty unspent.")
	assert_eq(agent.explain(), AiAgent.Reason.NOTHING_WORTH_DOING)
	assert_eq(agent.rollout_count(), 0, "A spell that only adds mana for nothing is not a candidate.")


func test_mana_is_not_added_in_its_own_upkeep_before_creatures_can_be_cast() -> void:
	var engine: MmEngine = _engine_holding_a_ritual(5, Step.UPKEEP, ["Black Knight", "Frozen Shade", "Swamp"])
	assert_not_null(engine, "No seed gave the lands and hand.")
	if engine == null:
		return
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, answer) is PassAction, "It would only tap a land the main phase needs.")
	assert_eq(agent.explain(), AiAgent.Reason.NOTHING_WORTH_DOING)
	assert_eq(agent.rollout_count(), 0)


func test_mana_is_added_to_cast_a_creature_the_lands_cannot_pay_for() -> void:
	var cards: Array[MmCardDefinition] = []
	for index: int in 10:
		cards.append_array([AiScenario.alpha("swamp"), AiScenario.alpha("swamp"), AiScenario.alpha("dark_ritual"),
			AiScenario.alpha("scathe_zombies")])
	var setup: MmEncounterSetup = Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40))
	setup.starting_player_rule = MmEncounterSetup.StartingPlayerRule.HERO_STARTS
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		return Scenario.ready_in_main(running, 3, 2, "Dark Ritual") \
			and Scenario.permanents_named(running, running.hero().id, "Swamp").size() == 2 \
			and Scenario.card_in_hand(running, running.hero(), "Scathe Zombies") != -1)
	assert_not_null(engine, "No seed gave the lands and hand.")
	if engine == null:
		return
	var agent: AiAgent = AiAgent.new()

	var first: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, first), "Dark Ritual", "Two Swamps and the Ritual make four mana.")
	assert_eq(agent.explain(), AiAgent.Reason.ROLLOUT_SCORE)
	engine.submit(first)
	while engine.pending_decision() is PayManaDecision:
		assert_eq(AiScenario.let_answer(engine, agent), "")
	Scenario.resolve_stack(engine)
	assert_eq(AiScenario.cast_name(engine, AiScenario.ask(engine, agent)), "Scathe Zombies")


## An encounter stopped at the first decision of [param step] on [param game_turn], where
## the Hero controls exactly two Swamps and holds Dark Ritual and every card in
## [param also_held]. The Villain's deck is Forests and Grizzly Bears, all still in hand
## or library apart from the lands played.
func _engine_holding_a_ritual(game_turn: int, step: Step, also_held: Array[String]) -> MmEngine:
	var cards: Array[MmCardDefinition] = []
	for index: int in 8:
		cards.append_array([AiScenario.alpha("swamp"), AiScenario.alpha("swamp"), AiScenario.alpha("dark_ritual"),
			AiScenario.alpha("black_knight"), AiScenario.alpha("frozen_shade")])
	var setup: MmEncounterSetup = Scenario.setup_with(cards,
		Scenario.deck_of(AiScenario.alpha("forest"), 20, AiScenario.alpha("grizzly_bears"), 20))
	setup.starting_player_rule = MmEncounterSetup.StartingPlayerRule.HERO_STARTS
	return Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, game_turn, step, true) != "":
			return false
		if not running.pending_decision() is PriorityDecision:
			return false
		if Scenario.permanents_named(running, running.hero().id, "Swamp").size() != 2:
			return false
		for card_name: String in also_held + (["Dark Ritual"] as Array[String]):
			if Scenario.card_in_hand(running, running.hero(), card_name) == -1:
				return false
		return true)


func test_a_minus_one_minus_one_counter_goes_on_the_opposing_creature_it_kills() -> void:
	var wither: MmCardDefinition = Scenario.free_counters("Wither", MmCounter.Kind.MINUS_ONE_MINUS_ONE, 1)
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Scout", 1, 1)], [Scenario.creature("Imp", 1, 1)], [wither])
	assert_not_null(engine)
	_cast_every(engine, "Scout")
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)
	assert_eq(AiScenario.cast_name(engine, play), "Wither")
	engine.submit(play)
	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

	assert_eq(target.id, Scenario.permanent_named(engine, engine.villain().id, "Imp"))


func test_a_plus_one_plus_one_counter_goes_on_its_own_creature() -> void:
	var grow: MmCardDefinition = Scenario.free_counters("Grow", MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1)
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Scout", 2, 2)], [Scenario.creature("Imp", 2, 2)], [grow])
	assert_not_null(engine)
	_cast_every(engine, "Scout")
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)
	assert_eq(AiScenario.cast_name(engine, play), "Grow")
	engine.submit(play)
	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

	assert_eq(target.id, Scenario.permanent_named(engine, engine.hero().id, "Scout"))


func test_plus_counters_are_played_whenever_and_minus_counters_as_removal() -> void:
	var grow: Array[MmEffect] = [Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, Scenario.targeted(0))]
	var wither: Array[MmEffect] = [Scenario.put_counters(MmCounter.Kind.MINUS_ONE_MINUS_ONE, 1, Scenario.targeted(0))]

	assert_eq(AiTiming.tag_of_effects(grow), AiTiming.Tag.NONE, "It lasts, so it is no combat trick.")
	assert_eq(AiTiming.tag_of_effects(wither), AiTiming.Tag.REMOVAL)


func test_on_the_second_landfall_the_doubling_goes_on_the_creature_with_counters_not_a_bigger_one_without() -> void:
	# Scythecat Cub: "put a +1/+1 counter on target creature you control. If this is the
	# second time this ability has resolved this turn, double the number of +1/+1 counters
	# on that creature instead." Doubling none is nothing, so the Giant gains nothing.
	var cub: MmCardDefinition = Scenario.free_copy(load("res://content/cards/foundations_jumpstart/scythecat_cub.tres"))
	var rush: MmCardDefinition = Scenario.instant("Rush", Scenario.mana_cost(0), [], [Scenario.additional_land_plays(1, Scenario.you())])
	var engine: MmEngine = AiScenario.ready_with([cub, Scenario.creature("Bear", 2, 2), Scenario.creature("Giant", 4, 4)], [],
		[Scenario.basic_land("Forest"), Scenario.basic_land("Plains"), rush])
	assert_not_null(engine, "No seed gave the needed hand.")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	_play_land(engine, "Forest")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(bear)), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Rush"), "")
	_play_land(engine, "Plains")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal())

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

	assert_eq(target.id, bear, "Its one counter doubles to two; the Giant has none to double.")


## Plays the land named [param card_name] from the Hero's hand.
func _play_land(engine: MmEngine, card_name: String) -> void:
	var land: int = Scenario.card_in_hand(engine, engine.hero(), card_name)
	assert_eq(engine.submit(Scenario.play_land_index(engine.pending_decision() as PriorityDecision, land)), "")
	assert_true(engine.pending_decision() is ChooseTargetDecision, "The landfall trigger asks its target.")


## Casts every card named [param card_name] in the Hero's hand, so the Agent is left with
## the spell under test.
func _cast_every(engine: MmEngine, card_name: String) -> void:
	while Scenario.card_in_hand(engine, engine.hero(), card_name) != -1:
		assert_eq(Scenario.cast_and_resolve(engine, card_name), "")


func test_removal_goes_at_the_lifelink_creature_of_two_otherwise_alike() -> void:
	for villain_creatures: Array in [[_guard(), _cleric()], [_cleric(), _guard()]]:
		var theirs: Array[MmCardDefinition] = []
		theirs.assign(villain_creatures)
		var engine: MmEngine = AiScenario.ready_with([], theirs, [AiScenario.free_alpha("terror")])
		assert_not_null(engine)
		var agent: AiAgent = AiAgent.new()
		var play: int = AiScenario.ask(engine, agent)
		assert_eq(AiScenario.cast_name(engine, play), "Terror")
		engine.submit(play)

		var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

		assert_eq(target.id, Scenario.permanent_named(engine, engine.villain().id, "Cleric"))


func _guard() -> MmCardDefinition:
	return Scenario.creature("Guard", 3, 3)


func _cleric() -> MmCardDefinition:
	return Scenario.creature("Cleric", 3, 3, [LifelinkAbility.new()])


func test_exiling_is_removal() -> void:
	assert_eq(AiTiming.tag_of_effects([Scenario.exile(Scenario.targeted(0))]), AiTiming.Tag.REMOVAL)


func test_an_enchantment_that_exiles_as_it_enters_is_cast_and_aimed_at_the_opposing_creature() -> void:
	# Oblivion Ring's two abilities. Its trigger is harmful, so even a Cheap Agent in a
	# rollout aims it at the other player's permanent, never its own.
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Scout", 2, 2)], [AiScenario.free_alpha("hill_giant")],
		[Scenario.free_prison("Prison")])
	assert_not_null(engine)
	_cast_every(engine, "Scout")
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)
	assert_eq(AiScenario.cast_name(engine, play), "Prison")
	engine.submit(play)
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseTargetDecision), "")

	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Hill Giant")
	assert_eq(AiScenario.chosen_target(engine, AiScenario.ask(engine, agent)).id, giant)
	assert_eq(AiScenario.chosen_target(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))).id, giant)


func test_a_cheap_agent_aims_damage_that_kills_nothing_at_the_other_players_creature_not_its_own() -> void:
	var sear: MmCardDefinition = Scenario.instant("Sear", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [Scenario.deal_damage(3, Scenario.targeted(0))])
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Scout", 2, 2)], [Scenario.creature("Giant", 4, 4)], [sear])
	assert_not_null(engine)
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	engine.submit(Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), "Sear")))

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)))

	assert_eq(target.id, Scenario.permanent_named(engine, engine.villain().id, "Giant"), "3 damage will not kill it.")


func test_tapping_is_harmful_but_keeps_its_timing_tag() -> void:
	var tap: Array[MmEffect] = [Scenario.tap(Scenario.targeted(0))]

	assert_true(AiTiming.is_harmful(tap))
	assert_eq(AiTiming.tag_of_effects(tap), AiTiming.Tag.NONE)
	assert_false(AiTiming.is_harmful([Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, Scenario.targeted(0))]))


func test_an_enters_trigger_that_taps_goes_at_the_blocker_in_the_way() -> void:
	# A tap only matters in this turn's combat, so the Full Agent scores each target once the
	# turn is over: with the Wall tapped, the Scout attacks for 2. Easy scores as soon as the
	# trigger resolves, when every target ties, and keeps the Cheap pick.
	for difficulty: AiDifficulty in [AiDifficulty.normal(), AiDifficulty.easy()]:
		var engine: MmEngine = _snarecaster_target_asked()
		var wall: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		assert_eq(AiScenario.chosen_target(engine, AiScenario.ask(engine, agent)).id, wall)
		assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)


func test_a_cheap_agent_taps_the_most_valuable_untapped_opposing_creature() -> void:
	var engine: MmEngine = _snarecaster_target_asked(true)
	var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Hill Giant")
	assert_true(engine.game_state().object(giant).is_tapped)

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)))

	assert_eq(target.id, Scenario.permanent_named(engine, engine.villain().id, "Wall"), "The Giant is tapped already.")


## The Hero's Scout and the Villain's 0/4 Wall (and a Hill Giant, tapped with
## [param giant_tapped]) on the battlefield, with Snarecaster ("When this creature enters,
## tap target creature") just cast and its target asked.
func _snarecaster_target_asked(giant_tapped: bool = false) -> MmEngine:
	var snarecaster: MmCardDefinition = Scenario.creature("Snarecaster", 2, 1, [Scenario.triggered(
		Scenario.enters(IsSourceFilter.new()), [Scenario.tap(Scenario.targeted(0))],
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))])])
	var theirs: Array[MmCardDefinition] = [Scenario.creature("Wall", 0, 4)]
	if giant_tapped:
		theirs.append(AiScenario.free_alpha("hill_giant"))
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Scout", 2, 2)], theirs,
		[snarecaster, Scenario.free_tap("Snare")])
	assert_not_null(engine)
	if giant_tapped:
		var giant: int = Scenario.permanent_named(engine, engine.villain().id, "Hill Giant")
		assert_eq(Scenario.cast_and_resolve(engine, "Snare", [MmReference.to_object(giant)]), "")
	var card: int = Scenario.card_in_hand(engine, engine.hero(), "Snarecaster")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, card)), "")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseTargetDecision), "")
	return engine


func test_of_two_free_two_twos_the_one_that_also_makes_a_token_is_cast_first() -> void:
	# Prideful Parent: its enters trigger has no choice to make, and the token it makes is a
	# creature the Board Evaluator counts like any other, so nothing new is needed.
	var parent: MmCardDefinition = Scenario.free_copy(load("res://content/cards/foundations/prideful_parent.tres") as MmCardDefinition)
	var cub: MmCardDefinition = Scenario.creature("Cub", 2, 2, [VigilanceAbility.new()])
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures, [cub, parent])
	assert_not_null(engine)

	assert_eq(AiScenario.cast_name(engine, AiScenario.ask(engine, AiAgent.new())), "Prideful Parent")


func test_a_helpful_spell_goes_at_the_creature_whose_heroic_trigger_it_sets_off() -> void:
	# Heroic: the simulation of each target plays the trigger too, so the +1/+1 counter goes
	# on the 2/2 that makes a Cat as well, not on the bigger creature the counter alone favors.
	var vanguard: MmCardDefinition = Scenario.heroic("Vanguard", [Scenario.create_tokens(Scenario.cat())])
	var blessing: MmCardDefinition = Scenario.sorcery("Blessing", Scenario.mana_cost(0),
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.put_counters(MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1, Scenario.targeted(0))])
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Giant", 3, 3), vanguard], [], [blessing])
	assert_not_null(engine)
	var card: int = Scenario.card_in_hand(engine, engine.hero(), "Blessing")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, card)), "")
	var agent: AiAgent = AiAgent.new()

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

	assert_eq(target.id, Scenario.permanent_named(engine, engine.hero().id, "Vanguard"))
	assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)


func test_up_to_two_counters_go_on_its_own_two_creatures() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), Scenario.creature("Lion", 2, 1)],
		[Scenario.creature("Ogre", 3, 3)], [Scenario.free_gird()])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	var gird: int = Scenario.card_in_hand(engine, engine.hero(), "Gird")
	assert_eq(engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, gird)), "")

	var full: Array = _chosen_ids(engine, AiScenario.ask(engine, agent))
	var cheap: Array = _chosen_ids(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)))

	var expected: Array = [Scenario.permanent_named(engine, engine.hero().id, "Bear"),
		Scenario.permanent_named(engine, engine.hero().id, "Lion")]
	expected.sort()
	assert_eq(full, expected, "Both of its own, never the Ogre.")
	assert_eq(cheap, expected)


func test_the_saviors_trigger_puts_its_counter_on_the_one_other_creature() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2)], [Scenario.creature("Ogre", 3, 3)],
		[Scenario.savior()])
	assert_not_null(engine)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Savior")), "")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseTargetsDecision), "")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var chosen: Array = _chosen_ids(engine, AiScenario.ask(engine, agent))

	assert_eq(chosen, [Scenario.permanent_named(engine, engine.hero().id, "Bear")], "Its only other creature.")


## The object IDs an answer to the pending ChooseTargetsDecision chose, in ID order.
func _chosen_ids(engine: MmEngine, answer: Variant) -> Array:
	var decision: ChooseTargetsDecision = engine.pending_decision() as ChooseTargetsDecision
	var ids: Array = []
	for index: Variant in answer as Array:
		ids.append(decision.candidates[index as int].id)
	ids.sort()
	return ids


# --- Cycling ------------------------------------------------------------------------

func test_a_cycling_card_is_cycled_in_the_other_players_end_step_with_mana_to_spare() -> void:
	var engine: MmEngine = _engine_holding_a_cycler(4, Step.END)
	assert_not_null(engine, "No seed gave the Elves and hand.")
	if engine == null:
		return
	Scenario.pass_priority(engine)
	assert_eq(engine.pending_decision().player_id, engine.hero().id, "The Hero's pass ends the Villain's turn.")

	var answer: int = AiScenario.ask(engine, AiAgent.new())

	var activate: ActivateAbilityAction = AiScenario.action_at(engine, answer) as ActivateAbilityAction
	assert_not_null(activate, "ADR 0059: the Elves' mana would go unused, and a card from the library is worth more.")
	if activate != null:
		assert_eq(engine.game_state().characteristics_of(engine.game_state().object(activate.object_id)).name, "Cycler")


func test_a_cycling_card_is_not_cycled_in_its_own_main_phase() -> void:
	var engine: MmEngine = _engine_holding_a_cycler(3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the Elves and hand.")
	if engine == null:
		return
	_cast_every(engine, "Elf")
	var cycler: int = Scenario.card_in_hand(engine, engine.hero(), "Cycler")
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, cycler), -1, "It could be cycled.")

	var answer: int = AiScenario.ask(engine, AiAgent.new())

	assert_false(AiScenario.action_at(engine, answer) is ActivateAbilityAction,
		"Its mana may yet cast something: cycling waits for the other player's end step.")


func test_a_landcycling_card_is_landcycled_in_the_other_players_end_step_with_mana_to_spare() -> void:
	var engine: MmEngine = _engine_holding_a_cycler(4, Step.END, Scenario.landcycler())
	assert_not_null(engine, "No seed gave the Elves and hand.")
	if engine == null:
		return
	Scenario.pass_priority(engine)
	assert_eq(engine.pending_decision().player_id, engine.hero().id, "The Hero's pass ends the Villain's turn.")

	var answer: int = AiScenario.ask(engine, AiAgent.new())

	var activate: ActivateAbilityAction = AiScenario.action_at(engine, answer) as ActivateAbilityAction
	assert_not_null(activate, "ADR 0059: a search into the hand is worth the mana that would go unused.")
	if activate != null:
		assert_eq(engine.game_state().characteristics_of(engine.game_state().object(activate.object_id)).name, "Landcycler")


func test_a_landcycling_card_is_not_landcycled_in_its_own_main_phase() -> void:
	var engine: MmEngine = _engine_holding_a_cycler(3, Step.PRECOMBAT_MAIN, Scenario.landcycler())
	assert_not_null(engine, "No seed gave the Elves and hand.")
	if engine == null:
		return
	_cast_every(engine, "Elf")
	var landcycler: int = Scenario.card_in_hand(engine, engine.hero(), "Landcycler")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	var index: int = Scenario.activate_index(decision, landcycler)
	assert_ne(index, -1, "It could be landcycled.")
	if index == -1:
		return
	assert_eq(AiTiming.tag_of_action(engine.game_state(), decision.actions[index]), AiTiming.Tag.SPARE_MANA,
		"ADR 0059: it only searches into its owner's hand.")

	var answer: int = AiScenario.ask(engine, AiAgent.new())

	assert_false(AiScenario.action_at(engine, answer) is ActivateAbilityAction,
		"Its mana may yet cast something: landcycling waits for the other player's end step.")


## The Hero with two Elves, "{T}: Add {W}", on the battlefield, holding [param cycler]
## (by default Cycler, an instant costing {0}, "You gain 1 life", cycling {2}) and Ogre (a
## 5/5 costing {5}), with Forests in their library too when [param cycler] is given, at the
## first decision of [param step] in [param game_turn].
func _engine_holding_a_cycler(game_turn: int, step: Step, cycler: MmCardDefinition = null) -> MmEngine:
	var elves: Array[MmCardDefinition] = [Scenario.elf(), Scenario.elf()]
	var ogre: MmCardDefinition = Scenario.creature("Ogre", 5, 5)
	ogre.mana_cost = Scenario.mana_cost(5)
	var held: Array[MmCardDefinition] = [cycler if cycler != null else Scenario.cycler(), ogre]
	var no_cards: Array[MmCardDefinition] = []
	var in_library: Array[MmCardDefinition] = held.duplicate()
	if cycler != null:
		in_library.append(Scenario.basic_land("Forest"))
	var setup: MmEncounterSetup = Scenario.combat_setup(elves, no_cards, in_library)
	return Scenario.permanents_ready_with(setup, elves, no_cards, held, no_cards, game_turn, step)
