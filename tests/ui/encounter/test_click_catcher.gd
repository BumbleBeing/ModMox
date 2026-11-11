extends GutTest
## A ClickCatcher makes the thing it covers take clicks, and only left clicks.

var _clicks: int = 0


func before_each() -> void:
	_clicks = 0


func test_it_covers_its_host_as_a_child_and_can_be_found_again() -> void:
	var host: Control = _host()
	assert_null(ClickCatcher.of(host), "Until one is added, the host does not take clicks.")

	var catcher: ClickCatcher = ClickCatcher.add(host, Vector2(120, 90))

	assert_eq(catcher.get_parent(), host)
	assert_eq(catcher.size, Vector2(120, 90))
	assert_eq(catcher.position, Vector2.ZERO)
	assert_eq(catcher.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(catcher.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
	assert_eq(ClickCatcher.of(host), catcher)


func test_a_left_press_is_a_click_and_nothing_else_is() -> void:
	var catcher: ClickCatcher = ClickCatcher.add(_host(), Vector2(120, 90))
	catcher.clicked.connect(func() -> void: _clicks += 1)

	catcher._gui_input(_button(MOUSE_BUTTON_LEFT, false))
	catcher._gui_input(_button(MOUSE_BUTTON_RIGHT, true))
	catcher._gui_input(_button(MOUSE_BUTTON_WHEEL_UP, true))
	catcher._gui_input(InputEventMouseMotion.new())
	assert_eq(_clicks, 0, "Right-click is kept for the inspector (13h).")

	catcher._gui_input(_button(MOUSE_BUTTON_LEFT, true))

	assert_eq(_clicks, 1)


func test_its_host_brightens_under_the_cursor() -> void:
	var host: Control = _host()
	var catcher: ClickCatcher = ClickCatcher.add(host, Vector2(120, 90))

	catcher.mouse_entered.emit()
	assert_eq(host.modulate, ClickCatcher.BRIGHT)
	assert_gt(ClickCatcher.BRIGHT.r, 1.0)

	catcher.mouse_exited.emit()
	assert_eq(host.modulate, Color.WHITE)


func _host() -> Control:
	var host: Control = Control.new()
	add_child_autofree(host)
	return host


func _button(index: MouseButton, is_pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = index
	event.pressed = is_pressed
	return event
