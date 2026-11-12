extends GutTest
## Windows ease in and out as Glows do. One closing is closed at once to anyone who asks and
## to the mouse; it is only drawn while it fades. Given no time, as in tests and
## screenshots, they come and go at once.

const SECONDS: float = 0.2
const FIELD: Rect2 = Rect2(352, 86, 1386, 806)


func after_each() -> void:
	await wait_process_frames(2)


func test_a_zone_window_eases_in_and_out() -> void:
	var window: ZoneWindow = _window()

	window.open()

	assert_true(window.is_open())
	assert_true(window.visible)
	assert_eq(window.modulate.a, 0.0, "It starts unseen.")
	await wait_seconds(SECONDS / 2.0)
	assert_between(window.modulate.a, 0.05, 0.99, "Partway.")
	await wait_seconds(SECONDS)
	assert_eq(window.modulate.a, 1.0)

	window.close()

	assert_false(window.is_open(), "Closed at once.")
	assert_true(window.visible, "But drawn while it fades.")
	assert_eq(window.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED, "And deaf to the mouse.")
	await wait_seconds(SECONDS * 1.5)
	assert_false(window.visible)
	assert_eq(window.modulate.a, 1.0, "Ready to be drawn whole when shown at once.")
	assert_eq(window.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED)


func test_a_window_opened_again_while_it_fades_out_comes_back_from_where_it_was() -> void:
	var window: ZoneWindow = _window()
	window.open()
	await wait_seconds(SECONDS * 1.5)
	window.close()
	await wait_seconds(SECONDS / 2.0)
	var partway: float = window.modulate.a

	window.open()

	assert_true(window.is_open())
	assert_gte(window.modulate.a, partway, "Not started over.")
	assert_eq(window.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED)
	await wait_seconds(SECONDS * 1.5)
	assert_true(window.visible, "The fade out it interrupted does not hide it.")
	assert_eq(window.modulate.a, 1.0)


func test_opening_a_window_already_open_leaves_it_as_it_is() -> void:
	var window: ZoneWindow = _window()
	window.open()
	await wait_seconds(SECONDS * 1.5)

	window.set_open(true)

	assert_eq(window.modulate.a, 1.0)


func test_a_window_given_no_time_comes_and_goes_at_once() -> void:
	var window: ZoneWindow = _window()
	window.ease_seconds = 0.0

	window.open()
	assert_eq(window.modulate.a, 1.0)
	window.close()
	assert_false(window.visible)


func test_the_close_button_eases_the_window_out() -> void:
	var window: ZoneWindow = _window()
	window.open()

	window.close_button().pressed.emit()

	assert_false(window.is_open())
	assert_true(window.visible)


func test_the_option_menu_eases_in_and_out_and_takes_no_clicks_once_closed() -> void:
	var menu: OptionMenu = OptionMenu.new()
	menu.ease_seconds = SECONDS
	add_child_autofree(menu)

	menu.open([ClickOption.new(1, "One")] as Array[ClickOption], Vector2(600, 300), FIELD)

	var box: Control = menu.get_child(-1)
	assert_eq(box.modulate.a, 0.0)
	await wait_seconds(SECONDS * 1.5)
	assert_eq(box.modulate.a, 1.0)

	menu.close()

	assert_false(menu.is_open())
	assert_eq(menu.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED)
	assert_eq(box.get_parent(), menu, "Still drawn while it fades.")

	menu.open([ClickOption.new(2, "Two")] as Array[ClickOption], Vector2(700, 300), FIELD)

	assert_true(menu.is_open(), "Opened at once somewhere else.")
	assert_eq(menu.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED)
	assert_eq(menu.rows()[0].text, "Two")
	await wait_seconds(SECONDS * 1.5)
	assert_false(is_instance_valid(box), "The old box is gone once faded.")
	assert_true(menu.visible)
	menu.close()
	await wait_seconds(SECONDS * 1.5)
	assert_false(menu.visible)
	assert_eq(menu.get_child_count(), 0)


func test_the_pause_menu_eases_in_and_out() -> void:
	var menu: PauseMenu = PauseMenu.new()
	menu.ease_seconds = SECONDS
	add_child_autofree(menu)

	menu.open(FIELD, true)

	assert_true(menu.is_open())
	assert_eq(menu.modulate.a, 0.0)
	await wait_seconds(SECONDS * 1.5)
	assert_eq(menu.modulate.a, 1.0)

	menu.close()

	assert_false(menu.is_open())
	assert_true(menu.visible)
	assert_eq(menu.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED)
	await wait_seconds(SECONDS * 1.5)
	assert_false(menu.visible)


func test_the_screen_gives_every_window_its_time() -> void:
	var screen: EncounterScreen = EncounterScreen.new()
	screen.starts_itself = false
	add_child_autofree(screen)

	screen.set_ease_seconds(SECONDS)

	for window: ZoneWindow in [screen.stack_window(), screen.choice_window(),
			screen.emblems_window(MmEncounterSetup.HERO_PLAYER_ID), screen.emblems_window(MmEncounterSetup.VILLAIN_PLAYER_ID)]:
		assert_eq(window.ease_seconds, SECONDS)
	assert_eq(screen.option_menu().ease_seconds, SECONDS)
	assert_eq(screen.pause_menu().ease_seconds, SECONDS)


func _window() -> ZoneWindow:
	var window: ZoneWindow = ZoneWindow.new("Emblems", true, Color.GOLD)
	window.size = Vector2(300, 200)
	window.ease_seconds = SECONDS
	window.hide()
	add_child_autofree(window)
	return window
