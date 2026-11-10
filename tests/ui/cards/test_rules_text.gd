extends GutTest
## Rules text wraps, draws {X} symbols inline, shrinks to a smallest size, and past that
## scrolls (A236). Card Faces leave reminder text off, except on basic lands.

const SHORT: String = "Target creature gets +3/+3 until end of turn."
const WORDY: String = "Flying, first strike, vigilance\nWhen this creature enters, draw two cards, then discard a card.\n{T}: This creature deals 1 damage to any target.\n{1}{U}, {T}: Tap target creature. It doesn't untap during its controller's next untap step.\nAt the beginning of your upkeep, you gain 1 life for each card in your hand.\nWhenever another creature you control dies, put it on top of its owner's library."


func test_text_that_fits_has_no_scroll_bar() -> void:
	var rules: RulesText = _rules(SHORT, Vector2(240, 80))

	assert_false(rules.overflows())
	assert_false(rules.has_scroll_bar())


func test_text_that_overflows_at_the_smallest_size_gets_a_scroll_bar() -> void:
	var rules: RulesText = _rules(WORDY, Vector2(240, 80))

	assert_true(rules.overflows())
	assert_true(rules.has_scroll_bar())
	assert_eq(rules.smallest_font_size(), floori(14.0 * 0.75), "Three quarters of the largest size.")
	assert_eq(rules.font_size, rules.smallest_font_size(), "It shrank as far as allowed first.")


func test_text_shrinks_before_it_scrolls() -> void:
	var roomy: RulesText = _rules(SHORT, Vector2(240, 80))
	var cramped: RulesText = _rules(SHORT + "\n" + SHORT + "\n" + SHORT, Vector2(240, 80))

	assert_lt(cramped.font_size, roomy.font_size)
	assert_false(cramped.overflows())


func test_the_scroll_bar_stops_at_the_height_it_is_given() -> void:
	var rules: RulesText = _rules(WORDY, Vector2(240, 80), 60.0)

	assert_lte(rules.scroll_bar_height(), 60.0)


func test_scrolling_moves_by_whole_lines_and_stops_at_both_ends() -> void:
	var rules: RulesText = _rules(WORDY, Vector2(240, 80))

	rules.scroll_lines(-1.0)
	assert_eq(rules.scroll_offset(), 0.0, "Already at the top.")
	rules.scroll_lines(1.0)
	assert_almost_eq(rules.scroll_offset(), rules.line_height() * RulesText.LINES_PER_STEP, 0.01)
	for i: int in 50:
		rules.scroll_lines(1.0)
	assert_almost_eq(rules.scroll_offset(), rules.content_height() + rules.bottom_padding() - rules.size.y, 0.01, "Stops at the bottom.")


func test_symbols_in_rules_text_are_drawn_from_the_mana_symbol_images() -> void:
	var rules: RulesText = _rules("{T}: Add {G}.", Vector2(240, 80))

	assert_eq(rules.symbols(), ["{T}", "{G}"] as Array[String])
	assert_eq(ManaSymbols.image_for("{T}"), "t")
	assert_eq(ManaSymbols.image_for("{2}"), "2")
	assert_eq(ManaSymbols.image_for("{Q}"), "", "No image for an unknown symbol.")


func test_reminder_text_is_left_off_a_card_face() -> void:
	var look: CardLook = CardLook.new()
	look.rules_text = "First strike (This creature deals combat damage first.)\nProtection from white (This can't be blocked by white.)"

	assert_eq(look.printed_rules_text(), "First strike\nProtection from white")


func test_a_line_that_is_only_reminder_text_disappears() -> void:
	var look: CardLook = CardLook.new()
	look.rules_text = "(This is a reminder.)\nFlying"

	assert_eq(look.printed_rules_text(), "Flying")


func test_a_basic_land_keeps_its_reminder_text() -> void:
	var look: CardLook = CardLook.new()
	look.supertypes = [MmCardTypes.Supertype.BASIC]
	look.rules_text = "({T}: Add {G}.)"

	assert_eq(look.printed_rules_text(), "({T}: Add {G}.)")


func _rules(text: String, size: Vector2, bar_height: float = -1.0) -> RulesText:
	var rules: RulesText = RulesText.new()
	add_child_autofree(rules)
	rules.setup(Rect2(Vector2.ZERO, size), text, 14.0, size.y if bar_height < 0.0 else bar_height)
	return rules
