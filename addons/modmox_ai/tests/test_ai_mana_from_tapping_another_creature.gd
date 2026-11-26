extends GutTest
## Paying with Jaspera Sentinel's "{T}, Tap an untapped creature you control: Add one mana of
## any color." (engine ADR 0105). The payment planner, which Auto-tap uses for the Hero (game
## ADR 0031), takes such a source after lands and creatures, since it taps two creatures, and
## then taps the creature least missed: one with no {T} ability of its own, and of those one
## with summoning sickness, which could not attack anyway. Sentinel is a 1/2 costing {0}
## with that ability; Bear a 2/2 costing {0}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type


func test_a_land_pays_before_the_sentinel() -> void:
	var sprout: MmCardDefinition = Scenario.creature("Sprout", 1, 1, [], Scenario.mana_cost(0, [Type.GREEN]))
	var engine: MmEngine = _ready_to_pay([Scenario.sentinel(), _bear()], sprout, ["Forest"])

	_cast_and_let_the_agent_pay(engine, "Sprout")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Sprout"])
	assert_true(_is_tapped(engine, "Forest"))
	assert_false(_is_tapped(engine, "Sentinel"))
	assert_false(_is_tapped(engine, "Bear"))


func test_a_creature_that_taps_for_mana_pays_before_the_sentinel() -> void:
	var sprout: MmCardDefinition = Scenario.creature("Sprout", 1, 1, [], Scenario.mana_cost(0, [Type.GREEN]))
	var engine: MmEngine = _ready_to_pay([Scenario.sentinel(), AiScenario.free_alpha("llanowar_elves"), _bear()], sprout, [])

	_cast_and_let_the_agent_pay(engine, "Sprout")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Sprout"])
	assert_true(_is_tapped(engine, "Llanowar Elves"))
	assert_false(_is_tapped(engine, "Sentinel"))


func test_the_sentinel_taps_a_creature_without_a_tap_ability_rather_than_a_mana_creature() -> void:
	# Only the Sentinel makes blue, so it pays, and the Elves are kept to make green.
	var drop: MmCardDefinition = Scenario.creature("Drop", 1, 1, [], Scenario.mana_cost(0, [Type.BLUE]))
	var engine: MmEngine = _ready_to_pay([Scenario.sentinel(), AiScenario.free_alpha("llanowar_elves"), _bear()], drop, [])

	_cast_and_let_the_agent_pay(engine, "Drop")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Drop"])
	assert_true(_is_tapped(engine, "Sentinel"))
	assert_true(_is_tapped(engine, "Bear"))
	assert_false(_is_tapped(engine, "Llanowar Elves"))


func test_the_sentinel_taps_a_creature_with_summoning_sickness_before_one_that_could_attack() -> void:
	var drop: MmCardDefinition = Scenario.creature("Drop", 1, 1, [], Scenario.mana_cost(0, [Type.BLUE]))
	var late: MmCardDefinition = Scenario.creature("Late", 2, 2)
	var engine: MmEngine = _ready_to_pay([Scenario.sentinel(), _bear()], drop, [], [late])
	assert_eq(Scenario.cast_and_resolve(engine, "Late"), "")

	_cast_and_let_the_agent_pay(engine, "Drop")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Drop"])
	assert_true(_is_tapped(engine, "Late"))
	assert_false(_is_tapped(engine, "Bear"), "The Bear can still attack.")


func test_the_agent_answers_the_sentinels_choice_as_part_of_paying() -> void:
	var drop: MmCardDefinition = Scenario.creature("Drop", 1, 1, [], Scenario.mana_cost(0, [Type.BLUE]))
	var engine: MmEngine = _ready_to_pay([Scenario.sentinel(), _bear(), Scenario.creature("Cub", 1, 1)], drop, [])
	_begin_cast(engine, "Drop")
	assert_eq(Scenario.pay_for(engine, Scenario.permanent_named(engine, engine.hero().id, "Sentinel"), Type.BLUE), "")
	var agent: AiAgent = AiAgent.new()

	var answer: Variant = AiScenario.ask(engine, agent)

	assert_eq(answer, [Scenario.permanent_named(engine, engine.hero().id, "Cub")], "The Cub is worth less than the Bear.")
	assert_eq(agent.explain(), AiAgent.Reason.PAYMENT_PLAN, "Nothing is simulated.")


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _is_tapped(engine: MmEngine, card_name: String) -> bool:
	return engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, card_name)).is_tapped


## The Hero in their main phase of Game Turn 3 with [param creatures] in play, the lands
## named [param land_names] fetched, and [param held] and [param others] in hand.
func _ready_to_pay(creatures: Array[MmCardDefinition], held: MmCardDefinition, land_names: Array[String],
		others: Array[MmCardDefinition] = []) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.free_land_fetch(), held]
	extras.append_array(others)
	var deck: Array[MmCardDefinition] = extras.duplicate()
	deck.append(Scenario.basic_land("Forest"))
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(creatures, no_cards, deck)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, creatures, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	if engine == null:
		return null
	if not land_names.is_empty():
		assert_eq(Scenario.fetch_lands(engine, land_names), "")
	return engine


## Casts the card named [param card_name] from the Hero's hand, up to its first payment.
func _begin_cast(engine: MmEngine, card_name: String) -> void:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	var index: int = Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), card_name))
	assert_ne(index, -1, "%s can be cast." % card_name)
	if index != -1:
		assert_eq(engine.submit(index), "")


## Casts the card named [param card_name] and lets a Normal Agent pay for it, as Auto-tap does.
func _cast_and_let_the_agent_pay(engine: MmEngine, card_name: String) -> void:
	_begin_cast(engine, card_name)
	var agent: AiAgent = AiAgent.new()
	while engine.pending_decision() is PayManaDecision or engine.pending_decision() is ChoosePermanentsDecision:
		assert_eq(AiScenario.let_answer(engine, agent), "")
		assert_eq(agent.explain(), AiAgent.Reason.PAYMENT_PLAN)
