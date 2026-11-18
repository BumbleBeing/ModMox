extends GutTest
## Milestone 13f: returning a card from a graveyard and countering an ability. A FULL
## Agent weighs both by simulation like any other play. A CHEAP Agent casts the first in
## its own main phase, at its best creature card, and never casts the second, because what
## an ability would do cannot be read from its cost. Neither knows any card's name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Tag := AiTiming.Tag


func test_returning_a_card_is_considered_whenever_it_may_be_cast() -> void:
	var raise: MmCardDefinition = Scenario.free_raise("Raise")

	assert_eq(AiTiming.tag_of_effects((raise.abilities[0] as SpellAbility).effects), Tag.NONE)


func test_a_cheap_agent_raises_its_best_creature_card_in_its_own_main_phase() -> void:
	var engine: MmEngine = _hero_with_two_dead_creatures()
	var hero: MmPlayer = engine.hero()
	var cheap: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	var play: int = AiScenario.ask(engine, cheap)

	assert_eq(AiScenario.cast_name(engine, play), "Raise", "It costs the most of what it could cast.")
	engine.submit(play)
	assert_eq((engine.pending_decision() as ChooseTargetDecision).candidates.size(), 2)
	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, cheap))
	assert_eq(target.id, Scenario.card_in_graveyard(engine, hero, "Giant"), "Not the Runt.")


func test_a_full_agent_chooses_a_graveyard_target_by_simulation() -> void:
	var engine: MmEngine = _hero_with_two_dead_creatures()
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, engine.hero(), "Raise")))
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	var answer: int = AiScenario.ask(engine, easy)

	assert_between(answer, 0, 1)
	assert_eq(easy.explain(), AiAgent.Reason.BEST_SCORE)
	assert_eq(engine.submit(answer), "")


func test_countering_an_ability_is_tagged_as_a_counter() -> void:
	var stifle: MmCardDefinition = Scenario.free_stifle("Stifle")

	assert_eq(AiTiming.tag_of_effects((stifle.abilities[0] as SpellAbility).effects), Tag.COUNTER)


func test_an_ability_that_would_kill_it_is_countered() -> void:
	var engine: MmEngine = AiScenario.ready_with([_cannon()], [], [], [Scenario.free_stifle("Stifle")],
		MmTurn.Step.PRECOMBAT_MAIN, 5)
	var hero: MmPlayer = engine.hero()
	Scenario.activate(engine, Scenario.permanent_named(engine, hero.id, "Cannon"), [MmReference.to_player(engine.villain().id)])
	Scenario.pass_priority(engine)

	var play: int = AiScenario.ask(engine, AiAgent.new())

	assert_eq(AiScenario.cast_name(engine, play), "Stifle")
	engine.submit(play)
	Scenario.resolve_stack(engine)
	assert_eq(engine.villain().life, 5, "The Cannon never fired.")


func test_its_own_ability_is_not_looked_at_for_countering() -> void:
	var engine: MmEngine = AiScenario.ready_with([_cannon()], [], [Scenario.free_stifle("Stifle")])
	var hero: MmPlayer = engine.hero()
	Scenario.activate(engine, Scenario.permanent_named(engine, hero.id, "Cannon"), [MmReference.to_player(engine.villain().id)])
	var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, hero, "Stifle")))
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, easy)) is PassAction)
	assert_eq(easy.explain(), AiAgent.Reason.NOTHING_WORTH_DOING, "Outside its window, so never simulated.")


func test_a_cheap_agent_never_counters_an_ability() -> void:
	var engine: MmEngine = _hero_facing_the_villains_ability()
	var hero: MmPlayer = engine.hero()

	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, hero, "Stifle")), "It could.")
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))) is PassAction)


func test_a_cheap_agent_does_not_aim_an_ability_counter_at_a_spell() -> void:
	var engine: MmEngine = AiScenario.ready_with([], [_fount()],
		[Scenario.free_stifle("Stifle"), Scenario.free_shock("Shock", 2)], [Scenario.free_shock("Jolt", 2)])
	var hero: MmPlayer = engine.hero()
	var villain: MmPlayer = engine.villain()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(villain.id)])
	Scenario.pass_priority(engine)
	Scenario.activate(engine, Scenario.permanent_named(engine, villain.id, "Fount"), [MmReference.to_player(villain.id)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, villain, "Jolt"), [MmReference.to_player(hero.id)])
	Scenario.pass_priority(engine)

	assert_true((engine.game_state().stack.objects().back() as MmGameObject).is_card(), "The Villain's Jolt is on top of its ability.")
	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, hero, "Stifle")))
	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))) is PassAction,
		"The Stifle cannot counter the Jolt, whatever each costs.")


func test_a_cheap_agent_asked_to_aim_one_takes_the_other_players_ability() -> void:
	var engine: MmEngine = _hero_facing_the_villains_ability()
	var hero: MmPlayer = engine.hero()
	var theirs: int = Scenario.stack_ids(engine)[0]
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, hero, "Stifle")))
	assert_eq((engine.pending_decision() as ChooseTargetDecision).candidates.size(), 2)

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)))

	assert_eq(target.id, theirs)


## An artifact costing {0}: "{T}: This artifact deals 5 damage to any target."
func _cannon() -> MmCardDefinition:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.any_target()]
	ability.effects = [Scenario.deal_damage(5, Scenario.targeted(0))]
	return Scenario.artifact("Cannon", [ability])


## An artifact costing {0}: "{T}: Target player gains 1 life."
func _fount() -> MmCardDefinition:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.target_player()]
	ability.effects = [Scenario.gain_life(1, Scenario.targeted(0))]
	return Scenario.artifact("Fount", [ability])


## The Hero holding priority with the Villain's Fount ability on top of the Hero's own
## Cannon ability, and a free Stifle and Shock in hand; the Villain holds a free Jolt.
func _hero_facing_the_villains_ability() -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with([_cannon()], [_fount()],
		[Scenario.free_stifle("Stifle"), Scenario.free_shock("Shock", 2)], [Scenario.free_shock("Jolt", 2)])
	var hero: MmPlayer = engine.hero()
	var villain: MmPlayer = engine.villain()
	Scenario.activate(engine, Scenario.permanent_named(engine, hero.id, "Cannon"), [MmReference.to_player(villain.id)])
	Scenario.pass_priority(engine)
	Scenario.activate(engine, Scenario.permanent_named(engine, villain.id, "Fount"), [MmReference.to_player(villain.id)])
	Scenario.pass_priority(engine)
	return engine


## The Hero in their main phase on Game Turn 3 with a land, a Giant (5/5) and a Runt (1/1)
## in their graveyard, holding a Raise that costs {1}.
func _hero_with_two_dead_creatures() -> MmEngine:
	var giant: MmCardDefinition = Scenario.creature("Giant", 5, 5)
	var runt: MmCardDefinition = Scenario.creature("Runt", 1, 1)
	var wrath: MmCardDefinition = Scenario.instant("Wrath", Scenario.mana_cost(0), [], [Scenario.destroy(Scenario.each_creature())])
	var raise: MmCardDefinition = Scenario.instant("Raise", Scenario.mana_cost(1), [Scenario.your_dead_creature()],
		[Scenario.return_to_hand(Scenario.targeted(0))])
	var engine: MmEngine = AiScenario.ready_with([runt, giant], [], [wrath, raise, Scenario.basic_land("Swamp")])
	Scenario.play_first_land(engine)
	Scenario.cast_and_resolve(engine, "Wrath")
	return engine


# --- Flashback (card track) ------------------------------------------------------------


func test_a_full_agent_casts_removal_again_with_flashback() -> void:
	var engine: MmEngine = _hero_with_zap_in_graveyard()

	var play: int = AiScenario.ask(engine, AiAgent.new())

	var cast: CastSpellAction = AiScenario.action_at(engine, play) as CastSpellAction
	assert_not_null(cast, "It casts something.")
	assert_eq(cast.object_id, Scenario.card_in_graveyard(engine, engine.hero(), "Zap"), "From the graveyard.")


func test_no_agent_pays_the_life_it_has_left() -> void:
	var engine: MmEngine = _hero_with_analysis_in_graveyard(3)
	var analysis: int = Scenario.card_in_graveyard(engine, engine.hero(), "Analysis")
	assert_true(Scenario.offers_cast(engine, analysis), "It could be cast, for all 3 life.")

	assert_ne(_cast_id(engine, AiAgent.new(null, AiAgent.Mode.CHEAP)), analysis)
	assert_ne(_cast_id(engine, AiAgent.new()), analysis, "Paying it would lose the encounter.")


func test_a_cheap_agent_taps_its_least_valuable_creatures_first() -> void:
	var giant: MmCardDefinition = Scenario.creature("Giant", 4, 4)
	var bears: Array[MmCardDefinition] = [giant, Scenario.creature("Bear", 2, 2), Scenario.creature("Bear", 2, 2)]
	var cub: MmCardDefinition = Scenario.creature("Cub", 2, 2)
	var engine: MmEngine = _hero_main(bears, [_project(), cub])
	Scenario.cast_and_resolve(engine, "Project")
	Scenario.resolve_stack(engine)
	Scenario.cast_and_resolve(engine, "Cub")
	Scenario.cast(engine, Scenario.card_in_graveyard(engine, engine.hero(), "Project"))
	var decision: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(decision)

	var picked: Array = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))

	var expected: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Bear")
	expected.append(Scenario.permanent_named(engine, engine.hero().id, "Cub"))
	expected.sort()
	assert_eq(picked, expected, "Not the Giant; the Cub has summoning sickness, so it was worth least.")
	assert_eq(decision.validate(AiScenario.ask(engine, AiAgent.new())), "", "A full Agent answers legally too.")


## The Hero in their main phase with two Elves, "{T}: Add {W}", having cast Zap, "Zap deals
## 2 damage to target creature. Flashback {1}{W}", from the hand at one of the Villain's two
## Wolves.
func _hero_with_zap_in_graveyard() -> MmEngine:
	var zap: MmCardDefinition = Scenario.flashback_sorcery("Zap", [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[Scenario.deal_damage(2, Scenario.targeted(0))], Scenario.flashback(Scenario.mana_cost(1, [MmMana.Type.WHITE])))
	var engine: MmEngine = _hero_main([Scenario.elf(), Scenario.elf()], [zap],
		[Scenario.creature("Wolf", 2, 2), Scenario.creature("Wolf", 2, 2)])
	Scenario.cast_and_resolve(engine, "Zap", [MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Wolf"))])
	Scenario.resolve_stack(engine)
	return engine


## The Hero in their main phase at [param life] life, having cast Analysis, "Draw a card.
## Flashback—Pay 3 life", from the hand.
func _hero_with_analysis_in_graveyard(life: int) -> MmEngine:
	var costs: Array[MmCost] = [Scenario.pay_life(3)]
	var analysis: MmCardDefinition = Scenario.flashback_sorcery("Analysis", [],
		[Scenario.draw_cards(1, Scenario.you())], Scenario.flashback(null, costs))
	var engine: MmEngine = _hero_main([], [analysis], [], life)
	Scenario.cast_and_resolve(engine, "Analysis")
	Scenario.resolve_stack(engine)
	return engine


## "You gain 1 life. Flashback—Tap three untapped creatures you control."
func _project() -> MmCardDefinition:
	var costs: Array[MmCost] = [Scenario.tap_creatures(3)]
	return Scenario.flashback_sorcery("Project", [], [Scenario.gain_life(1, Scenario.you())], Scenario.flashback(null, costs))


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = [], life: int = 20) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	setup.hero.starting_life = life
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards,
		3, MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## The object [param agent]'s priority answer casts, or -1.
func _cast_id(engine: MmEngine, agent: AiAgent) -> int:
	var cast: CastSpellAction = AiScenario.action_at(engine, AiScenario.ask(engine, agent)) as CastSpellAction
	return -1 if cast == null else cast.object_id
