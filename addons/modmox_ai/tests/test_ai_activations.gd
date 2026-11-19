extends GutTest
## Activated abilities (ADR 0020): a keyword counts once, an ability is never activated on
## top of itself, a trick is judged after it has worn off, a Repeat Plan compares
## activating several times in a row, and evasion is considered before blockers.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const Tag := AiTiming.Tag


# --- Board Evaluator ---------------------------------------------------------------

func test_a_keyword_granted_twice_counts_once() -> void:
	var jump: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Jump",
		Scenario.gain_abilities([FlyingAbility.new()], Scenario.targeted(0)))
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("savannah_lions")], [], [jump])
	assert_not_null(engine)
	var lions: int = Scenario.permanent_named(engine, engine.hero().id, "Savannah Lions")
	assert_eq(Scenario.cast_and_resolve(engine, "Jump", [MmReference.to_object(lions)]), "")
	var once: int = AiBoardEvaluator.creature_value(engine.game_state(), engine.game_state().object(lions))

	assert_eq(Scenario.cast_and_resolve(engine, "Jump", [MmReference.to_object(lions)]), "")

	assert_eq(AiBoardEvaluator.creature_value(engine.game_state(), engine.game_state().object(lions)), once)


func test_two_different_activated_abilities_count_separately() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Plain", 1, 1),
		Scenario.creature("Tricky", 1, 1, [_free_pump(1, 1), _free_flying()])], [])
	assert_not_null(engine)
	var state: MmGameState = engine.game_state()

	var plain: int = AiBoardEvaluator.creature_value(state, state.object(Scenario.permanent_named(engine, engine.hero().id, "Plain")))
	var tricky: int = AiBoardEvaluator.creature_value(state, state.object(Scenario.permanent_named(engine, engine.hero().id, "Tricky")))

	assert_eq(tricky, plain + 20)


# --- Never on top of itself --------------------------------------------------------

func test_an_ability_is_not_activated_on_top_of_itself() -> void:
	for difficulty: AiDifficulty in [AiDifficulty.easy(), AiDifficulty.normal()]:
		var engine: MmEngine = _unblocked_attacker(Scenario.creature("Wraith", 1, 1, [_free_pump(1, 0)]))
		assert_not_null(engine)
		var wraith: int = Scenario.permanent_named(engine, engine.hero().id, "Wraith")
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)
		assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is ActivateAbilityAction, "More damage.")
		assert_eq(Scenario.activate(engine, wraith), "")
		assert_eq(engine.game_state().stack.objects().size(), 1)

		var play: int = AiScenario.ask(engine, agent)

		assert_true(AiScenario.action_at(engine, play) is PassAction, "Its own pump is on top of the stack.")


func test_an_ability_is_activated_again_once_it_has_resolved() -> void:
	var engine: MmEngine = _unblocked_attacker(Scenario.creature("Wraith", 1, 1, [_free_pump(1, 0)]))
	assert_not_null(engine)
	var wraith: int = Scenario.permanent_named(engine, engine.hero().id, "Wraith")
	assert_eq(Scenario.activate(engine, wraith), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.pending_decision().player_id, engine.hero().id)

	var play: int = AiScenario.ask(engine, AiAgent.new())

	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction)


func test_an_ability_is_activated_again_under_the_other_players_spell() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Wraith", 1, 1, [_free_pump(1, 1)])], [], [],
		[Scenario.free_shock("Zap", 1)])
	assert_not_null(engine)
	var wraith: int = Scenario.permanent_named(engine, engine.hero().id, "Wraith")
	assert_eq(Scenario.activate(engine, wraith), "")
	assert_eq(Scenario.pass_priority(engine), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Zap"), [MmReference.to_object(wraith)]), "")
	assert_eq(Scenario.pass_priority(engine), "", "The Villain keeps priority after casting.")
	assert_eq(engine.pending_decision().player_id, engine.hero().id)

	var play: int = AiScenario.ask(engine, AiAgent.new())

	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction, "The Zap is on top, and one more pump survives it.")


# --- Tricks are judged after they wear off -----------------------------------------

func test_flying_is_not_gained_once_blockers_are_declared() -> void:
	var engine: MmEngine = _unblocked_attacker(AiScenario.free_alpha("goblin_balloon_brigade"), AiScenario.alpha("mountain"))
	assert_not_null(engine)

	var normal: int = AiScenario.ask(engine, AiAgent.new())
	var easy: int = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))

	assert_true(AiScenario.action_at(engine, normal) is PassAction, "Nothing lasting changes.")
	assert_true(AiScenario.action_at(engine, easy) is ActivateAbilityAction, "Easy still counts the flying it has now.")


func test_a_creature_out_of_the_fight_is_not_pumped() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("frozen_shade"), AiScenario.free_alpha("grizzly_bears")],
		[], [AiScenario.alpha("swamp")])
	assert_not_null(engine)
	Scenario.play_first_land(engine)
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	engine.submit([Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")])
	_pass_to_hero_after_blocks(engine)

	var normal: int = AiScenario.ask(engine, AiAgent.new())
	var easy: int = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))

	assert_true(AiScenario.action_at(engine, normal) is PassAction, "The Shade is not attacking.")
	assert_true(AiScenario.action_at(engine, easy) is ActivateAbilityAction, "Easy still counts the pump it has now.")


func test_an_unblocked_attacker_is_pumped() -> void:
	var engine: MmEngine = _unblocked_attacker(AiScenario.free_alpha("shivan_dragon"), AiScenario.alpha("mountain"))
	assert_not_null(engine)

	var play: int = AiScenario.ask(engine, AiAgent.new())

	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction, "One more damage lasts.")


func test_a_pump_is_skipped_when_its_mana_would_cast_a_creature() -> void:
	var recruit: MmCardDefinition = Scenario.creature("Recruit", 2, 2, [], Scenario.mana_cost(0, [MmMana.Type.BLACK]))
	var engine: MmEngine = _unblocked_attacker(AiScenario.free_alpha("frozen_shade"), AiScenario.alpha("swamp"), [recruit])
	assert_not_null(engine)

	var normal: int = AiScenario.ask(engine, AiAgent.new())
	var easy: int = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))

	assert_true(AiScenario.action_at(engine, normal) is PassAction, "The Swamp casts the Recruit after combat.")
	assert_true(AiScenario.action_at(engine, easy) is ActivateAbilityAction, "Easy does not look past combat.")


# --- Repeat Plans ------------------------------------------------------------------

func test_a_repeat_plan_pumps_just_enough_to_win_the_fight() -> void:
	var engine: MmEngine = _blocked_attacker(Scenario.creature("Wraith", 0, 1, [_free_pump(1, 1)]))
	assert_not_null(engine)
	var hero: int = engine.hero().id
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction, "Two pumps kill the Bears and survive them.")
	assert_eq(agent.repeat_count(), 2, "Eight are possible; two are enough.")
	assert_eq(agent.explain(), AiAgent.Reason.ROLLOUT_SCORE, "The rollouts played the whole plan.")
	engine.submit(play)
	assert_eq(engine.game_state().stack.objects().size(), 1, "Only the first activation is submitted.")
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PassAction, "Not on top of itself.")
	Scenario.resolve_stack(engine)

	play = AiScenario.ask(engine, agent)
	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction, "One more is still needed.")
	assert_eq(agent.repeat_count(), 1)
	engine.submit(play)
	Scenario.resolve_stack(engine)

	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PassAction, "A third pump changes nothing.")
	assert_eq(Scenario.pt(engine, Scenario.permanent_named(engine, hero, "Wraith")), [2, 3])


func test_no_plan_is_made_when_no_count_wins_the_fight() -> void:
	var engine: MmEngine = _blocked_attacker(AiScenario.free_alpha("frozen_shade"), AiScenario.alpha("swamp"))
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is PassAction, "One Swamp pays for one pump, and a 1/2 still dies.")


func test_a_free_ability_is_planned_at_most_eight_times() -> void:
	var engine: MmEngine = _unblocked_attacker(Scenario.creature("Wraith", 1, 1, [_free_pump(1, 0)]))
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction)
	assert_eq(agent.repeat_count(), 8, "Every pump is more damage, and eight is the most a plan may hold.")


func test_an_ability_that_taps_is_planned_once() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("prodigal_sorcerer")],
		[AiScenario.free_alpha("savannah_lions")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction, "One damage kills the Lions.")
	assert_eq(agent.repeat_count(), 1, "The engine does not offer it again once the Sorcerer is tapped.")


func test_a_difficulty_can_turn_repeat_plans_off() -> void:
	var engine: MmEngine = _blocked_attacker(Scenario.creature("Wraith", 0, 1, [_free_pump(1, 1)]))
	assert_not_null(engine)
	var difficulty: AiDifficulty = AiDifficulty.normal()
	difficulty.repeat_plan_length = 1
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is PassAction, "One pump alone changes nothing.")


func test_easy_judges_tricks_now_and_makes_no_repeat_plans() -> void:
	assert_false(AiDifficulty.easy().judges_tricks_after_the_turn)
	assert_eq(AiDifficulty.easy().repeat_plan_length, 1)
	assert_true(AiDifficulty.normal().judges_tricks_after_the_turn)
	assert_eq(AiDifficulty.normal().repeat_plan_length, 8)
	assert_eq(AiDifficulty.hard().repeat_plan_length, 8)


# --- Evasion -----------------------------------------------------------------------

func test_a_trick_that_only_grants_abilities_is_evasion() -> void:
	var grant: MmEffect = Scenario.until_end_of_turn(Scenario.gain_abilities([FlyingAbility.new()], SourceSelection.new()))
	var pump: MmEffect = Scenario.until_end_of_turn(Scenario.modify_pt(1, 1, SourceSelection.new()))
	var brigade: ActivatedAbility = AiScenario.alpha("goblin_balloon_brigade").abilities[0] as ActivatedAbility
	var growth: SpellAbility = AiScenario.alpha("giant_growth").abilities[0] as SpellAbility

	assert_eq(AiTiming.tag_of_effects(brigade.effects), Tag.EVASION)
	assert_eq(AiTiming.tag_of_effects(growth.effects), Tag.COMBAT_TRICK)
	assert_eq(AiTiming.tag_of_effects([grant, pump]), Tag.COMBAT_TRICK, "It also pumps, so it waits for blockers.")


func test_an_attacker_gains_flying_before_blockers_to_get_through() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("goblin_balloon_brigade")],
		[AiScenario.free_alpha("grizzly_bears")], [AiScenario.alpha("mountain")])
	assert_not_null(engine)
	Scenario.play_first_land(engine)
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	engine.submit([Scenario.permanent_named(engine, engine.hero().id, "Goblin Balloon Brigade")])
	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.game_state().step, Step.DECLARE_ATTACKERS)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction, "The Bears cannot block a flyer.")
	engine.submit(play)
	_let_agents_finish_combat(engine)
	assert_eq(engine.villain().life, 19)


func test_a_defender_gains_flying_to_block_a_flyer() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Sprite", 1, 1, [FlyingAbility.new()])],
		[Scenario.creature("Balloonist", 1, 2, [_free_flying()])], [], [], Step.DECLARE_ATTACKERS)
	assert_not_null(engine)
	var sprite: int = Scenario.permanent_named(engine, engine.hero().id, "Sprite")
	engine.submit([sprite])
	AiScenario.pass_to(engine, engine.villain().id, PriorityDecision)
	assert_eq(engine.game_state().step, Step.DECLARE_ATTACKERS)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is ActivateAbilityAction, "With flying it can block the Sprite.")
	engine.submit(play)
	_let_agents_finish_combat(engine)
	assert_eq(engine.villain().life, 20)
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Sprite").size(), 0, "Blocked and killed.")


func test_a_pump_is_still_held_until_blockers_are_declared() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("grizzly_bears")], [AiScenario.free_alpha("hill_giant")],
		[AiScenario.free_alpha("giant_growth")], [], Step.DECLARE_ATTACKERS)
	assert_not_null(engine)
	engine.submit([Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")])
	assert_eq(engine.game_state().step, Step.DECLARE_ATTACKERS)
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, play) is PassAction)
	assert_eq(agent.explain(), AiAgent.Reason.WAIT_FOR_COMBAT)


# --- Support -----------------------------------------------------------------------

## "{0}: This creature gets +[param power]/+[param toughness] until end of turn."
func _free_pump(power: int, toughness: int) -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.effects = [Scenario.until_end_of_turn(Scenario.modify_pt(power, toughness, SourceSelection.new()))]
	return ability


## "{0}: This creature gains flying until end of turn."
func _free_flying() -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.effects = [Scenario.until_end_of_turn(Scenario.gain_abilities([FlyingAbility.new()], SourceSelection.new()))]
	return ability


## The Hero attacking a Villain with no creatures with [param attacker], after playing
## [param land] if given and holding [param extras], stopped at the Hero's priority once
## blockers are declared.
func _unblocked_attacker(attacker: MmCardDefinition, land: MmCardDefinition = null,
		extras: Array[MmCardDefinition] = []) -> MmEngine:
	return _attack(attacker, [], land, extras)


## Like _unblocked_attacker(), but a Villain's Grizzly Bears blocks.
func _blocked_attacker(attacker: MmCardDefinition, land: MmCardDefinition = null) -> MmEngine:
	return _attack(attacker, [AiScenario.free_alpha("grizzly_bears")], land, [])


func _attack(attacker: MmCardDefinition, blockers: Array[MmCardDefinition], land: MmCardDefinition,
		extras: Array[MmCardDefinition]) -> MmEngine:
	var held: Array[MmCardDefinition] = extras.duplicate()
	if land != null:
		held.append(land)
	var engine: MmEngine = AiScenario.ready_with([attacker], blockers, held)
	if engine == null:
		return null
	if land != null:
		Scenario.play_first_land(engine)
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	var attacker_id: int = Scenario.permanent_named(engine, engine.hero().id, attacker.name)
	engine.submit([attacker_id])
	if not blockers.is_empty():
		Scenario.pass_to_blockers(engine)
		engine.submit([[Scenario.permanent_named(engine, engine.villain().id, blockers[0].name), attacker_id]])
	_pass_to_hero_after_blocks(engine)
	return engine


func _pass_to_hero_after_blocks(engine: MmEngine) -> void:
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.game_state().step == Step.DECLARE_BLOCKERS and running.pending_decision() is PriorityDecision \
			and running.pending_decision().player_id == running.hero().id)


## Both players' Agents play on until combat is over.
func _let_agents_finish_combat(engine: MmEngine) -> void:
	var agents: Dictionary[int, MmAgent] = {0: AiAgent.new(), 1: AiAgent.new()}
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, agents)
	driver.run_until(func(running: MmEngine) -> bool:
		return not AiTiming.COMBAT_STEPS.has(running.game_state().step))


# --- Emblems (ADR 0036) --------------------------------------------------------------

func test_an_emblem_ability_is_activated_at_the_other_player_for_lethal() -> void:
	for difficulty: AiDifficulty in [AiDifficulty.easy(), AiDifficulty.normal()]:
		var engine: MmEngine = _with_electromancers_boon(3)
		assert_not_null(engine)
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		var play: MmAction = AiScenario.action_at(engine, AiScenario.ask(engine, agent))

		assert_true(play is ActivateAbilityAction, "3 damage wins the game.")
		assert_eq((play as ActivateAbilityAction).object_id, engine.view_for(engine.hero()).command[0].id)
		assert_eq(AiScenario.let_answer(engine, agent), "")
		var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))
		assert_true(target.is_player() and target.id == engine.villain().id)


func test_a_spent_emblem_ability_is_not_asked_for_again() -> void:
	var engine: MmEngine = _with_electromancers_boon(20)
	assert_not_null(engine)
	var emblem: int = engine.view_for(engine.hero()).command[0].id
	assert_eq(Scenario.activate(engine, emblem, [MmReference.to_player(engine.villain().id)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var play: MmAction = AiScenario.action_at(engine, AiScenario.ask(engine, AiAgent.new()))

	assert_true(play is PassAction, "Nothing else to do, and the Simulation Copy knows it is spent.")


## The Hero in their second main phase with "{0}: This emblem deals 3 damage to any target.
## Activate only once each game." and nothing else, against a Villain at
## [param villain_life].
func _with_electromancers_boon(villain_life: int) -> MmEngine:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.mana_cost = Scenario.mana_cost(0)
	ability.targets = [Scenario.any_target()]
	ability.effects = [Scenario.deal_damage(3, Scenario.targeted(0))]
	ability.is_once_each_game = true
	var setup: MmEncounterSetup = Scenario.combat_setup([], [])
	setup.hero.emblems = [Scenario.emblem("Electromancer's Boon", [ability])]
	setup.villain.starting_life = villain_life
	return Scenario.permanents_ready_with(setup, [], [], [], [], 3, Step.PRECOMBAT_MAIN)


func test_the_authored_electromancers_boon_is_paid_for_and_aimed_for_lethal() -> void:
	var setup: MmEncounterSetup = Scenario.setup_with(
		Scenario.cycled([Scenario.mana_land("Mountain", MmMana.Type.RED, 1)]), Scenario.cycled([]))
	setup.hero.emblems = [load("res://content/emblems/electromancers_boon.tres")] as Array[MmCardDefinition]
	setup.villain.starting_life = 3
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var agent: AiAgent = AiAgent.new()
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PlayLandAction, "It needs {R} first.")
	assert_eq(AiScenario.let_answer(engine, agent), "")

	for decision: int in 6:
		if engine.is_over():
			break
		assert_eq(AiScenario.let_answer(engine, agent), "")

	assert_true(engine.is_over(), "It activated the Boon at the Villain, paid {R} and won.")
	assert_eq(engine.outcome(), MmEngine.Outcome.HERO_WON)
	assert_eq(Scenario.events_of(engine, AbilitySpentEvent).size(), 1)


# --- Equipment ---------------------------------------------------------------------

func test_an_equipment_is_equipped_to_a_creature() -> void:
	# An attach effect has the Timing Tag NONE, so it is weighed in the main phase, and the
	# Board Evaluator sees the bigger creature. The hand holds more free copies, which are
	# worth more to cast first, so the Agent plays its whole main phase.
	for difficulty: AiDifficulty in [AiDifficulty.easy(), AiDifficulty.normal()]:
		var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), Scenario.sword("Sword")], [])
		assert_not_null(engine)
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		_let_play_the_main_phase(engine, agent)

		var equipped: int = 0
		for sword: int in Scenario.permanents_named(engine, engine.hero().id, "Sword"):
			equipped += 1 if Scenario.attached_to(engine, sword) != 0 else 0
		assert_gt(equipped, 0, "It equips rather than leaving every Sword loose.")


func test_an_equipment_is_not_equipped_again_to_the_creature_it_is_on() -> void:
	# CR 701.3b: that would change nothing, so it is never worth the activation.
	for difficulty: AiDifficulty in [AiDifficulty.easy(), AiDifficulty.normal()]:
		var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), Scenario.sword("Sword")], [])
		assert_not_null(engine)
		var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
		assert_eq(Scenario.equip_and_resolve(engine, sword, Scenario.permanent_named(engine, engine.hero().id, "Bear")), "")
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		var action: ActivateAbilityAction = AiScenario.action_at(engine, AiScenario.ask(engine, agent)) as ActivateAbilityAction

		assert_true(action == null or action.object_id != sword, "Nothing to gain from equipping the same creature.")


func test_an_equipment_goes_on_the_creature_that_gains_most_from_being_equipped() -> void:
	# Sunspear Shikari: "As long as this creature is equipped, it has first strike and
	# lifelink." The Board Evaluator reads its abilities from the layers, so it sees an
	# equipped Shikari as a 3/3 with both, and an equipped Bear as a vanilla 3/3.
	for difficulty: AiDifficulty in [AiDifficulty.easy(), AiDifficulty.normal()]:
		var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), Scenario.shikari(), Scenario.sword("Sword")], [])
		assert_not_null(engine)
		var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
		var shikari: int = Scenario.permanent_named(engine, engine.hero().id, "Shikari")
		assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword)), "")
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

		assert_eq(target.id, shikari, "Equipped, it also has first strike and lifelink.")


func test_an_instant_speed_equip_is_a_combat_trick_outside_sorcery_timing() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), _leonin(), Scenario.sword("Sword")], [])
	assert_not_null(engine)
	var action: ActivateAbilityAction = ActivateAbilityAction.new(Scenario.permanent_named(engine, engine.hero().id, "Sword"), 1)

	assert_eq(AiTiming.tag_of_action(engine.game_state(), action), Tag.NONE, "In its main phase, as any equip.")
	Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
	assert_eq(AiTiming.tag_of_action(engine.game_state(), action), Tag.COMBAT_TRICK)


func test_a_blocked_attacker_is_equipped_at_instant_speed_to_win_its_fight() -> void:
	# Leonin Shikari: "You may activate equip abilities any time you could cast an instant."
	# Once blockers are declared, the Sword makes the Bear a 3/3 that kills its blocker and
	# lives.
	for difficulty: AiDifficulty in [AiDifficulty.easy(), AiDifficulty.normal()]:
		var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), _leonin(), Scenario.sword("Sword")],
			[AiScenario.free_alpha("grizzly_bears")])
		assert_not_null(engine)
		var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
		Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS)
		engine.submit([bear])
		Scenario.pass_to_blockers(engine)
		engine.submit([[Scenario.permanent_named(engine, engine.villain().id, "Grizzly Bears"), bear]])
		_pass_to_hero_after_blocks(engine)
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		var action: ActivateAbilityAction = AiScenario.action_at(engine, AiScenario.ask(engine, agent)) as ActivateAbilityAction

		assert_not_null(action, "It equips after blocks.")
		assert_eq(action.object_id if action != null else 0, Scenario.permanent_named(engine, engine.hero().id, "Sword"))


func test_an_instant_speed_equip_is_held_in_the_other_players_upkeep() -> void:
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), _leonin(), Scenario.sword("Sword")], [])
	assert_not_null(engine)
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		var pending: PriorityDecision = running.pending_decision() as PriorityDecision
		return pending != null and pending.player_id == running.hero().id and running.game_state().step == Step.UPKEEP \
			and running.game_state().active_player_id != running.hero().id)
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword), -1, "Equip is offered.")

	var play: int = AiScenario.ask(engine, AiAgent.new())

	assert_true(AiScenario.action_at(engine, play) is PassAction, "Nothing is fighting yet.")


func test_an_equipment_with_reconfigure_is_attached_when_its_bonus_is_worth_more_than_its_body() -> void:
	# Reconfigure's attach has the Timing Tag NONE, as equip does, and simulation weighs a
	# 1/1 body against +3/+3 on the Bear.
	for difficulty: AiDifficulty in [AiDifficulty.easy(), AiDifficulty.normal()]:
		var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), Scenario.sash("Sash", 3)], [])
		assert_not_null(engine)
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		_let_play_the_main_phase(engine, agent)

		var attached: int = 0
		for sash: int in Scenario.permanents_named(engine, engine.hero().id, "Sash"):
			attached += 1 if Scenario.attached_to(engine, sash) != 0 else 0
		assert_gt(attached, 0, "It reconfigures a Sash onto a creature.")


func test_an_equipment_with_reconfigure_is_not_unattached_again_in_the_same_main_phase() -> void:
	# Unattaching only undoes what was paid for: no score gains from it.
	for difficulty: AiDifficulty in [AiDifficulty.easy(), AiDifficulty.normal()]:
		var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), Scenario.sash("Sash", 3)], [])
		assert_not_null(engine)
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		_let_play_the_main_phase(engine, agent)

		assert_gt(Scenario.events_of(engine, AttachedEvent).size(), 0, "It reconfigured.")
		assert_eq(Scenario.events_of(engine, UnattachedEvent).size(), 0)


func test_lion_sash_s_bonus_from_its_counters_is_valued_on_the_creature_it_is_attached_to() -> void:
	# "Equipped creature gets +X/+X, where X is the number of +1/+1 counters on this
	# permanent": the Board Evaluator reads power and toughness from the layers, which count
	# them. With one other creature, a 4/4 Sash and a 2/2 are worth more than a 5/5, so the
	# Agent is not made to reconfigure here.
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2), Scenario.lion_sash()], [],
		[Scenario.free_counters("Grow", MmCounter.Kind.PLUS_ONE_PLUS_ONE, 3)])
	assert_not_null(engine)
	var sash: int = Scenario.permanent_named(engine, engine.hero().id, "Lion Sash")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(sash)]), "")
	var loose: int = AiBoardEvaluator.creature_value(engine.game_state(), engine.game_state().object(bear))

	assert_eq(Scenario.equip_and_resolve(engine, sash, bear), "")

	var equipped: int = AiBoardEvaluator.creature_value(engine.game_state(), engine.game_state().object(bear))
	assert_eq(equipped - loose, 25 * 3, "+3/+3 at 15 a power and 10 a toughness.")


# --- Exiling from graveyards ------------------------------------------------------------

func test_exiling_a_card_from_a_graveyard_is_removal() -> void:
	# Considered in its main phases, after blocks, in response and in the other player's end
	# step, where Lion Sash's {W} would otherwise go unused.
	var engine: MmEngine = _graveyards_filled()
	var action: ActivateAbilityAction = ActivateAbilityAction.new(Scenario.permanent_named(engine, engine.hero().id, "Scavenger"), 0)

	assert_eq(AiTiming.tag_of_action(engine.game_state(), action), Tag.REMOVAL)


func test_a_permanent_card_in_the_other_players_graveyard_is_exiled_for_its_counter() -> void:
	# Only the Ogre card is a permanent card: the Doom and the Shock give no counter.
	for mode: AiAgent.Mode in [AiAgent.Mode.FULL, AiAgent.Mode.CHEAP]:
		var engine: MmEngine = _graveyards_filled()
		var scavenger: int = Scenario.permanent_named(engine, engine.hero().id, "Scavenger")
		assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, scavenger)), "")
		var agent: AiAgent = AiAgent.new(null, mode)

		var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, agent))

		assert_eq(target.id, Scenario.card_in_graveyard(engine, engine.villain(), "Ogre"))


## The Hero's main phase with a Scavenger (Lion Sash's first ability at {0}) on the
## battlefield, a Doom and a Shock in the Hero's graveyard and an Ogre in the Villain's.
func _graveyards_filled() -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with([Scenario.scavenger()], [Scenario.creature("Ogre", 2, 2)],
		[Scenario.free_destroy("Doom"), Scenario.free_shock("Shock", 2)])
	assert_not_null(engine)
	assert_eq(Scenario.cast_and_resolve(engine, "Doom",
		[MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Ogre"))]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.villain().id)]), "")
	return engine


## Leonin Shikari: a 2/2 with "You may activate equip abilities any time you could cast an
## instant."
func _leonin() -> MmCardDefinition:
	return Scenario.creature("Leonin", 2, 2, [Scenario.instant_speed_equip()])


## Lets [param agent] answer every decision of the Hero's until the precombat main phase of
## this Game Turn is over.
func _let_play_the_main_phase(engine: MmEngine, agent: AiAgent) -> void:
	var game_turn: int = engine.game_state().game_turn
	for _answer: int in 80:
		var state: MmGameState = engine.game_state()
		var pending: MmPendingDecision = engine.pending_decision()
		if pending == null or state.game_turn != game_turn or state.step != Step.PRECOMBAT_MAIN:
			return
		if pending.player_id == engine.hero().id:
			assert_eq(AiScenario.let_answer(engine, agent), "")
		else:
			engine.submit(Scenario.default_answer(pending))
