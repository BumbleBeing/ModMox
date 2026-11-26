extends GutTest
## The Agent plays the mechanics the red one-drops of this card track brought: an
## activation that exiles three cards from its graveyard (Kessig Wolfrider), mentor's target
## (Goblin Banneret), equipping the creature that gets more from it (Goblin Gaveleer), a card
## exiled to be played (Clockwork Percussionist, engine ADR 0100), and paying to return a
## card from its graveyard attacking (Phoenix Chick, engine ADR 0094's addendum).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const PLUS_ONE := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const Choice := ChooseYesOrNoDecision.Choice


func test_it_exiles_three_cards_from_its_graveyard_to_make_a_wolf() -> void:
	var rider: MmCardDefinition = _rider()
	var hand: Array[MmCardDefinition] = [_husk("Husk A"), _husk("Husk B"), _husk("Husk C")]
	var engine: MmEngine = _hero_main([rider], hand)
	for husk: MmCardDefinition in hand:
		assert_eq(Scenario.cast_and_resolve(engine, husk.name), "")
	var rider_id: int = Scenario.permanent_named(engine, engine.hero().id, "Rider")
	var agent: AiAgent = _agent()

	var answer: int = AiScenario.ask(engine, agent)

	var activation: ActivateAbilityAction = AiScenario.action_at(engine, answer) as ActivateAbilityAction
	assert_not_null(activation, "A free 3/2 for three dead cards is worth making.")
	if activation == null:
		return
	assert_eq(activation.object_id, rider_id)
	assert_eq(engine.submit(answer), "")
	for pick: int in 3:
		assert_true(engine.pending_decision() is ChooseObjectDecision, "Pick %d is asked." % pick)
		assert_eq(AiScenario.let_answer(engine, agent), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 1)


func test_it_puts_mentors_counter_on_its_smaller_attacker() -> void:
	var engine: MmEngine = Scenario.combat_ready([_mentor(), Scenario.creature("Squire", 1, 3)], [])
	assert_not_null(engine, "No seed gave the needed hands.")
	var mentor: int = Scenario.permanent_named(engine, engine.hero().id, "Mentor")
	var squire: int = Scenario.permanent_named(engine, engine.hero().id, "Squire")
	assert_eq(Scenario.declare_attackers(engine, [mentor, squire]), "")
	var agent: AiAgent = _agent()

	if engine.pending_decision() is ChooseTargetDecision:
		var answer: int = AiScenario.ask(engine, agent)
		assert_eq(AiScenario.chosen_target(engine, answer).id, squire)
		assert_eq(engine.submit(answer), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, squire, PLUS_ONE), 1)


func test_it_equips_the_creature_that_gets_more_from_its_equipment() -> void:
	# A Sword giving +0/+0: on the Bear it changes nothing, on Gaveleer it is +2/+0. The
	# Board Evaluator reads power from the layers, so it sees Gaveleer as a 3/1 trampler.
	var engine: MmEngine = _hero_main([_gaveleer(), Scenario.creature("Bear", 1, 1), Scenario.sword("Sword", 0)], [])
	var gaveleer: int = Scenario.permanent_named(engine, engine.hero().id, "Gaveleer")
	var sword: int = Scenario.permanent_named(engine, engine.hero().id, "Sword")
	assert_eq(engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, sword)), "")

	var target: MmReference = AiScenario.chosen_target(engine, AiScenario.ask(engine, _agent()))

	assert_eq(target.id, gaveleer)


func test_it_casts_a_card_exiled_to_be_played() -> void:
	var deck: Array[MmCardDefinition] = [_impulse(), Scenario.creature("Bear", 2, 2)]
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(deck), Scenario.cycled([]))
	var none: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.top_ready(setup, none, [deck[0]] as Array[MmCardDefinition], ["Bear"])
	assert_not_null(engine, "No seed gave the needed cards.")
	assert_eq(Scenario.cast_and_resolve(engine, "Impulse"), "")
	var exiled: int = Scenario.card_in_exile(engine, engine.hero(), "Bear")
	var agent: AiAgent = _agent()

	var cast_it: bool = false
	for _index: int in 12:
		var priority: PriorityDecision = engine.pending_decision() as PriorityDecision
		if priority == null or priority.player_id != engine.hero().id:
			break
		var answer: int = AiScenario.ask(engine, agent)
		var cast: CastSpellAction = priority.actions[answer] as CastSpellAction
		if cast == null:
			break
		if cast.object_id == exiled:
			cast_it = true
			break
		assert_eq(engine.submit(answer), "")
		assert_eq(Scenario.resolve_stack(engine), "")

	assert_true(cast_it, "A free 2/2 it may play now is worth casting.")


func test_it_pays_to_return_its_chick_attacking() -> void:
	var hero: Array[MmCardDefinition] = [Scenario.creature("Ann", 2, 2), Scenario.creature("Ben", 2, 2),
		Scenario.creature("Cy", 2, 2), Scenario.mana_bird()]
	var engine: MmEngine = _hero_main(hero, [_chick()])
	assert_eq(Scenario.cast_and_resolve(engine, "Chick"), "")
	assert_eq(Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS), "")
	var attackers: Array[int] = []
	for card_name: String in ["Ann", "Ben", "Cy"]:
		attackers.append(Scenario.permanent_named(engine, engine.hero().id, card_name))
	assert_eq(Scenario.declare_attackers(engine, attackers), "")
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")

	assert_eq(AiScenario.ask(engine, _agent()), Choice.YES, "Two mana for a 1/1 flier attacking.")


# --- Helpers ---------------------------------------------------------------------------


func _agent() -> AiAgent:
	return AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())


## A 1/2 costing {0}: "{0}, {T}, Exile three cards from your graveyard: Create a 3/2 Wolf
## creature token."
func _rider() -> MmCardDefinition:
	var three: ExileFromGraveyardCost = ExileFromGraveyardCost.new()
	three.count = 3
	var costs: Array[MmCost] = [TapCost.new(), three]
	var red: Array[MmCardTypes.CardColor] = [MmCardTypes.CardColor.RED]
	var wolf: MmCardDefinition = Scenario.token(3, 2, red, ["Wolf"] as Array[String])
	var effects: Array[MmEffect] = [Scenario.create_tokens(wolf)]
	return Scenario.creature("Rider", 1, 2, [Scenario.activated(Scenario.mana_cost(0), costs, effects)])


func _husk(card_name: String) -> MmCardDefinition:
	return Scenario.creature(card_name, 0, 0)


func _mentor() -> MmCardDefinition:
	return Scenario.creature("Mentor", 2, 2, [MentorAbility.new()])


## A 1/1 costing {0} with Trample and "This creature gets +2/+0 for each Equipment attached
## to it."
func _gaveleer() -> MmCardDefinition:
	var to_it: IsAttachedToFilter = IsAttachedToFilter.new()
	to_it.selection = SourceSelection.new()
	var count: CountValue = CountValue.new()
	count.selection = Scenario.each(Scenario.all_of([Scenario.has_subtype("Equipment"), to_it]))
	var twice: ProductValue = ProductValue.new()
	twice.factor = 2
	twice.value = count
	var pump: ModifyPowerToughnessContinuousEffect = Scenario.modify_pt(0, 0, SourceSelection.new())
	pump.power = twice
	return Scenario.creature("Gaveleer", 1, 1, [TrampleAbility.new(), Scenario.continuous_static([pump])])


## An instant costing {0}: "Exile the top card of your library. You may play it until the
## end of your next turn."
func _impulse() -> MmCardDefinition:
	var exile: ExileTopOfLibraryEffect = ExileTopOfLibraryEffect.new()
	exile.amount = Scenario.constant(1)
	exile.players = YouSelection.new()
	var may_play: MayPlayExiledEffect = MayPlayExiledEffect.new()
	may_play.selection = MovedCardsSelection.new()
	return Scenario.instant("Impulse", Scenario.mana_cost(0), [], [exile, may_play])


## A 0/0 flier costing {0} that can't block, with Phoenix Chick's return for {2}: it dies as
## it enters, and so starts in the graveyard.
func _chick() -> MmCardDefinition:
	var back: ReturnToBattlefieldEffect = Scenario.return_to_battlefield(SourceSelection.new())
	back.tapped = true
	back.attacking = true
	back.counters = Scenario.constant(1)
	var attack_with_three: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	attack_with_three.at_least = 3
	var rising: TriggeredAbility = Scenario.triggered(attack_with_three, [Scenario.may_pay_mana(Scenario.mana_cost(2), back)])
	rising.is_triggered_from_graveyard = true
	return Scenario.creature("Chick", 0, 0, [FlyingAbility.new(), CantBlockAbility.new(), rising])


func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = AiScenario.ready_with(hero_permanents, [], hand)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
