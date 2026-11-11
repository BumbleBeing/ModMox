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
	assert_eq(menu.rows()[0].text, "Option 1")
	assert_eq(menu.rows()[1].text, "Option 2")
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
