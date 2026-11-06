extends GutTest
## CR 202: mana costs, mana value, and color derived from the cost.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Type := MmMana.Type
const CardColor := MmCardTypes.CardColor


func test_mana_value_counts_generic_and_symbols() -> void:
	var cost: MmManaCost = Scenario.mana_cost(2, [Type.RED, Type.RED])

	assert_eq(cost.mana_value(), 4)
	assert_eq(cost.describe(), "{2}{R}{R}")


func test_color_comes_from_the_colored_symbols() -> void:
	assert_eq(Scenario.mana_cost(2, [Type.RED, Type.RED]).colors(), [CardColor.RED])
	assert_eq(Scenario.mana_cost(0, [Type.RED, Type.WHITE]).colors(), [CardColor.WHITE, CardColor.RED], "Always WUBRG order.")


func test_generic_and_colorless_symbols_make_a_colorless_card() -> void:
	assert_eq(Scenario.mana_cost(3).colors(), [])
	var colorless: MmManaCost = Scenario.mana_cost(0, [Type.COLORLESS])
	assert_eq(colorless.colors(), [])
	assert_eq(colorless.mana_value(), 1)


func test_a_card_with_no_mana_cost_has_mana_value_zero_and_no_color() -> void:
	var printed: MmCharacteristics = MmCharacteristics.printed(Scenario.basic_land("Forest"))

	assert_null(printed.mana_cost)
	assert_eq(printed.mana_value(), 0)
	assert_eq(printed.colors, [])


func test_adding_a_green_symbol_makes_a_white_red_card_three_colors() -> void:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = Scenario.sorcery("Boros Thing", Scenario.mana_cost(1, [Type.WHITE, Type.RED]), [], [])
	var add_green: AddManaSymbolModification = AddManaSymbolModification.new()
	add_green.symbol = Type.GREEN
	run_card.modifications.append(add_green)

	var printed: MmCharacteristics = MmCharacteristics.printed(run_card.flatten())

	assert_eq(printed.colors, [CardColor.WHITE, CardColor.RED, CardColor.GREEN])
	assert_eq(printed.mana_value(), 4)
	assert_eq(run_card.base.mana_cost.symbols, [Type.WHITE, Type.RED], "The base cost is untouched.")


func test_printed_characteristics_match_the_in_game_query() -> void:
	var definition: MmCardDefinition = Scenario.bolt()
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.copies(definition, 10), Scenario.copies(definition, 10)))
	var in_library: MmGameObject = engine.hero().library.objects()[0]

	var in_game: MmCharacteristics = engine.game_state().characteristics_of(in_library)
	var printed: MmCharacteristics = MmCharacteristics.printed(definition)

	assert_eq(in_game.name, printed.name)
	assert_eq(in_game.card_types, printed.card_types)
	assert_eq(in_game.colors, printed.colors)
	assert_eq(in_game.mana_value(), printed.mana_value())
	assert_eq(in_game.abilities.size(), printed.abilities.size())
