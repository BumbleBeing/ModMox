extends GutTest
## The Option Menu opens where a card was clicked with a row for each thing the click could
## mean, and closes without choosing when anything else is clicked.

const FIELD: Rect2 = Rect2(352, 86, 1386, 806)

var _chosen: Array[int] = []
var _pointed: Array[String] = []


func before_each() -> void:
	_chosen.clear()
	_pointed.clear()


func after_each() -> void:
	await wait_process_frames(2)


func test_it_is_closed_and_hidden_until_opened() -> void:
	var menu: OptionMenu = _menu()

	assert_false(menu.is_open())
	assert_false(menu.visible, "Hidden, it takes no clicks from the board.")
	assert_eq(menu.rows().size(), 0)
	assert_eq(menu.box_rect(), Rect2())


func test_it_opens_at_the_click_with_a_row_for_each_option() -> void:
	var menu: OptionMenu = _menu()

	menu.open(_options(2), Vector2(600, 300), FIELD)

	assert_true(menu.is_open())
	assert_true(menu.visible)
	assert_eq(menu.box_rect(), EncounterLayout.menu_rect(Vector2(600, 300), 2, FIELD))
	assert_eq(menu.box_rect().position, Vector2(600, 300))
	assert_eq(menu.rows().size(), 2)
	assert_eq(menu.words()[0].written(), "Option 1")
	assert_eq(menu.words()[1].written(), "Option 2")
	assert_eq(menu.rows()[0].custom_minimum_size.y, EncounterLayout.MENU_ROW)


func test_four_options_show_in_the_height_of_three_and_scroll() -> void:
	var menu: OptionMenu = _menu()

	menu.open(_options(4), Vector2(600, 300), FIELD)

	assert_eq(menu.rows().size(), 4)
	assert_eq(menu.box_rect().size, EncounterLayout.menu_rect(Vector2(600, 300), 3, FIELD).size)
	var scroll: ScrollContainer = menu.rows()[0].get_parent().get_parent() as ScrollContainer
	assert_not_null(scroll, "The rows are in a scrolling list.")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "It scrolls up and down only.")
	var needed: float = 4.0 * EncounterLayout.MENU_ROW + 3.0 * EncounterLayout.MENU_GAP
	assert_lt(scroll.custom_minimum_size.y, needed, "Shorter than its four rows, so they scroll.")


func test_it_stays_inside_the_field_when_opened_at_its_edge() -> void:
	var menu: OptionMenu = _menu()

	menu.open(_options(3), FIELD.end, FIELD)

	assert_true(FIELD.encloses(menu.box_rect()))


func test_pressing_a_row_answers_with_that_option_and_closes() -> void:
	var menu: OptionMenu = _menu()
	menu.open(_options(3), Vector2(600, 300), FIELD)

	menu.rows()[2].pressed.emit()

	assert_eq(_chosen, [12] as Array[int])
	assert_false(menu.is_open())
	assert_false(menu.visible)


func test_a_click_outside_closes_it_without_choosing() -> void:
	var menu: OptionMenu = _menu()
	menu.open(_options(2), Vector2(600, 300), FIELD)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true

	menu._gui_input(click)

	assert_false(menu.is_open())
	assert_eq(_chosen.size(), 0)


func test_it_says_when_it_closes_but_only_if_it_was_open() -> void:
	var menu: OptionMenu = _menu()
	var closes: Array[int] = []
	menu.closed.connect(func() -> void: closes.append(1))

	menu.close()
	assert_eq(closes.size(), 0, "It was not open.")
	menu.open(_options(2), Vector2(600, 300), FIELD)
	assert_eq(closes.size(), 0, "Opening a closed menu closes nothing.")
	menu.close()
	assert_eq(closes.size(), 1)
	menu.open(_options(2), Vector2(600, 300), FIELD)
	menu.rows()[0].pressed.emit()
	assert_eq(closes.size(), 2, "Choosing a row closes it too.")


func test_letting_go_of_the_button_or_moving_the_mouse_outside_does_not_close_it() -> void:
	var menu: OptionMenu = _menu()
	menu.open(_options(2), Vector2(600, 300), FIELD)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false

	menu._gui_input(release)
	menu._gui_input(InputEventMouseMotion.new())

	assert_true(menu.is_open(), "The click that opened it is still being let go of.")


func test_pointing_at_a_row_says_its_text_and_leaving_or_closing_says_nothing() -> void:
	var menu: OptionMenu = _menu()
	menu.open(_options(2), Vector2(600, 300), FIELD)
	_pointed.clear()

	menu.rows()[1].mouse_entered.emit()
	menu.rows()[1].mouse_exited.emit()
	menu.rows()[0].mouse_entered.emit()
	menu.close()

	assert_eq(_pointed, ["Option 2", "", "Option 1", ""] as Array[String])


func test_it_says_which_answer_the_cursor_is_over() -> void:
	var menu: OptionMenu = _menu()
	var options: Array[ClickOption] = _options(2)
	assert_eq(menu.pointed_answer(), OptionMenu.NO_ANSWER)
	menu.open(options, Vector2(600, 300), FIELD)
	assert_eq(menu.pointed_answer(), OptionMenu.NO_ANSWER, "Open, with the cursor on no row.")

	menu.rows()[1].mouse_entered.emit()
	assert_eq(menu.pointed_answer(), options[1].answer)
	# Godot tells the row entered before the row left.
	menu.rows()[0].mouse_entered.emit()
	menu.rows()[1].mouse_exited.emit()
	assert_eq(menu.pointed_answer(), options[0].answer)
	menu.rows()[0].mouse_exited.emit()
	assert_eq(menu.pointed_answer(), OptionMenu.NO_ANSWER)

	menu.rows()[0].mouse_entered.emit()
	menu.close()
	assert_eq(menu.pointed_answer(), OptionMenu.NO_ANSWER, "A closed menu points at nothing.")


func test_opening_again_replaces_the_rows() -> void:
	var menu: OptionMenu = _menu()
	menu.open(_options(3), Vector2(600, 300), FIELD)

	menu.open(_options(2), Vector2(700, 400), FIELD)

	assert_eq(menu.rows().size(), 2)
	assert_eq(menu.box_rect().position, Vector2(700, 400))


func test_a_row_brightens_under_the_cursor() -> void:
	var menu: OptionMenu = _menu()
	menu.open(_options(2), Vector2(600, 300), FIELD)
	var row: Button = menu.rows()[0]

	var normal: Color = (row.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	var hover: Color = (row.get_theme_stylebox("hover") as StyleBoxFlat).bg_color

	assert_gt(hover.get_luminance(), normal.get_luminance())


func test_every_row_draws_its_mana_symbols_as_pips() -> void:
	# Game ADR 0073: a row is written with a SymbolLabel, as the Info Panel is, never as a
	# button's text, which shows the braces.
	var menu: OptionMenu = _menu()
	var options: Array[ClickOption] = [ClickOption.new(3, "{T}: Add {G}.", true), ClickOption.new(4, "{T}: Add {W}.", true)]

	menu.open(options, Vector2(600, 300), FIELD)

	assert_eq(menu.words().size(), 2)
	assert_eq(menu.words()[0].written(), "{T}: Add {G}.")
	assert_eq(menu.words()[0].symbols(), ["t", "g"] as Array[String])
	assert_eq(menu.words()[1].symbols(), ["t", "w"] as Array[String])
	assert_eq(menu.rows()[0].text, "", "No braces drawn.")
	assert_true(menu.rows()[0].is_ancestor_of(menu.words()[0]))
	assert_eq(menu.words()[0].mouse_filter, Control.MOUSE_FILTER_IGNORE, "The row takes the click.")


func test_a_row_reads_its_row_text_and_the_info_panel_is_told_its_text_in_full() -> void:
	var menu: OptionMenu = _menu()
	var white: ClickOption = ClickOption.new(7, "{T}, Sacrifice this token: Add {W}.", true)
	white.row_text = "Add {W}"
	menu.open([white] as Array[ClickOption], Vector2(600, 300), FIELD)
	_pointed.clear()

	menu.rows()[0].mouse_entered.emit()

	assert_eq(menu.words()[0].written(), "Add {W}")
	assert_eq(menu.words()[0].symbols(), ["w"] as Array[String])
	assert_eq(_pointed, ["{T}, Sacrifice this token: Add {W}."] as Array[String])


func test_a_row_reads_its_text_unless_told_otherwise() -> void:
	assert_eq(ClickOption.new(3, "{T}: Add {G}.", true).row_text, "{T}: Add {G}.")
	assert_eq(ClickOption.new(3, "Cast Hill Giant").mana_type, MmMana.NO_TYPE)
	assert_false(ClickOption.new(3, "Cast Hill Giant").has_glow)


func test_a_menu_of_the_five_colors_shows_all_five_rows() -> void:
	var menu: OptionMenu = _menu()

	menu.open(_colors(), Vector2(600, 300), FIELD)

	assert_eq(menu.rows().size(), 5)
	assert_eq(menu.box_rect().size, EncounterLayout.menu_rect(Vector2(600, 300), 5, FIELD, 5).size)
	var five: float = 5.0 * EncounterLayout.MENU_ROW + 4.0 * EncounterLayout.MENU_GAP + EncounterLayout.MENU_PAD * 2.0
	assert_eq(menu.box_rect().size.y, five, "Every color in sight, none scrolled to.")
	var scroll: ScrollContainer = menu.rows()[0].get_parent().get_parent() as ScrollContainer
	assert_gte(scroll.custom_minimum_size.y, five - EncounterLayout.MENU_PAD * 2.0)


func test_only_a_menu_of_colors_shows_more_than_three_rows() -> void:
	var five: Array[ClickOption] = _options(5)

	assert_eq(OptionMenu.most_rows_shown(five), EncounterLayout.MENU_ROWS_SHOWN, "A286: three, and scroll.")
	assert_eq(OptionMenu.most_rows_shown(_colors()), 5)
	assert_eq(OptionMenu.most_rows_shown(_options(2)), EncounterLayout.MENU_ROWS_SHOWN)


func test_a_row_that_has_a_glow_glows_green_and_the_others_do_not() -> void:
	var menu: OptionMenu = _menu()
	var options: Array[ClickOption] = _colors()
	options[0].has_glow = true

	menu.open(options, Vector2(600, 300), FIELD)

	var green: Color = DecisionClicks.color_of(DecisionClicks.Kind.PLAY)
	assert_eq(BorderEffects.glow_colors(menu.rows()[0]), [green] as Array[Color])
	for index: int in range(1, 5):
		assert_eq(BorderEffects.glow_colors(menu.rows()[index]), [] as Array[Color], "Row %d pays nothing owed." % index)
	var scroll: ScrollContainer = menu.rows()[0].get_parent().get_parent() as ScrollContainer
	assert_false(scroll.clip_contents, "Nothing scrolls, so the Glow is not cut off at the menu's edge.")


func _options(count: int) -> Array[ClickOption]:
	var options: Array[ClickOption] = []
	for index: int in count:
		options.append(ClickOption.new(10 + index, "Option %d" % (index + 1)))
	return options


func _menu() -> OptionMenu:
	var menu: OptionMenu = OptionMenu.new()
	add_child_autofree(menu)
	menu.chosen.connect(func(answer: int) -> void: _chosen.append(answer))
	menu.pointed.connect(func(text: String) -> void: _pointed.append(text))
	return menu


## A row for each color of a Treasure's mana, as DecisionClicks makes them.
func _colors() -> Array[ClickOption]:
	var options: Array[ClickOption] = []
	for color: MmMana.Type in MmMana.COLORS:
		var option: ClickOption = ClickOption.new(20 + color, "{T}, Sacrifice this token: Add {%s}." % MmMana.SYMBOLS[color], true)
		option.row_text = "Add {%s}" % MmMana.SYMBOLS[color]
		option.mana_type = color
		options.append(option)
	return options
