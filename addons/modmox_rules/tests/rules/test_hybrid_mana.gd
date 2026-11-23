extends GutTest
## Hybrid mana symbols (CR 107.4e): {B/R} is paid with one black mana or one red mana. A unit
## of mana pays a plain symbol of its type first, then the first hybrid symbol with its color,
## then generic mana (engine ADR 0077).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type
const BLACK_RED: Vector2i = Vector2i(Type.BLACK, Type.RED)


func test_two_mountains_cast_a_creature_costing_one_and_black_red() -> void:
	var engine: MmEngine = _ready_to_pay(_pup(), ["Mountain", "Mountain"])

	_begin_cast(engine, "Cinder Pup")
	assert_eq(Scenario.auto_pay(engine), "")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Cinder Pup"])
	assert_eq(engine.hero().mana_pool().size(), 0)


func test_a_swamp_pays_the_hybrid_symbol_and_a_forest_the_generic() -> void:
	var engine: MmEngine = _ready_to_pay(_pup(), ["Forest", "Swamp"])
	_begin_cast(engine, "Cinder Pup")

	assert_eq(Scenario.pay_by_tapping(engine, _land(engine, "Forest")), "")
	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq([paying.remaining_generic, paying.remaining_hybrid_symbols], [0, [BLACK_RED] as Array[Vector2i]],
		"Green can't pay the {B/R}.")
	assert_eq(Scenario.pay_by_tapping(engine, _land(engine, "Swamp")), "")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Cinder Pup"])


func test_red_pays_the_hybrid_symbol_before_the_generic() -> void:
	var engine: MmEngine = _ready_to_pay(_pup(), ["Mountain", "Forest"])
	_begin_cast(engine, "Cinder Pup")

	assert_eq(Scenario.pay_by_tapping(engine, _land(engine, "Mountain")), "")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq([paying.remaining_generic, paying.remaining_hybrid_symbols], [1, [] as Array[Vector2i]],
		"ADR 0077: the red paid the {B/R}, leaving the {1} the Forest can pay.")
	assert_eq(Scenario.pay_by_tapping(engine, _land(engine, "Forest")), "")
	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Cinder Pup"])


func test_a_plain_red_symbol_is_paid_before_a_hybrid_one() -> void:
	var engine: MmEngine = _ready_to_pay(_red_pup(), ["Mountain", "Swamp"])
	_begin_cast(engine, "Red Pup")

	assert_eq(Scenario.pay_by_tapping(engine, _land(engine, "Mountain")), "")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq([paying.remaining_symbols, paying.remaining_hybrid_symbols],
		[[] as Array[Type], [BLACK_RED] as Array[Vector2i]], "The {B/R} is left for the Swamp.")
	assert_eq(Scenario.pay_by_tapping(engine, _land(engine, "Swamp")), "")
	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Red Pup"])


func test_two_forests_cant_pay_for_it_so_it_is_not_offered() -> void:
	var engine: MmEngine = _ready_to_pay(_pup(), ["Forest", "Forest"])

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Cinder Pup")),
		"CR 107.4e: only black or red pays the {B/R}.")
	assert_false(ManaPayment.can_afford(engine.game_state(), engine.hero().id, _pup().mana_cost))


func test_a_forest_is_not_offered_while_only_the_hybrid_symbol_is_owed() -> void:
	var engine: MmEngine = _ready_to_pay(_pup(), ["Forest", "Mountain", "Forest"])
	_begin_cast(engine, "Cinder Pup")
	var forests: Array[int] = Scenario.permanents_named(engine, engine.hero().id, "Forest")
	assert_eq(Scenario.pay_by_tapping(engine, forests[0]), "")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision

	assert_eq(Scenario.colors_offered(paying.actions, forests[1]), [] as Array[int])
	assert_eq(Scenario.colors_offered(paying.actions, _land(engine, "Mountain")), [MmMana.NO_TYPE])


func test_a_treasures_black_pays_the_hybrid_symbol() -> void:
	var extras: Array[MmCardDefinition] = [Scenario.free_tokens("Hoard", Scenario.treasure()), _black_red()]
	var engine: MmEngine = _ready_with(_setup(extras, ["Forest"]), extras)
	assert_eq(Scenario.cast_and_resolve(engine, "Hoard"), "")
	var treasure: int = Scenario.tokens_on_battlefield(engine)[0]
	_begin_cast(engine, "Ember Imp")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_eq(Scenario.colors_offered(paying.actions, treasure), [Type.WHITE, Type.BLUE, Type.BLACK, Type.RED, Type.GREEN],
		"ADR 0072: every color once any would pay.")
	assert_eq(Scenario.pay_for(engine, treasure, Type.BLACK), "")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Ember Imp"])


func test_its_spell_is_black_and_red_with_mana_value_two() -> void:
	var engine: MmEngine = _ready_to_pay(_pup(), ["Mountain", "Mountain"])
	_begin_cast(engine, "Cinder Pup")
	Scenario.auto_pay(engine)

	var spell: MmCharacteristics = engine.game_state().characteristics_of(engine.game_state().stack.objects()[0])

	assert_eq(spell.colors, [MmCardTypes.CardColor.BLACK, MmCardTypes.CardColor.RED], "CR 202.2d")
	assert_eq(spell.mana_value(), 2, "CR 202.3f")


## A 2/1 creature costing {1}{B/R}.
func _pup() -> MmCardDefinition:
	return Scenario.creature("Cinder Pup", 2, 1, [], Scenario.hybrid_cost(1, [[Type.BLACK, Type.RED]]))


## A 2/2 creature costing {R}{B/R}.
func _red_pup() -> MmCardDefinition:
	return Scenario.creature("Red Pup", 2, 2, [], Scenario.hybrid_cost(0, [[Type.BLACK, Type.RED]], [Type.RED]))


## A 1/1 creature costing {B/R}.
func _black_red() -> MmCardDefinition:
	return Scenario.creature("Ember Imp", 1, 1, [], Scenario.hybrid_cost(0, [[Type.BLACK, Type.RED]]))


## The Hero in their main phase on Game Turn 3 with the lands named [param land_names],
## holding [param held].
func _ready_to_pay(held: MmCardDefinition, land_names: Array[String]) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.free_land_fetch(), held]
	var engine: MmEngine = _ready_with(_setup(extras, ["Mountain", "Swamp", "Forest"]), extras)
	if engine == null:
		return null
	assert_eq(Scenario.fetch_lands(engine, land_names), "")
	return engine


## A setup whose Hero deck cycles through [param extras] and basic lands named
## [param land_names].
func _setup(extras: Array[MmCardDefinition], land_names: Array[String]) -> MmEncounterSetup:
	var cards: Array[MmCardDefinition] = extras.duplicate()
	for land_name: String in land_names:
		cards.append(Scenario.basic_land(land_name))
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


## The Hero's first permanent named [param land_name].
func _land(engine: MmEngine, land_name: String) -> int:
	return Scenario.permanents_named(engine, engine.hero().id, land_name)[0]
