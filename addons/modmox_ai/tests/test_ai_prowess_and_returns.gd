extends GutTest
## How the AI plays prowess (CR 702.108a), a cost that returns a permanent to its owner's hand
## (Fear of Isolation's), and an ability that returns its own creature (Dour Port-Mage's).
## None of them needs anything of its own: the simulation sees the pump, scores each pick and
## scores the save.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


func test_a_full_agent_casts_a_noncreature_spell_before_attacking_when_prowess_makes_the_attack_lethal() -> void:
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var engine: MmEngine = AiScenario.ready_with([Scenario.monk()], [], [gift], [], Step.PRECOMBAT_MAIN, 2)
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

	assert_true(engine.villain().has_lost, "A Gift before combat makes a Monk 2/2, for the Villain's last 2 life.")


func test_both_agents_return_their_least_valuable_permanent_to_cast_fear_of_isolation() -> void:
	var giant: MmCardDefinition = Scenario.creature("Giant", 4, 4)
	var rock: MmCardDefinition = Scenario.artifact("Rock", [Scenario.tap_for_mana(MmMana.Type.COLORLESS, 1)])
	var isolation: MmCardDefinition = Scenario.free_copy(_card("duskmourn_house_of_horror", "fear_of_isolation"))
	var engine: MmEngine = AiScenario.ready_with([giant, rock], [], [isolation])
	assert_not_null(engine, "No seed gave the needed hands.")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Fear of Isolation")), "")
	var decision: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(decision)
	var rock_id: Array[int] = [Scenario.permanent_named(engine, engine.hero().id, "Rock")]

	var cheap: Array = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))
	var full: Array = AiScenario.ask(engine, AiAgent.new())

	assert_eq(cheap, rock_id, "Not the Giant, which could attack this turn.")
	assert_eq(full, rock_id)


func test_a_full_agent_returns_its_creature_with_dour_port_mage_in_answer_to_removal() -> void:
	var port_mage: MmCardDefinition = Scenario.free_copy(_card("bloomburrow", "dour_port_mage"))
	var bird: MmCardDefinition = Scenario.creature("Blue Bird", 0, 1, [Scenario.tap_for_mana(MmMana.Type.BLUE, 2)])
	var giant: MmCardDefinition = Scenario.creature("Giant", 4, 4)
	var no_cards: Array[MmCardDefinition] = []
	var doom: Array[MmCardDefinition] = [Scenario.free_destroy("Doom")]
	var engine: MmEngine = AiScenario.ready_with([port_mage, bird, giant], no_cards, no_cards, doom)
	assert_not_null(engine, "No seed gave the needed hands.")
	assert_eq(Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN), "")
	var giant_id: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Doom"), [MmReference.to_object(giant_id)]), "")
	assert_eq(Scenario.pass_priority(engine), "", "The Villain passes with Doom on the stack.")

	var play: int = AiScenario.ask(engine, AiAgent.new())

	var activation: ActivateAbilityAction = AiScenario.action_at(engine, play) as ActivateAbilityAction
	assert_not_null(activation, "It answers Doom.")
	assert_eq(activation.object_id, Scenario.permanent_named(engine, engine.hero().id, "Dour Port-Mage"),
		"The Giant goes back to the hand, and the Port-Mage draws a card for it.")


func _card(set_name: String, file_name: String) -> MmCardDefinition:
	return load("res://content/cards/%s/%s.tres" % [set_name, file_name]) as MmCardDefinition
