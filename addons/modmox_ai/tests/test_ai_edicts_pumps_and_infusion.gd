extends GutTest
## How the AI plays a sacrifice effect (Agent of the Fates's "each opponent sacrifices a
## creature"), an ability it may activate only once each turn (Cutthroat Centurion's), and
## an "if you gained life this turn" (Poisoner's Apprentice's), and a Role token created
## attached to a creature (Price of Beauty's). None of them needs anything
## of its own: the Agent picks what to sacrifice as it picks a cost's, it is offered only
## what it may activate, and the simulation sees a -4/-4 that does nothing without a gain.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_both_agents_sacrifice_their_least_valuable_creature_to_an_edict() -> void:
	# The Hero's deck holds one Edict among creatures it cannot cast yet: with more, a world
	# the Villain imagines may deal the Hero another, and then both picks lose everything.
	var giant: MmCardDefinition = Scenario.creature("Giant", 4, 4)
	var squirrel: MmCardDefinition = Scenario.creature("Squirrel", 1, 1)
	var edict: Array[MmCardDefinition] = [Scenario.free_edict()]
	var deck: Array[MmCardDefinition] = edict.duplicate()
	deck.append_array(Scenario.copies(Scenario.creature("Costly", 5, 5, [], Scenario.mana_cost(5)), 39))
	var villain_creatures: Array[MmCardDefinition] = [giant, squirrel]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.setup_with(deck, Scenario.cycled(villain_creatures)),
		NO_CARDS, villain_creatures, edict, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Edict")), "")
	assert_eq(Scenario.pass_to_permanents_choice(engine), "")
	assert_eq(engine.pending_decision().player_id, engine.villain().id)
	var squirrel_id: Array[int] = [Scenario.permanent_named(engine, engine.villain().id, "Squirrel")]

	var cheap: Array = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))
	var full: Array = AiScenario.ask(engine, AiAgent.new())

	assert_eq(cheap, squirrel_id, "CHEAP: not the Giant.")
	assert_eq(full, squirrel_id, "FULL: not the Giant.")


func test_a_full_agent_sacrifices_a_spare_creature_so_its_blocked_centurion_wins_the_fight() -> void:
	# Cutthroat Centurion's "Sacrifice another artifact or creature: This creature gets +2/+2
	# until end of turn. Activate only once each turn." on a 2/2 costing {0}.
	var pump: ActivatedAbility = Scenario.activated(null,
		[Scenario.sacrifice_permanents(1, Scenario.all_of([Scenario.is_not(IsSourceFilter.new()),
			Scenario.any_of([Scenario.of_type(MmCardTypes.CardType.ARTIFACT), Scenario.of_type(MmCardTypes.CardType.CREATURE)])]))],
		[Scenario.until_end_of_turn(Scenario.modify_pt(2, 2, SourceSelection.new()))])
	pump.is_once_each_turn = true
	var centurion: MmCardDefinition = Scenario.creature("Centurion", 2, 2, [pump])
	var spare: MmCardDefinition = Scenario.creature("Spare", 1, 1)
	var bear: MmCardDefinition = Scenario.creature("Their Bear", 3, 3)
	var engine: MmEngine = AiScenario.ready_with([centurion, spare], [bear], NO_CARDS, NO_CARDS, Step.DECLARE_ATTACKERS)
	assert_not_null(engine, "No seed gave the needed hands.")
	var centurion_id: int = Scenario.permanent_named(engine, engine.hero().id, "Centurion")
	var bear_id: int = Scenario.permanent_named(engine, engine.villain().id, "Their Bear")
	assert_eq(Scenario.declare_attackers(engine, [centurion_id]), "")
	assert_eq(Scenario.pass_to_blockers(engine), "")
	assert_eq(Scenario.declare_blockers(engine, [[bear_id, centurion_id]]), "")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, PriorityDecision), "")

	var play: int = AiScenario.ask(engine, AiAgent.new())

	var activation: ActivateAbilityAction = AiScenario.action_at(engine, play) as ActivateAbilityAction
	assert_not_null(activation, "It pumps the Centurion before damage.")
	assert_eq(activation.object_id, centurion_id)


func test_a_full_agent_gains_life_before_casting_the_apprentice_so_its_minus_four_kills() -> void:
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var giant: MmCardDefinition = Scenario.creature("Giant", 4, 4)
	var engine: MmEngine = AiScenario.ready_with(NO_CARDS, [giant], [gift, Scenario.apprentice()])
	assert_not_null(engine, "No seed gave the needed hands.")
	var agent: AiAgent = AiAgent.new()

	# The Agent plays the Hero's main phase; the Villain passes.
	for _decision: int in 60:
		if engine.is_over() or engine.game_state().step != Step.PRECOMBAT_MAIN:
			break
		var pending: MmPendingDecision = engine.pending_decision()
		if pending.player_id == engine.hero().id:
			assert_eq(AiScenario.let_answer(engine, agent), "")
		else:
			assert_eq(engine.submit(Scenario.default_answer(pending)), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.villain(), "Giant"), -1, "Gift first, then the Apprentice.")


func test_a_full_agent_puts_a_role_on_its_creature_before_attacking_when_the_bonus_is_lethal() -> void:
	# Price of Beauty's "Create a Wicked Role token attached to target creature you control."
	var engine: MmEngine = AiScenario.ready_with([Scenario.creature("Bear", 2, 2)], NO_CARDS, [Scenario.free_role()], NO_CARDS,
		Step.PRECOMBAT_MAIN, 3)
	assert_not_null(engine, "No seed gave the needed hands.")
	var agent: AiAgent = AiAgent.new()

	# The Agent plays the Hero's turn; the Villain, with nothing on the battlefield, passes.
	for _decision: int in 60:
		if engine.is_over() or engine.game_state().game_turn != 3:
			break
		var pending: MmPendingDecision = engine.pending_decision()
		if pending.player_id == engine.hero().id:
			assert_eq(AiScenario.let_answer(engine, agent), "")
		else:
			assert_eq(engine.submit(Scenario.default_answer(pending)), "")

	assert_true(engine.villain().has_lost, "A 3/3 Bear for the Villain's last 3 life.")

