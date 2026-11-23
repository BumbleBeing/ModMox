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
	var add_green: AddManaCostModification = AddManaCostModification.new()
	add_green.cost = MmManaCost.new()
	add_green.cost.symbols = [Type.GREEN] as Array[MmMana.Type]
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


func test_a_generic_reduction_takes_off_generic_mana_only_and_never_below_zero() -> void:
	var cost: MmManaCost = Scenario.mana_cost(3, [Type.WHITE, Type.WHITE])

	assert_eq(cost.reduced_by(Scenario.mana_cost(2)).describe(), "{1}{W}{W}", "CR 118.7a")
	assert_eq(cost.reduced_by(Scenario.mana_cost(7)).describe(), "{W}{W}")
	assert_eq(cost.describe(), "{3}{W}{W}", "The cost reduced is left as it was.")
	assert_eq(cost.reduced_by(null).describe(), "{3}{W}{W}")


func test_a_colored_reduction_takes_off_that_symbol_or_else_generic_mana() -> void:
	var cost: MmManaCost = Scenario.mana_cost(2, [Type.BLUE, Type.BLUE])

	assert_eq(cost.reduced_by(Scenario.mana_cost(0, [Type.BLUE])).describe(), "{2}{U}", "CR 118.7b")
	assert_eq(cost.reduced_by(Scenario.mana_cost(0, [Type.RED])).describe(), "{1}{U}{U}", "CR 118.7b: it needs no red.")
	assert_eq(cost.reduced_by(Scenario.mana_cost(0, [Type.BLUE, Type.BLUE, Type.BLUE])).describe(), "{1}",
		"CR 118.7c: the blue beyond what it needs comes off generic mana.")
	assert_eq(Scenario.mana_cost(0, [Type.COLORLESS]).reduced_by(Scenario.mana_cost(0, [Type.COLORLESS])).describe(), "{0}",
		"CR 118.7d, and reduced to nothing it is {0} (CR 118.7).")


func test_a_reduction_leaves_the_mana_value_of_the_card_alone() -> void:
	var printed: MmCharacteristics = MmCharacteristics.printed(
		Scenario.cat_affinity_instant("Claws", Scenario.mana_cost(3, [Type.WHITE, Type.WHITE])))

	assert_eq(printed.mana_value(), 5, "CR 202.3")


# --- Hybrid symbols (CR 107.4e, engine ADR 0077) -------------------------------------


func test_a_hybrid_symbol_counts_one_toward_mana_value_and_is_written_with_a_slash() -> void:
	var cost: MmManaCost = Scenario.hybrid_cost(4, [[Type.BLACK, Type.RED]])

	assert_eq(cost.mana_value(), 5, "CR 202.3f: its largest component, one mana.")
	assert_eq(cost.describe(), "{4}{B/R}")
	assert_eq(Scenario.hybrid_cost(0, [[Type.RED, Type.WHITE]], [Type.RED]).describe(), "{R}{R/W}",
		"Plain symbols first, then hybrid ones.")


func test_a_hybrid_symbol_makes_a_card_both_of_its_colors() -> void:
	assert_eq(Scenario.hybrid_cost(4, [[Type.BLACK, Type.RED]]).colors(), [CardColor.BLACK, CardColor.RED],
		"CR 202.2d")
	assert_eq(Scenario.hybrid_cost(0, [[Type.RED, Type.WHITE]], [Type.GREEN]).colors(),
		[CardColor.WHITE, CardColor.RED, CardColor.GREEN], "In addition to its other colors, in WUBRG order.")


func test_a_colored_reduction_takes_off_a_plain_symbol_then_a_hybrid_one_of_its_color_then_generic() -> void:
	var red: MmManaCost = Scenario.mana_cost(0, [Type.RED])

	assert_eq(Scenario.hybrid_cost(4, [[Type.BLACK, Type.RED]]).reduced_by(red).describe(), "{4}",
		"CR 601.2b: its caster announces red for the {B/R}, so the {R} reduction takes it (CR 118.7).")
	assert_eq(Scenario.hybrid_cost(1, [[Type.BLACK, Type.RED]], [Type.RED]).reduced_by(red).describe(), "{1}{B/R}",
		"The plain {R} first: the {B/R} could still be paid with black.")
	assert_eq(Scenario.hybrid_cost(4, [[Type.BLACK, Type.RED]]).reduced_by(Scenario.mana_cost(0, [Type.GREEN])).describe(),
		"{3}{B/R}", "CR 118.7b: it needs no green.")
	assert_eq(Scenario.hybrid_cost(4, [[Type.BLACK, Type.RED]]).reduced_by(Scenario.mana_cost(5)).describe(), "{B/R}",
		"CR 118.7a: generic mana only.")


func test_x_and_a_mana_cost_modification_keep_the_hybrid_symbols() -> void:
	var cost: MmManaCost = Scenario.hybrid_cost(1, [[Type.BLACK, Type.RED]])
	cost.x_count = 1
	assert_eq(cost.with_x(2).describe(), "{3}{B/R}")

	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = Scenario.sorcery("Ember", Scenario.mana_cost(1), [], [])
	var add_hybrid: AddManaCostModification = AddManaCostModification.new()
	add_hybrid.cost = Scenario.hybrid_cost(0, [[Type.RED, Type.WHITE]])
	run_card.modifications.append(add_hybrid)

	var printed: MmCharacteristics = MmCharacteristics.printed(run_card.flatten())
	assert_eq(printed.mana_cost.describe(), "{1}{R/W}")
	assert_eq(printed.colors, [CardColor.WHITE, CardColor.RED])
	assert_eq(run_card.base.mana_cost.hybrid_symbols, [] as Array[Vector2i], "The base cost is untouched.")
