extends GutTest
## "Add {U}, {B}, or {R}", as Crumbling Necropolis's "{T}: Add {U}, {B}, or {R}.": one mana
## of one of a few colors, chosen as its ability is activated (CR 605.3a). It is offered as
## mana of any color is (ADR 0072), one Action for each of its colors, in WUBRG order, and
## none for any other color.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Type := MmMana.Type


func test_it_offers_one_action_for_each_of_its_colors_in_wubrg_order_and_none_for_the_others() -> void:
	# Authored green, blue, red, as Frontier Bivouac prints them.
	var engine: MmEngine = _ready_with_lands(_bivouac(), ["Bivouac"])
	var bivouac: int = Scenario.permanent_named(engine, engine.hero().id, "Bivouac")

	var actions: Array[MmAction] = (engine.pending_decision() as PriorityDecision).actions

	assert_eq(Scenario.colors_offered(actions, bivouac), [Type.BLUE, Type.RED, Type.GREEN])
	for action: MmAction in actions:
		var activate: ActivateAbilityAction = action as ActivateAbilityAction
		if activate != null and activate.object_id == bivouac:
			assert_eq(activate.ability_index, 0, "ADR 0012: its one ability, the colors together.")


func test_activating_its_red_taps_it_and_adds_red_without_the_stack() -> void:
	var engine: MmEngine = _ready_with_lands(_necropolis(), ["Necropolis"])
	var necropolis: int = Scenario.permanent_named(engine, engine.hero().id, "Necropolis")

	assert_eq(Scenario.activate_for(engine, necropolis, Type.RED), "")

	var pool: Array[MmMana] = engine.hero().mana_pool()
	assert_eq(pool.size(), 1)
	assert_eq([pool[0].type, pool[0].source_object_id], [Type.RED, necropolis])
	assert_true(engine.game_state().object(necropolis).is_tapped, "{T} was paid.")
	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.pending_decision().player_id, engine.hero().id)
	assert_eq(engine.game_state().stack.size(), 0, "CR 605.3a.")


func test_it_makes_no_color_it_does_not_name() -> void:
	var engine: MmEngine = _ready_with_lands(_necropolis(), ["Necropolis"])
	var necropolis: int = Scenario.permanent_named(engine, engine.hero().id, "Necropolis")

	assert_ne(Scenario.activate_for(engine, necropolis, Type.GREEN), "")

	assert_eq(engine.hero().mana_pool().size(), 0)
	assert_false(engine.game_state().object(necropolis).is_tapped)


func test_paying_black_offers_each_of_its_colors_and_its_black_pays() -> void:
	var engine: MmEngine = _ready_with_lands(_necropolis(), ["Necropolis", "Forest"], _thrull())
	var necropolis: int = Scenario.permanent_named(engine, engine.hero().id, "Necropolis")
	_begin_cast(engine, "Thrull")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(paying)
	assert_eq(Scenario.colors_offered(paying.actions, necropolis), [Type.BLUE, Type.BLACK, Type.RED],
		"ADR 0072: every color it makes, once one pays.")
	assert_eq(Scenario.pay_for(engine, necropolis, Type.BLACK), "")

	assert_eq(Scenario.names(engine, engine.game_state().stack), ["Thrull"])
	assert_eq(engine.hero().mana_pool().size(), 0)


func test_it_is_not_offered_while_paying_a_color_it_does_not_make() -> void:
	var engine: MmEngine = _ready_with_lands(_necropolis(), ["Necropolis", "Forest"], _sprout())
	var necropolis: int = Scenario.permanent_named(engine, engine.hero().id, "Necropolis")
	var forest: int = Scenario.permanent_named(engine, engine.hero().id, "Forest")
	_begin_cast(engine, "Sprout")

	var paying: PayManaDecision = engine.pending_decision() as PayManaDecision

	assert_eq(Scenario.colors_offered(paying.actions, necropolis), [] as Array[int], "None of its colors pays {G}.")
	assert_eq(Scenario.colors_offered(paying.actions, forest), [MmMana.NO_TYPE])
	assert_eq(paying.actions.size(), 1)


func test_can_afford_counts_it_as_one_mana_of_one_of_its_colors_once() -> void:
	var engine: MmEngine = _ready_with_lands(_necropolis(), ["Necropolis"])
	var state: MmGameState = engine.game_state()
	var hero: int = engine.hero().id

	for color: Type in [Type.BLUE, Type.BLACK, Type.RED]:
		assert_true(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [color])), Type.find_key(color))
	assert_true(ManaPayment.can_afford(state, hero, Scenario.mana_cost(1)))
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [Type.WHITE])))
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [Type.GREEN])))
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [Type.BLUE, Type.RED])), "It pays once.")
	assert_false(ManaPayment.can_afford(state, hero, Scenario.mana_cost(0, [Type.COLORLESS])))


# --- Helpers ---------------------------------------------------------------------------


## "{T}: Add {U}, {B}, or {R}."
func _necropolis() -> MmCardDefinition:
	return Scenario.choice_land("Necropolis", [Type.BLUE, Type.BLACK, Type.RED])


## "{T}: Add {G}, {U}, or {R}."
func _bivouac() -> MmCardDefinition:
	return Scenario.choice_land("Bivouac", [Type.GREEN, Type.BLUE, Type.RED])


## A 1/1 creature costing {B}.
func _thrull() -> MmCardDefinition:
	return Scenario.creature("Thrull", 1, 1, [], Scenario.mana_cost(0, [Type.BLACK]))


## A 1/1 creature costing {G}.
func _sprout() -> MmCardDefinition:
	return Scenario.creature("Sprout", 1, 1, [], Scenario.mana_cost(0, [Type.GREEN]))


## The Hero in their main phase on Game Turn 3 with the lands named [param land_names]
## ([param land], or a Forest) put onto the battlefield, holding [param held] if given.
func _ready_with_lands(land: MmCardDefinition, land_names: Array[String], held: MmCardDefinition = null) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.free_land_fetch()]
	if held != null:
		extras.append(held)
	var deck: Array[MmCardDefinition] = extras.duplicate()
	deck.append(land)
	deck.append(Scenario.basic_land("Forest"))
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(no_cards, no_cards, deck)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, no_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	if engine == null:
		return null
	assert_eq(Scenario.fetch_lands(engine, land_names), "")
	return engine


## Casts the card named [param card_name] from the Hero's hand, up to its first payment.
func _begin_cast(engine: MmEngine, card_name: String) -> void:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	var index: int = Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), card_name))
	assert_ne(index, -1, "%s can be cast." % card_name)
	if index != -1:
		assert_eq(engine.submit(index), "")
