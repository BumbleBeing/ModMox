extends GutTest
## Countering (milestone 13d): a FULL Agent weighs a counter against letting the spell
## resolve, by simulation, so a counter is worth what the spell would have done. A CHEAP
## Agent counters by cost alone. Neither knows any card's name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Tag := AiTiming.Tag


func test_a_counter_is_tagged_from_its_effect() -> void:
	var counter: MmCardDefinition = Scenario.free_counter("Counter")

	assert_eq(AiTiming.tag_of_effects((counter.abilities[0] as SpellAbility).effects), Tag.COUNTER)


func test_a_spell_that_would_hurt_is_countered() -> void:
	var engine: MmEngine = _villain_facing(AiScenario.free_alpha("craw_wurm"), Scenario.free_counter("Counter"))
	var agent: AiAgent = AiAgent.new()

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Counter")
	engine.submit(play)
	Scenario.resolve_stack(engine)
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Craw Wurm"), [] as Array[int])


func test_a_harmless_spell_is_let_through() -> void:
	# One life is worth less than the card the counter is (A179).
	var sip: MmCardDefinition = Scenario.instant("Sip", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var engine: MmEngine = _villain_facing(sip, Scenario.free_counter("Counter"))
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Counter")))
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, AiAgent.new())) is PassAction)
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, easy)) is PassAction)
	assert_eq(easy.explain(), AiAgent.Reason.SCORES_WORSE_THAN_PASS)


func test_its_own_spell_is_not_looked_at_for_countering() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [], [AiScenario.free_alpha("craw_wurm"), Scenario.free_counter("Counter")])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Craw Wurm"))
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Counter")))
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, easy)) is PassAction)
	assert_eq(easy.explain(), AiAgent.Reason.NOTHING_WORTH_DOING, "Outside its window, so never simulated.")


func test_a_cheap_agent_counters_a_spell_that_costs_at_least_as_much() -> void:
	var engine: MmEngine = _villain_facing(AiScenario.free_alpha("craw_wurm"), Scenario.free_counter("Counter"))
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var play: int = AiScenario.ask(engine, cheap)

	assert_eq(AiScenario.cast_name(engine, play), "Counter")


func test_a_cheap_agent_keeps_a_counter_that_costs_more_than_the_spell() -> void:
	var dear: MmCardDefinition = Scenario.instant("Counter", Scenario.mana_cost(1), [Scenario.target_spell()], [Scenario.counter(Scenario.targeted(0))])
	var engine: MmEngine = AiScenario.ready_with([], [], [Scenario.free_shock("Shock", 2), dear, Scenario.basic_land("Island")],
		[Scenario.free_shock("Jolt", 2)])
	var hero: MmPlayer = engine.hero()
	Scenario.play_first_land(engine)
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(engine.villain().id)])
	Scenario.pass_priority(engine)
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Jolt"), [MmReference.to_player(hero.id)])
	Scenario.pass_priority(engine)
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, hero, "Counter")), "It could pay.")
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, cheap)) is PassAction)


func test_a_cheap_agent_aims_a_counter_at_the_other_players_spell() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [], [Scenario.free_shock("Shock", 2), Scenario.free_counter("Counter")],
		[Scenario.free_shock("Jolt", 2)])
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(engine.villain().id)])
	Scenario.pass_priority(engine)
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Jolt"), [MmReference.to_player(hero.id)])
	Scenario.pass_priority(engine)
	var jolt: int = Scenario.stack_ids(engine)[0]
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, hero, "Counter")))
	assert_eq((engine.pending_decision() as ChooseTargetDecision).candidates.size(), 2)

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)))

	assert_eq(target.id, jolt)


func test_a_counter_is_considered_only_with_the_other_players_spell_on_top() -> void:
	var engine: MmEngine = _hero_facing_a_response()
	var state: MmGameState = engine.game_state()

	assert_true(AiTiming.is_in_window(state, engine.hero().id, Tag.COUNTER), "The Villain's Jolt is on top of the Hero's Shock.")
	assert_false(AiTiming.is_in_window(state, engine.villain().id, Tag.COUNTER), "Its own Jolt is on top.")


func test_a_counter_is_not_a_combat_trick() -> void:
	var engine: MmEngine = AiScenario.ready_with([AiScenario.free_alpha("grizzly_bears")], [], [], [], MmTurn.Step.DECLARE_ATTACKERS)
	engine.submit([Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")])
	Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.game_state().step == MmTurn.Step.DECLARE_BLOCKERS and running.pending_decision() is PriorityDecision)
	var state: MmGameState = engine.game_state()

	assert_true(AiTiming.is_in_window(state, engine.villain().id, Tag.COMBAT_TRICK))
	assert_false(AiTiming.is_in_window(state, engine.villain().id, Tag.COUNTER), "Nothing of the other player's is on the stack.")


func test_a_cheap_agent_counters_a_response_to_its_own_spell() -> void:
	var engine: MmEngine = _hero_facing_a_response()

	var play: int = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))

	assert_eq(AiScenario.cast_name(engine, play), "Counter", "The top of the stack is the Villain's, whatever lies under it.")


func test_a_cheap_agent_leaves_its_own_spell_alone() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [], [AiScenario.free_alpha("craw_wurm"), Scenario.free_counter("Counter")])
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Craw Wurm"))

	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Counter")))
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))) is PassAction)


func test_a_cheap_agent_aims_a_counter_at_the_spell_that_cost_the_most() -> void:
	var bolt: MmCardDefinition = Scenario.instant("Bolt", Scenario.mana_cost(1), [Scenario.target_player()],
		[Scenario.deal_damage(3, Scenario.targeted(0))])
	var setup: MmEncounterSetup = Scenario.setup_with(
		Scenario.cycled([Scenario.basic_land("Mountain"), bolt, AiScenario.free_alpha("craw_wurm")]),
		Scenario.cycled([Scenario.free_counter("Counter")]))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 1, 1, "Bolt"):
			return false
		return Scenario.card_in_hand(running, running.hero(), "Craw Wurm") != -1)
	assert_not_null(engine, "No seed gave the needed hand.")
	var hero: MmPlayer = engine.hero()
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Craw Wurm")), "")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Bolt"), [MmReference.to_player(engine.villain().id)]), "")
	var on_stack: Array[int] = Scenario.stack_ids(engine)
	Scenario.pass_priority(engine)
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.villain(), "Counter")))
	assert_eq((engine.pending_decision() as ChooseTargetDecision).candidates.size(), 2)

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)))

	assert_eq(target.id, on_stack[0], "The Bolt cost {1}; the free Craw Wurm is the better creature, but that is not what it goes by.")


## The Hero, holding a free Counter, has priority with the Villain's Jolt on top of the
## Hero's own Shock.
func _hero_facing_a_response() -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with([], [], [Scenario.free_shock("Shock", 2), Scenario.free_counter("Counter")],
		[Scenario.free_shock("Jolt", 2)])
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(engine.villain().id)])
	Scenario.pass_priority(engine)
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Jolt"), [MmReference.to_player(hero.id)])
	Scenario.pass_priority(engine)
	return engine


## The Hero has cast [param spell] and passed, so the Villain, holding [param counter],
## has priority with it on the stack. Each held exactly one copy, among lands, so neither
## play-out can simply do the same again with the next copy.
func _villain_facing(spell: MmCardDefinition, counter: MmCardDefinition) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.deck_of(Scenario.basic_land("Forest"), 32, spell, 8),
		Scenario.deck_of(Scenario.basic_land("Island"), 32, counter, 8))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 3, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		return Scenario.names(running, running.hero().hand).count(spell.name) == 1 \
			and Scenario.names(running, running.villain().hand).count(counter.name) == 1)
	assert_not_null(engine, "No seed gave the needed hands.")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), spell.name))
	Scenario.pass_priority(engine)
	return engine
