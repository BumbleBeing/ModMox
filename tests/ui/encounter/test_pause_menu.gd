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


func test_its_first_page_has_four_rows() -> void:
	var menu: PauseMenu = _menu()
	menu.open(FIELD, true)

	assert_eq(menu.page(), PauseMenu.Page.MENU)
	assert_eq(menu.heading_text(), "Paused")
	for text: String in [PauseMenu.RESUME, PauseMenu.CONCEDE, PauseMenu.SETTINGS, PauseMenu.QUIT]:
		assert_not_null(menu.button(text), text)
	assert_false(menu.button(PauseMenu.SETTINGS).disabled)
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


func test_settings_opens_a_page_with_the_game_speeds_and_the_one_in_use_marked() -> void:
	var menu: PauseMenu = _menu()
	menu.show_game_speed(GameSpeed.Speed.FAST)
	menu.open(FIELD, true)

	menu.button(PauseMenu.SETTINGS).pressed.emit()

	assert_eq(menu.page(), PauseMenu.Page.SETTINGS)
	assert_eq(menu.heading_text(), "Settings")
	assert_not_null(menu.button(PauseMenu.BACK))
	assert_null(menu.button(PauseMenu.RESUME))
	var last_x: float = -1.0
	for speed: GameSpeed.Speed in GameSpeed.ALL:
		var made: Button = menu.speed_button(speed)
		assert_eq(made.text, GameSpeed.name_of(speed))
		assert_eq(menu.is_speed_chosen(speed), speed == GameSpeed.Speed.FAST, made.text)
		assert_gt(made.position.x, last_x, "Slowest at the left.")
		assert_true(Rect2(Vector2.ZERO, menu.window_rect().size).encloses(Rect2(made.position, made.size)), made.text)
		last_x = made.position.x
	assert_lt(menu.speed_button(GameSpeed.Speed.SLOW).position.y, menu.button(PauseMenu.BACK).position.y)


func test_pressing_a_speed_says_so_and_marks_it() -> void:
	var menu: PauseMenu = _menu()
	var chosen: Array[GameSpeed.Speed] = []
	menu.speed_chosen.connect(func(speed: GameSpeed.Speed) -> void: chosen.append(speed))
	menu.open(FIELD, true)
	menu.button(PauseMenu.SETTINGS).pressed.emit()
	assert_true(menu.is_speed_chosen(GameSpeed.Speed.NORMAL), "Normal until it is told otherwise.")

	menu.speed_button(GameSpeed.Speed.BLAZING).pressed.emit()

	assert_eq(chosen, [GameSpeed.Speed.BLAZING] as Array[GameSpeed.Speed])
	assert_eq(menu.page(), PauseMenu.Page.SETTINGS, "The page stays up.")
	assert_true(menu.is_speed_chosen(GameSpeed.Speed.BLAZING))
	assert_false(menu.is_speed_chosen(GameSpeed.Speed.NORMAL))

	menu.button(PauseMenu.BACK).pressed.emit()
	assert_eq(menu.page(), PauseMenu.Page.MENU)
	assert_null(menu.speed_button(GameSpeed.Speed.FAST), "The speeds are on the settings page only.")


func test_the_settings_page_has_an_auto_pass_box_under_the_speeds() -> void:
	var menu: PauseMenu = _menu()
	var chosen: Array[bool] = []
	menu.auto_pass_chosen.connect(func(is_on: bool) -> void: chosen.append(is_on))
	menu.open(FIELD, true)
	assert_null(menu.auto_pass_button(), "It is on the settings page only.")

	menu.button(PauseMenu.SETTINGS).pressed.emit()

	var box: Button = menu.auto_pass_button()
	assert_eq(box.text, "☑  Auto-pass", "On until it is told otherwise.")
	assert_gt(box.position.y, menu.speed_button(GameSpeed.Speed.SLOW).position.y)
	assert_lt(box.position.y, menu.button(PauseMenu.BACK).position.y)
	assert_true(Rect2(Vector2.ZERO, menu.window_rect().size).encloses(Rect2(box.position, box.size)))

	box.pressed.emit()

	assert_eq(chosen, [false] as Array[bool])
	assert_eq(menu.auto_pass_button().text, "☐  Auto-pass")
	assert_eq(menu.page(), PauseMenu.Page.SETTINGS, "The page stays up.")


func test_the_auto_pass_box_shows_what_it_is_told() -> void:
	var menu: PauseMenu = _menu()
	menu.show_auto_pass(false)
	menu.open(FIELD, true)

	menu.button(PauseMenu.SETTINGS).pressed.emit()

	assert_eq(menu.auto_pass_button().text, "☐  Auto-pass")


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
