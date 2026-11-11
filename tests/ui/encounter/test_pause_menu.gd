extends GutTest
## The Pause Menu offers Resume, Concede, Settings and Quit, and asks once more before
## conceding or quitting.

const FIELD: Rect2 = Rect2(352, 86, 1386, 806)

var _events: Array[String] = []


func before_each() -> void:
	_events.clear()


func after_each() -> void:
	await wait_process_frames(2)


func test_it_is_hidden_until_opened_and_covers_the_screen_while_open() -> void:
	var menu: PauseMenu = _menu()
	assert_false(menu.is_open())

	menu.open(FIELD, true)

	assert_true(menu.is_open())
	assert_eq(menu.mouse_filter, Control.MOUSE_FILTER_STOP, "Nothing under it can be clicked.")
	assert_eq(menu.anchor_right, 1.0)
	assert_eq(menu.anchor_bottom, 1.0)
	assert_eq(menu.window_rect(), EncounterLayout.pause_rect(4, FIELD))

	menu.close()
	assert_false(menu.is_open())


func test_its_first_page_has_four_rows_with_settings_grayed_out() -> void:
	var menu: PauseMenu = _menu()
	menu.open(FIELD, true)

	assert_eq(menu.page(), PauseMenu.Page.MENU)
	assert_eq(menu.heading_text(), "Paused")
	for text: String in [PauseMenu.RESUME, PauseMenu.CONCEDE, PauseMenu.SETTINGS, PauseMenu.QUIT]:
		assert_not_null(menu.button(text), text)
	assert_true(menu.button(PauseMenu.SETTINGS).disabled, "Not built yet (A297).")
	assert_false(menu.button(PauseMenu.RESUME).disabled)
	assert_false(menu.button(PauseMenu.CONCEDE).disabled)
	assert_false(menu.button(PauseMenu.QUIT).disabled)
	assert_null(menu.button(PauseMenu.BACK))
	assert_lt(menu.button(PauseMenu.RESUME).position.y, menu.button(PauseMenu.CONCEDE).position.y)
	assert_lt(menu.button(PauseMenu.SETTINGS).position.y, menu.button(PauseMenu.QUIT).position.y)


func test_resume_says_so_at_once() -> void:
	var menu: PauseMenu = _menu()
	menu.open(FIELD, true)

	menu.button(PauseMenu.RESUME).pressed.emit()

	assert_eq(_events, ["resume"] as Array[String])


func test_concede_asks_once_more_before_it_is_confirmed() -> void:
	var menu: PauseMenu = _menu()
	menu.open(FIELD, true)

	menu.button(PauseMenu.CONCEDE).pressed.emit()

	assert_eq(_events.size(), 0, "Nothing happens on the first press.")
	assert_eq(menu.page(), PauseMenu.Page.CONCEDE)
	assert_eq(menu.heading_text(), "Concede this encounter?")
	assert_null(menu.button(PauseMenu.RESUME))
	assert_eq(menu.window_rect(), EncounterLayout.pause_rect(2, FIELD))

	menu.button(PauseMenu.CONCEDE).pressed.emit()

	assert_eq(_events, ["concede"] as Array[String])


func test_quit_asks_once_more_before_it_is_confirmed() -> void:
	var menu: PauseMenu = _menu()
	menu.open(FIELD, true)

	menu.button(PauseMenu.QUIT).pressed.emit()

	assert_eq(_events.size(), 0)
	assert_eq(menu.page(), PauseMenu.Page.QUIT)
	assert_string_contains(menu.heading_text(), "This encounter will be lost.")

	menu.button(PauseMenu.QUIT_NOW).pressed.emit()

	assert_eq(_events, ["quit"] as Array[String])


func test_back_returns_to_the_first_page_from_either_question() -> void:
	var menu: PauseMenu = _menu()
	menu.open(FIELD, true)

	menu.button(PauseMenu.CONCEDE).pressed.emit()
	menu.button(PauseMenu.BACK).pressed.emit()
	assert_eq(menu.page(), PauseMenu.Page.MENU)
	menu.button(PauseMenu.QUIT).pressed.emit()
	menu.button(PauseMenu.BACK).pressed.emit()

	assert_eq(menu.page(), PauseMenu.Page.MENU)
	assert_eq(_events.size(), 0)
	assert_not_null(menu.button(PauseMenu.RESUME))


func test_it_reopens_on_its_first_page() -> void:
	var menu: PauseMenu = _menu()
	menu.open(FIELD, true)
	menu.button(PauseMenu.QUIT).pressed.emit()
	menu.close()

	menu.open(FIELD, true)

	assert_eq(menu.page(), PauseMenu.Page.MENU)


func test_concede_is_grayed_out_once_the_encounter_is_over() -> void:
	var menu: PauseMenu = _menu()

	menu.open(FIELD, false)

	assert_true(menu.button(PauseMenu.CONCEDE).disabled)
	assert_false(menu.button(PauseMenu.QUIT).disabled)


func test_a_button_brightens_under_the_cursor_and_a_grayed_one_is_darker() -> void:
	var menu: PauseMenu = _menu()
	menu.open(FIELD, true)
	var resume: Button = menu.button(PauseMenu.RESUME)

	var normal: Color = (resume.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	var hover: Color = (resume.get_theme_stylebox("hover") as StyleBoxFlat).bg_color
	var disabled: Color = (resume.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color

	assert_gt(hover.get_luminance(), normal.get_luminance())
	assert_lt(disabled.get_luminance(), normal.get_luminance())


func _menu() -> PauseMenu:
	var menu: PauseMenu = PauseMenu.new()
	add_child_autofree(menu)
	menu.resume_pressed.connect(func() -> void: _events.append("resume"))
	menu.concede_confirmed.connect(func() -> void: _events.append("concede"))
	menu.quit_confirmed.connect(func() -> void: _events.append("quit"))
	return menu
