extends GutTest
## "Add one mana of any color" (CR 106.1a), as a Treasure's "{T}, Sacrifice this token: Add
## one mana of any color." (CR 111.10a). Its color is chosen as it is activated (CR 605.3a):
## it is offered as one Action for each color, in WUBRG order, at priority and while paying,
## where every color is offered once any would pay something (ADR 0072).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type
const WUBRG: Array[int] = [Type.WHITE, Type.BLUE, Type.BLACK, Type.RED, Type.GREEN]


func test_a_treasure_at_priority_offers_one_action_for_each_color_in_wubrg_order() -> void:
	var engine: MmEngine = _hero_main([_hoard()])
	Scenario.cast_and_resolve(engine, "Hoard")
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]

	var actions: Array[MmAction] = (engine.pending_decision() as PriorityDecision).actions

	assert_eq(Scenario.colors_offered(actions, treasure), WUBRG)
	var first: int = Scenario.activate_index(engine.pending_decision() as PriorityDecision, treasure)
	for offset: int in WUBRG.size():
		var activate: ActivateAbilityAction = actions[first + offset] as ActivateAbilityAction
		assert_eq([activate.object_id, activate.ability_index], [treasure, 0], "ADR 0012: its one ability, the colors together.")


func test_activating_its_green_taps_and_sacrifices_it_and_adds_green() -> void:
	var engine: MmEngine = _hero_main([_hoard()])
	Scenario.cast_and_resolve(engine, "Hoard")
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]

	assert_eq(Scenario.activate_for(engine, treasure, Type.GREEN), "")

	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 1)
	assert_eq([pool[0].type, pool[0].source_object_id], [Type.GREEN, treasure])
	assert_true(_tapped(engine, treasure), "{T} was paid.")
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.SACRIFICE)
	assert_eq(Scenario.tokens_on_battlefield(engine), [] as Array[int])
	assert_eq(Scenario.events_of(engine, TokenCeasedEvent).size(), 1, "CR 704.5d: the token ceased to exist.")
	assert_eq(Scenario.names(engine, engine.hero().graveyard), ["Hoard"], "CR 111.7: no Treasure stays there.")


func test_a_mana_ability_of_any_color_keeps_priority_and_does_not_use_the_stack() -> void:
	var engine: MmEngine = _hero_main([_hoard()])
	Scenario.cast_and_resolve(engine, "Hoard")
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]

	Scenario.activate_for(engine, treasure, Type.BLACK)

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.pending_decision().player_id, engine.hero().id)
	assert_eq(engine.game_state().stack.size(), 0, "CR 605.3a.")


func test_paying_white_with_three_forests_and_a_treasure_offers_the_treasures_colors_and_no_forest() -> void:
	var engine: MmEngine = _ready_to_pay(1, _lions())
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]

	_begin_cast(engine, "Savannah Lions")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(paying)
	assert_eq(Scenario.colors_offered(paying.actions, treasure), WUBRG, "Every color, though only white pays.")
	for forest: int in Scenario.permanents_named(engine, engine.hero().id, "Forest"):
		assert_eq(Scenario.colors_offered(paying.actions, forest), [] as Array[int], "A Forest pays nothing owed.")
	assert_eq(paying.actions.size(), 5)


func test_the_treasures_white_pays_for_savannah_lions_and_casts_it() -> void:
	var engine: MmEngine = _ready_to_pay(1, _lions())
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	_begin_cast(engine, "Savannah Lions")

	assert_eq(Scenario.pay_for(engine, treasure, Type.WHITE), "")

	assert_true(engine.pending_decision() is PriorityDecision, "Paid in full, so cast.")
	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Savannah Lions"])
	assert_eq(engine.hero().mana_pool().size(), 0)
	assert_eq(Scenario.tokens_on_battlefield(engine), [] as Array[int])
	for forest: int in Scenario.permanents_named(engine, engine.hero().id, "Forest"):
		assert_false(_tapped(engine, forest))


func test_the_treasures_blue_goes_to_the_pool_and_white_is_still_owed_until_canceled() -> void:
	var engine: MmEngine = _ready_to_pay(2, _lions())
	var treasures: Array[int] = Scenario.tokens_on_battlefield(engine)
	_begin_cast(engine, "Savannah Lions")

	assert_eq(Scenario.pay_for(engine, treasures[0], Type.BLUE), "")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(paying, "The other Treasure can still pay.")
	assert_eq([paying.remaining_generic, paying.remaining_symbols], [0, [Type.WHITE] as Array[Type]])
	assert_eq(_pool_types(engine), [Type.BLUE], "CR 605.3a: mana the cost does not need stays in the pool.")
	assert_eq(Scenario.colors_offered(paying.actions, treasures[1]), WUBRG)
	assert_eq(paying.actions.size(), 5, "The blue in the pool pays nothing owed.")
	assert_eq(engine.cancel_cast(), "")
	assert_eq(Scenario.tokens_on_battlefield(engine), treasures, "CR 728: canceling takes the Treasure back.")
	assert_eq(engine.hero().mana_pool().size(), 0)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Savannah Lions"), -1)


func test_a_color_that_leaves_nothing_able_to_pay_rewinds_the_cast() -> void:
	var engine: MmEngine = _ready_to_pay(1, _lions())
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	_begin_cast(engine, "Savannah Lions")

	assert_eq(Scenario.pay_for(engine, treasure, Type.BLUE), "")

	assert_true(engine.pending_decision() is PriorityDecision, "CR 728: the cast can't be finished, so it is rewound.")
	assert_false(engine.is_casting())
	assert_eq(Scenario.tokens_on_battlefield(engine), [treasure] as Array[int])
	assert_false(_tapped(engine, treasure))
	assert_eq(engine.hero().mana_pool().size(), 0)
	assert_ne(Scenario.card_in_hand(engine, engine.hero(), "Savannah Lions"), -1)


func test_paying_one_and_white_offers_every_color_and_a_forest_pays_the_generic() -> void:
	var engine: MmEngine = _ready_to_pay(1, _squire())
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	var forests: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Forest")
	_begin_cast(engine, "Squire")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq(Scenario.colors_offered(paying.actions, treasure), WUBRG)
	assert_eq(Scenario.colors_offered(paying.actions, forests[0]), [MmMana.NO_TYPE], "A Forest pays the {1}.")
	assert_eq(paying.actions.size(), 8, "Five colors and three Forests.")
	assert_eq(Scenario.pay_for(engine, treasure, Type.WHITE), "")
	assert_eq((engine.pending_decision() as PayManaDecision).remaining_symbols, [] as Array[Type])
	assert_eq(Scenario.pay_by_tapping(engine, forests[0]), "")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Squire"])
	assert_eq(engine.hero().mana_pool().size(), 0)


func test_a_treasure_is_not_offered_when_no_color_pays_what_is_still_owed() -> void:
	var engine: MmEngine = _ready_to_pay(1, _walker(), ["Forest", "Vault"])
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	_begin_cast(engine, "Wastes Walker")
	assert_eq(Scenario.pay_by_tapping(engine, Scenario.permanent_named(engine, engine.hero().id, "Forest")), "")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision

	assert_eq(paying.remaining_symbols, [Type.COLORLESS] as Array[Type])
	assert_eq(Scenario.colors_offered(paying.actions, treasure), [] as Array[int], "No color pays {C}.")
	assert_eq(paying.actions.size(), 1, "Only the Vault.")


func test_can_afford_counts_a_treasure_as_one_mana_of_any_one_color_once() -> void:
	var engine: MmEngine = _hero_main([_hoard()])
	Scenario.cast_and_resolve(engine, "Hoard")
	var state: MmGameState = engine.game_state()
	var hero: int = engine.hero().id

	for color: Type in MmMana.COLORS:
		assert_true(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [color])), Type.find_key(color))
	assert_true(ManaPayment.can_afford(state, hero, Scenario.mana_cost(1)))
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [Type.WHITE, Type.BLUE])), "It pays once.")
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(2)))
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [Type.COLORLESS])), "{C} is no color.")


func test_can_afford_counts_a_treasure_beside_lands() -> void:
	var engine: MmEngine = _ready_to_pay(1, _lions())
	var state: MmGameState = engine.game_state()
	var hero: int = engine.hero().id

	assert_true(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [Type.WHITE, Type.GREEN, Type.GREEN, Type.GREEN])))
	assert_true(ManaPayment.can_afford(state, hero, Scenario.mana_cost(3, [Type.RED])))
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [Type.WHITE, Type.WHITE])))
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(5)))


func test_a_replay_of_a_log_with_a_color_action_reproduces_the_state_exactly() -> void:
	# ADR 0010, 0012: the colors are offered in a fixed order, so an index replays exactly.
	var setup: MmEncounterSetup = _setup([_hoard()], ["Forest"])
	var original: MmEngine = _ready_with(setup, [_hoard()])
	Scenario.cast_and_resolve(original, "Hoard")
	var treasure: int = Scenario.tokens_on_battlefield(original)[0]
	assert_eq(Scenario.activate_for(original, treasure, Type.RED), "")
	var mid_step: String = original.fingerprint()
	var answers_by_then: int = original.decision_log().size()
	assert_eq(Scenario.play_until_game_turn(original, 5), "")

	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())

	assert_eq(replayed.fingerprint(), original.fingerprint())
	var added: Array[MmEvent] = Scenario.events_of(replayed, ManaAddedEvent)
	assert_eq((added.back() as ManaAddedEvent).mana_type, Type.RED)
	var halfway: MmEngine = MmEngine.replay(setup, original.decision_log().slice(0, answers_by_then))
	assert_eq(halfway.fingerprint(), mid_step, "Replayed to the red mana, the pool holds it.")
	assert_eq(halfway.hero().mana_pool()[0].type, Type.RED)


# --- Helpers ---------------------------------------------------------------------------


## An instant costing {0} that creates [param amount] Treasures.
func _hoard(amount: int = 1) -> MmCardDefinition:
	return Scenario.free_tokens("Hoard", Scenario.treasure(), amount)


## The Hero in their main phase on Game Turn 3, holding [param extras].
func _hero_main(extras: Array[MmCardDefinition]) -> MmEngine:
	return _ready_with(_setup(extras, ["Forest"]), extras)


## The Hero in their main phase on Game Turn 3 with [param treasures] Treasures and the
## lands named [param land_names] (three Forests unless others are given), holding
## [param held].
func _ready_to_pay(treasures: int, held: MmCardDefinition,
		land_names: Array[String] = ["Forest", "Forest", "Forest"]) -> MmEngine:
	var extras: Array[MmCardDefinition] = [_hoard(treasures), Scenario.free_land_fetch(), held]
	var engine: MmEngine = _ready_with(_setup(extras, ["Forest", "Vault"]), extras)
	if engine == null:
		return null
	assert_eq(Scenario.cast_and_resolve(engine, "Hoard"), "")
	assert_eq(Scenario.fetch_lands(engine, land_names), "")
	return engine


## Savannah Lions as it is authored: {W}.
func _lions() -> MmCardDefinition:
	return load("res://content/cards/alpha/savannah_lions.tres") as MmCardDefinition


## A 1/2 creature costing {1}{W}.
func _squire() -> MmCardDefinition:
	return Scenario.creature("Squire", 1, 2, [], Scenario.mana_cost(1, [Type.WHITE]))


## A 1/1 creature costing {1}{C}.
func _walker() -> MmCardDefinition:
	return Scenario.creature("Wastes Walker", 1, 1, [], Scenario.mana_cost(1, [Type.COLORLESS]))


## A setup whose Hero deck cycles through [param extras] and lands named [param land_names]
## (a Forest, or a Vault that taps for {C}).
func _setup(extras: Array[MmCardDefinition], land_names: Array[String]) -> MmEncounterSetup:
	var cards: Array[MmCardDefinition] = extras.duplicate()
	for land_name: String in land_names:
		cards.append(Scenario.basic_land("Forest") if land_name == "Forest" else Scenario.mana_land("Vault", Type.COLORLESS, 1))
	var no_cards: Array[MmCardDefinition] = []
	return Scenario.combat_setup(no_cards, no_cards, cards)


func _ready_with(setup: MmEncounterSetup, extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## Casts the card named [param card_name] from the Hero's hand, up to its first payment.
func _begin_cast(engine: MmEngine, card_name: String) -> void:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	var index: int = Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), card_name))
	assert_ne(index, -1, "%s can be cast." % card_name)
	if index != -1:
		assert_eq(engine.submit(index), "")


func _tapped(engine: MmEngine, object_id: int) -> bool:
	for event: MmEvent in Scenario.events_of(engine, TapEvent):
		if (event as TapEvent).object_id == object_id:
			return true
	return false


func _pool_types(engine: MmEngine) -> Array[Type]:
	var types: Array[Type] = []
	for unit: MmMana in engine.hero().mana_pool():
		types.append(unit.type)
	return types

