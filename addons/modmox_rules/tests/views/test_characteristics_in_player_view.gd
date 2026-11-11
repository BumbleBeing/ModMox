extends GutTest
## A Game Object's view carries the characteristics a card is drawn from (its colors, card
## types, supertypes, subtypes and mana cost), so the GUI can choose its Frame (ADR 0009).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_a_creature_card_in_hand_shows_its_colors_types_subtypes_and_mana_cost() -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(1, [MmMana.Type.GREEN]))
	bear.subtypes = ["Bear"]
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.copies(bear, 40), Scenario.copies(bear, 40)))

	var seen: MmObjectView = engine.view_for(engine.hero()).hand[0]

	assert_eq(seen.colors, [MmCardTypes.CardColor.GREEN] as Array[MmCardTypes.CardColor])
	assert_eq(seen.card_types, [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType])
	assert_eq(seen.supertypes, [] as Array[MmCardTypes.Supertype])
	assert_eq(seen.subtypes, ["Bear"] as Array[String])
	assert_eq(seen.mana_cost.describe(), "{1}{G}")


func test_a_basic_land_shows_its_supertype_and_no_mana_cost() -> void:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))

	var seen: MmObjectView = engine.view_for(engine.hero()).hand[0]

	assert_eq(seen.card_types, [MmCardTypes.CardType.LAND] as Array[MmCardTypes.CardType])
	assert_eq(seen.supertypes, [MmCardTypes.Supertype.BASIC] as Array[MmCardTypes.Supertype])
	assert_eq(seen.subtypes, ["Forest"] as Array[String])
	assert_eq(seen.colors, [] as Array[MmCardTypes.CardColor], "Colorless: a land has no mana cost.")
	assert_null(seen.mana_cost, "No mana cost at all, which is not the same as {0}.")


func test_a_permanents_view_agrees_with_its_printed_characteristics() -> void:
	# ADR 0009: a deck screen and the battlefield give the same answer for an unaffected card.
	var giant: MmCardDefinition = Scenario.creature("Giant", 3, 3, [], Scenario.mana_cost(0))
	giant.subtypes = ["Giant"]
	giant.supertypes = [MmCardTypes.Supertype.LEGENDARY]
	var engine: MmEngine = Scenario.combat_ready([giant], [])
	var printed: MmCharacteristics = MmCharacteristics.printed(giant)

	var seen: MmObjectView = engine.view_for(engine.villain()).battlefield[0]

	assert_eq(seen.name, printed.name)
	assert_eq(seen.colors, printed.colors)
	assert_eq(seen.card_types, printed.card_types)
	assert_eq(seen.supertypes, printed.supertypes)
	assert_eq(seen.subtypes, printed.subtypes)
	assert_eq(seen.mana_cost.describe(), printed.mana_cost.describe())


func test_changing_a_view_never_changes_the_game() -> void:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))
	var seen: MmObjectView = engine.view_for(engine.hero()).hand[0]

	seen.subtypes.append("Island")
	seen.card_types.append(MmCardTypes.CardType.CREATURE)

	var again: MmObjectView = engine.view_for(engine.hero()).hand[0]
	assert_eq(again.subtypes, ["Forest"] as Array[String])
	assert_eq(again.card_types, [MmCardTypes.CardType.LAND] as Array[MmCardTypes.CardType])


func test_a_star_creature_shows_a_star_in_hand_and_its_worked_out_numbers_on_the_battlefield() -> void:
	# Keldon Warlord: */*, the number of non-Wall creatures you control (CR 604.3).
	var warlord: MmCardDefinition = Scenario.free_copy(load("res://content/cards/alpha/keldon_warlord.tres") as MmCardDefinition)
	var in_hand: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.copies(warlord, 40), Scenario.copies(warlord, 40)))
	var held: MmObjectView = in_hand.view_for(in_hand.hero()).hand[0]
	assert_true(held.is_power_variable, "A card in hand reads */* as printed.")
	assert_true(held.is_toughness_variable)
	var engine: MmEngine = Scenario.combat_ready([warlord], [])

	var id: int = Scenario.permanent_named(engine, engine.hero().id, "Keldon Warlord")
	var seen: MmObjectView = null
	for permanent: MmObjectView in engine.view_for(engine.hero()).battlefield:
		if permanent.id == id:
			seen = permanent

	assert_false(seen.is_power_variable, "On the battlefield the numbers are worked out.")
	assert_false(seen.is_toughness_variable)
	assert_eq([seen.power, seen.toughness], [1, 1])
	assert_eq(CardLook.of_view(seen).power_toughness_texts(), ["1", "/", "1"] as Array[String])
