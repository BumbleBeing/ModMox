extends GutTest
## Every zone's window is titled with its name and count, stays inside its bounds however
## it is dragged or resized, and keeps its place while hidden. All but the Stack Window can
## be closed.


func test_the_title_is_the_zones_name_and_its_count() -> void:
	var window: ZoneWindow = _window("Stack", false)

	window.show_count(2)

	assert_eq(window.title_text(), "Stack (2)")


func test_a_window_that_can_close_hides_on_its_x_and_the_stack_window_has_none() -> void:
	var emblems: ZoneWindow = _window("Emblems", true)
	var stack: ZoneWindow = _window("Stack", false)

	emblems.close_button().pressed.emit()

	assert_false(emblems.visible)
	assert_null(stack.close_button())


func test_the_x_is_no_taller_than_the_title_bar() -> void:
	var window: ZoneWindow = _window("Emblems", true)

	assert_lt(window.close_button().offset_bottom - window.close_button().offset_top, ZoneWindow.BAR_HEIGHT)
	assert_gt(window.close_button().offset_top, 0.0)


func test_the_x_is_46_pixels_wide_and_red_with_a_dark_border() -> void:
	var close: Button = _window("Emblems", true).close_button()

	assert_eq(close.offset_right - close.offset_left, 46.0)
	var style: StyleBoxFlat = close.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(style.bg_color, Color("#bb0a21"))
	assert_eq(style.border_color, Color("#5e0510"), "A darker red border round it.")
	assert_eq(style.border_width_left, 2)


func test_dragging_cannot_take_it_out_of_its_bounds() -> void:
	var window: ZoneWindow = _window("Stack", false)
	window.bounds = Rect2(100, 100, 800, 600)
	window.position = Vector2(200, 200)

	window.drag_by(Vector2(5000, -5000))

	assert_eq(window.position, Vector2(900 - window.size.x, 100))


func test_resizing_stops_at_its_bounds_and_at_its_smallest_size() -> void:
	var window: ZoneWindow = _window("Stack", false)
	window.bounds = Rect2(100, 100, 800, 600)
	window.position = Vector2(100, 100)

	window.resize_by(Vector2(5000, 5000))
	assert_eq(window.size, Vector2(800, 600))

	window.resize_by(Vector2(-5000, -5000))
	assert_eq(window.size, ZoneWindow.SMALLEST)


func test_the_corner_stays_under_the_cursor_after_the_cursor_leaves_the_bounds_and_comes_back() -> void:
	var view: SubViewport = _viewport()
	var window: ZoneWindow = _window("Stack", false, view)
	window.bounds = Rect2(100, 100, 800, 600)
	window.position = Vector2(200, 200)
	var corner: Vector2 = window.position + window.size - Vector2(4, 4)

	_press(view, corner)
	_move(view, corner, Vector2(1400, 1000))
	assert_eq(window.size, Vector2(700, 500), "Out past the bounds, it stops at them.")
	_move(view, Vector2(1400, 1000), Vector2(1000, 850))
	assert_eq(window.size, Vector2(700, 500), "Coming back, it waits until the cursor reaches the corner.")
	_move(view, Vector2(1000, 850), Vector2(700, 600))
	assert_eq(window.position + window.size - Vector2(4, 4), Vector2(700, 600), "Then the corner is under the cursor again.")
	_move(view, Vector2(700, 600), Vector2(-500, -500))
	assert_eq(window.size, ZoneWindow.SMALLEST, "Shrunk past its smallest, it stops there.")
	_move(view, Vector2(-500, -500), Vector2(300, 300))
	assert_eq(window.size, ZoneWindow.SMALLEST, "And waits for the cursor to come back to the corner.")
	_move(view, Vector2(300, 300), Vector2(500, 450))
	assert_eq(window.position + window.size - Vector2(4, 4), Vector2(500, 450))
	view.push_input(_click(false, Vector2(500, 450)))


func test_resizing_past_the_bounds_never_moves_the_window() -> void:
	var view: SubViewport = _viewport()
	var window: ZoneWindow = _window("Stack", false, view)
	window.bounds = Rect2(100, 100, 800, 600)
	window.position = Vector2(500, 400)
	var corner: Vector2 = window.position + window.size - Vector2(4, 4)

	_press(view, corner)
	_move(view, corner, Vector2(1400, 1000))

	assert_eq(window.position, Vector2(500, 400), "Its top left stays where it was.")
	assert_eq(window.position + window.size, Vector2(900, 700), "It grows to the edge of its bounds.")
	view.push_input(_click(false, Vector2(1400, 1000)))


func test_the_title_bar_stays_under_the_cursor_after_the_cursor_leaves_the_bounds_and_comes_back() -> void:
	var view: SubViewport = _viewport()
	var window: ZoneWindow = _window("Stack", false, view)
	window.bounds = Rect2(100, 100, 800, 600)
	window.position = Vector2(200, 200)
	var grab: Vector2 = window.position + Vector2(100, 10)

	_press(view, grab)
	_move(view, grab, Vector2(1500, 300))
	assert_eq(window.position, Vector2(600, 290), "Stopped at the right edge.")
	_move(view, Vector2(1500, 300), Vector2(1100, 300))
	assert_eq(window.position, Vector2(600, 290), "Coming back, it waits for the cursor.")
	_move(view, Vector2(1100, 300), Vector2(500, 350))
	assert_eq(window.position, Vector2(400, 340), "Then it is held where it was grabbed again.")
	view.push_input(_click(false, Vector2(500, 350)))


func test_shrinking_its_bounds_moves_and_shrinks_it_to_fit() -> void:
	var window: ZoneWindow = _window("Stack", false)
	window.bounds = Rect2(0, 0, 1000, 1000)
	window.position = Vector2(600, 600)

	window.bounds = Rect2(0, 0, 250, 250)
	window.fit()

	assert_true(window.bounds.encloses(Rect2(window.position, window.size)))


func test_it_keeps_its_place_and_size_while_hidden() -> void:
	var window: ZoneWindow = _window("Emblems", true)
	window.bounds = Rect2(0, 0, 1000, 1000)
	window.position = Vector2(300, 200)
	window.resize_by(Vector2(40, 30))
	var place: Vector2 = window.position
	var extent: Vector2 = window.size

	window.hide()
	window.show()

	assert_eq(window.position, place)
	assert_eq(window.size, extent)


func test_clearing_empties_its_contents_which_are_clipped_to_it() -> void:
	var window: ZoneWindow = _window("Emblems", true)
	window.body().add_child(Label.new())

	window.clear()
	await wait_process_frames(2)

	assert_eq(window.body().get_child_count(), 0)
	assert_true(window.clip_contents)


func test_a_button_baked_into_the_bottom_edge_stays_centered_in_its_strip_however_it_is_resized() -> void:
	# Game ADR 0085: as the title bar runs along the top, a strip as tall as the button.
	var window: ZoneWindow = _window("Look", false)
	var button: Button = Button.new()

	window.bake_button(button, Vector2(200, 40))

	var strip: Control = window.edge_strip()
	assert_eq(strip.size.y, 40.0, "As tall as the button.")
	assert_almost_eq(strip.get_rect().end.y, window.size.y - 2.0, 0.01, "Along the bottom edge, inside the border.")
	assert_almost_eq(strip.size.x, window.size.x - 4.0, 0.01)
	assert_almost_eq(button.size, Vector2(200, 40), Vector2(0.01, 0.01))
	assert_almost_eq(button.get_global_rect().get_center().x, window.get_global_rect().get_center().x, 0.5)
	assert_lt(window.scroll().get_rect().end.y, strip.get_rect().position.y, "The contents end above it.")
	window.resize_by(Vector2(120, 60))
	assert_almost_eq(button.get_global_rect().get_center().x, window.get_global_rect().get_center().x, 0.5, "Still centered.")
	assert_almost_eq(button.get_global_rect().end.y, window.get_global_rect().end.y - 2.0, 0.5, "Still on the bottom edge.")
	assert_eq(window.get_child(window.get_child_count() - 1).mouse_default_cursor_shape, Control.CURSOR_FDIAGSIZE,
		"The resize grip stays on top of the strip.")


func test_the_size_around_contents_leaves_room_for_a_baked_strip() -> void:
	var inner: Vector2 = Vector2(400, 200)

	assert_eq(ZoneWindow.size_around(inner), Vector2(420, 200 + ZoneWindow.BAR_HEIGHT + 22.0))
	assert_eq(ZoneWindow.size_around(inner, 40.0), Vector2(420, 200 + ZoneWindow.BAR_HEIGHT + 8.0 + ZoneWindow.EDGE_GAP + 40.0 + 2.0))


func _window(zone_name: String, can_close: bool, parent: Node = null) -> ZoneWindow:
	var window: ZoneWindow = ZoneWindow.new(zone_name, can_close, Color.WHITE)
	window.size = Vector2(300, 220)
	if parent == null:
		add_child_autofree(window)
	else:
		parent.add_child(window)
	return window


## A viewport of its own, so events pushed into it go through Godot's own picking.
func _viewport() -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	add_child_autofree(view)
	return view


func _press(view: SubViewport, at: Vector2) -> void:
	view.push_input(_motion(at, Vector2.ZERO))
	view.push_input(_click(true, at))


## Moves the cursor from [param from] to [param to] in steps, as a hand does.
func _move(view: SubViewport, from: Vector2, to: Vector2) -> void:
	var steps: int = 8
	var last: Vector2 = from
	for step: int in range(1, steps + 1):
		var at: Vector2 = from.lerp(to, float(step) / steps)
		view.push_input(_motion(at, at - last))
		last = at


func _motion(at: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.relative = relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	return motion


func _click(is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click
