extends GutTest
## Paying with a land that adds one mana of one of a few colors, as Savage Lands's "{T}: Add
## {B}, {R}, or {G}.": it is offered once for each of its colors (ADR 0072), and the payment
## planner, which Auto-tap uses for the Hero (game ADR 0031), chooses the color owed, not
## the first offered.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type


func test_red_is_paid_with_the_land_making_red_though_black_is_offered_first() -> void:
	var engine: MmEngine = _ready_to_pay(_goblin())
	var lands: int = Scenario.permanent_named(engine, engine.hero().id, "Savage")
	_begin_cast(engine, "Goblin")
	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq(Scenario.colors_offered(paying.actions, lands), [Type.BLACK, Type.RED, Type.GREEN])
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	var chosen: ActivateAbilityAction = paying.actions[answer] as ActivateAbilityAction
	assert_eq([chosen.object_id, chosen.mana_type], [lands, Type.RED])
	assert_eq(agent.explain(), AiAgent.Reason.PAYMENT_PLAN)
	assert_eq(engine.submit(answer), "")
	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Goblin"])
	assert_eq(engine.hero().mana_pool().size(), 0, "No mana of another color was made.")


# --- Helpers ---------------------------------------------------------------------------


## A 1/1 creature costing {R}.
func _goblin() -> MmCardDefinition:
	return Scenario.creature("Goblin", 1, 1, [], Scenario.mana_cost(0, [Type.RED]))


## The Hero in their main phase on Game Turn 3 with a land that taps for {B}, {R} or {G}
## as their only land, holding [param held].
func _ready_to_pay(held: MmCardDefinition) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.free_land_fetch(), held]
	var deck: Array[MmCardDefinition] = extras.duplicate()
	deck.append(Scenario.choice_land("Savage", [Type.BLACK, Type.RED, Type.GREEN]))
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, deck)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	if engine == null:
		return null
	assert_eq(Scenario.fetch_lands(engine, ["Savage"]), "")
	return engine


## Casts the card named [param card_name] from the Hero's hand, up to its first payment.
func _begin_cast(engine: MmEngine, card_name: String) -> void:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	var index: int = Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), card_name))
	assert_ne(index, -1, "%s can be cast." % card_name)
	if index != -1:
		assert_eq(engine.submit(index), "")
