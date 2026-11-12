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
