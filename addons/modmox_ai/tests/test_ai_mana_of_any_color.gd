extends GutTest
## Paying with a Treasure (CR 111.10a): its one mana ability is offered once for each color
## (ADR 0072), and the payment planner, which Auto-tap uses for the Hero (game ADR 0031),
## takes a source sacrificed for its mana last, after lands and creatures, since it is lost
## for good. A color that pays nothing is never chosen, and a Treasure is never activated at
## priority for nothing.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type


func test_green_is_paid_with_a_forest_before_the_treasure() -> void:
	var sprout: MmCardDefinition = Scenario.creature("Sprout", 1, 1, [], Scenario.mana_cost(0, [Type.GREEN]))
	var engine: MmEngine = _ready_to_pay([], sprout, ["Forest"])
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	var forest: int = Scenario.permanent_named(engine, engine.hero().id, "Forest")

	_cast_and_let_the_agent_pay(engine, "Sprout")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Sprout"])
	assert_true(engine.game_state().object(forest).is_tapped)
	assert_eq(Scenario.tokens_on_battlefield(engine), [treasure] as Array[int], "The Treasure is kept.")


func test_generic_is_paid_with_lands_then_creatures_before_the_treasure() -> void:
	var pair: MmCardDefinition = Scenario.creature("Pair", 2, 2, [], Scenario.mana_cost(2))
	var engine: MmEngine = _ready_to_pay([AiScenario.free_alpha("llanowar_elves")], pair, ["Forest"])
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	var forest: int = Scenario.permanent_named(engine, engine.hero().id, "Forest")
	var elves: int = Scenario.permanent_named(engine, engine.hero().id, "Llanowar Elves")

	_cast_and_let_the_agent_pay(engine, "Pair")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Pair"])
	assert_eq(_tapped_in_order(engine), [forest, elves], "A land, then a creature.")
	assert_eq(Scenario.tokens_on_battlefield(engine), [treasure] as Array[int], "The Treasure is kept.")


func test_the_treasure_pays_the_generic_once_lands_and_creatures_are_spent() -> void:
	var trio: MmCardDefinition = Scenario.creature("Trio", 3, 3, [], Scenario.mana_cost(3))
	var engine: MmEngine = _ready_to_pay([AiScenario.free_alpha("llanowar_elves")], trio, ["Forest"])
	var forest: int = Scenario.permanent_named(engine, engine.hero().id, "Forest")
	var elves: int = Scenario.permanent_named(engine, engine.hero().id, "Llanowar Elves")
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]

	_cast_and_let_the_agent_pay(engine, "Trio")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Trio"])
	assert_eq(_tapped_in_order(engine), [forest, elves, treasure], "The Treasure last.")
	assert_eq(engine.hero().mana_pool().size(), 0)


func test_white_is_paid_with_the_treasure_making_white() -> void:
	var lions: MmCardDefinition = AiScenario.alpha("savannah_lions")
	var engine: MmEngine = _ready_to_pay([], lions, ["Forest", "Forest"])
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	_begin_cast(engine, "Savannah Lions")
	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	var chosen: ActivateAbilityAction = paying.actions[answer] as ActivateAbilityAction
	assert_eq([chosen.object_id, chosen.mana_type], [treasure, Type.WHITE])
	assert_eq(agent.explain(), AiAgent.Reason.PAYMENT_PLAN)
	assert_eq(engine.submit(answer), "")
	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Savannah Lions"])
	assert_eq(engine.hero().mana_pool().size(), 0, "No mana of another color was made.")


func test_black_is_paid_with_the_treasure_making_black_though_white_is_offered_first() -> void:
	var thrull: MmCardDefinition = Scenario.creature("Thrull", 1, 1, [], Scenario.mana_cost(0, [Type.BLACK]))
	var engine: MmEngine = _ready_to_pay([], thrull, ["Forest"])
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	_begin_cast(engine, "Thrull")
	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq(Scenario.colors_offered(paying.actions, treasure)[0], Type.WHITE)

	var answer: int = AiScenario.ask(engine, AiAgent.new())

	assert_eq((paying.actions[answer] as ActivateAbilityAction).mana_type, Type.BLACK)
	assert_eq(engine.submit(answer), "")
	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Thrull"])


func test_one_and_white_pays_white_with_the_treasure_and_the_generic_with_a_forest() -> void:
	var squire: MmCardDefinition = Scenario.creature("Squire", 1, 2, [], Scenario.mana_cost(1, [Type.WHITE]))
	var engine: MmEngine = _ready_to_pay([], squire, ["Forest", "Forest"])
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]

	_cast_and_let_the_agent_pay(engine, "Squire")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Squire"])
	assert_eq(_tapped_in_order(engine).size(), 2, "The Treasure and one Forest.")
	assert_eq(_tapped_in_order(engine)[0], treasure, "The color owed comes first.")
	assert_eq(engine.hero().mana_pool().size(), 0)


func test_the_villain_does_not_crack_a_treasure_at_priority_for_nothing() -> void:
	var hoarder: MmCardDefinition = Scenario.creature("Hoarder", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.create_tokens(Scenario.treasure())])])
	var engine: MmEngine = AiScenario.ready_with([], [hoarder])
	assert_not_null(engine, "No seed gave the needed board.")
	if engine == null:
		return
	assert_eq(Scenario.pass_priority(engine), "")
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(decision.player_id, engine.villain().id)
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	assert_eq(Scenario.colors_offered(decision.actions, treasure).size(), 5, "It could.")
	var agent: AiAgent = AiAgent.new()

	var answer: int = AiScenario.ask(engine, agent)

	assert_true(AiScenario.action_at(engine, answer) is PassAction)
	assert_eq(agent.explain(), AiAgent.Reason.NOTHING_WORTH_DOING)
	assert_eq(agent.rollout_count(), 0, "A mana ability is never a candidate.")


func test_a_cheap_agent_does_not_crack_a_treasure_at_priority_either() -> void:
	var hoarder: MmCardDefinition = Scenario.creature("Hoarder", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.create_tokens(Scenario.treasure())])])
	var engine: MmEngine = AiScenario.ready_with([], [hoarder])
	assert_not_null(engine, "No seed gave the needed board.")
	if engine == null:
		return
	assert_eq(Scenario.pass_priority(engine), "")

	var answer: int = AiScenario.ask(engine, AiAgent.new(null, AiAgent.Mode.CHEAP))

	assert_true(AiScenario.action_at(engine, answer) is PassAction)


# --- Helpers ---------------------------------------------------------------------------


## The Hero in their main phase on Game Turn 3 with [param creatures] (free copies cast on
## Game Turn 1), a Treasure and the lands named [param land_names], holding [param held].
func _ready_to_pay(creatures: Array[MmCardDefinition], held: MmCardDefinition, land_names: Array[String]) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.free_tokens("Hoard", Scenario.treasure()), Scenario.free_land_fetch(), held]
	var deck: Array[MmCardDefinition] = extras.duplicate()
	deck.append(Scenario.basic_land("Forest"))
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(creatures, no_cards, deck)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, creatures, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	if engine == null:
		return null
	assert_eq(Scenario.cast_and_resolve(engine, "Hoard"), "")
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
	while engine.pending_decision() is PayManaDecision:
		assert_eq(AiScenario.let_answer(engine, agent), "")
		assert_eq(agent.explain(), AiAgent.Reason.PAYMENT_PLAN)


## The Hero's permanents tapped since the cast began, in the order they were tapped.
func _tapped_in_order(engine: MmEngine) -> Array[int]:
	var since: int = 0
	var events: Array[MmEvent] = engine.event_log()
	for index: int in events.size():
		if events[index] is ZoneChangeEvent and (events[index] as ZoneChangeEvent).reason == ZoneChangeEvent.Reason.CAST:
			since = index
	var tapped: Array[int] = []
	for index: int in range(since, events.size()):
		var tap: TapEvent = events[index] as TapEvent
		if tap != null:
			tapped.append(tap.object_id)
	return tapped
