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


func _window(zone_name: String, can_close: bool) -> ZoneWindow:
	var window: ZoneWindow = ZoneWindow.new(zone_name, can_close, Color.WHITE)
	window.size = Vector2(300, 220)
	add_child_autofree(window)
	return window
