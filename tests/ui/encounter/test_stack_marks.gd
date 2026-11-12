extends GutTest
## What the Stack Window entry under the cursor marks on the board (A337, A346): its
## source with a solid border and its targets with a dashed one, in place of their Glow.

const SIZE: Vector2 = Vector2(120, 100)


func after_each() -> void:
	# A mark that was taken away is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_mark_has_its_color_and_is_solid_or_dashed() -> void:
	var source: Control = _host()
	var target: Control = _host()

	BorderEffects.add_mark(source, SIZE, Color.RED, false)
	BorderEffects.add_mark(target, SIZE, Color.BLUE, true)

	assert_eq(BorderEffects.mark_color(source), Color.RED)
	assert_false(BorderEffects.is_mark_dashed(source))
	assert_eq(BorderEffects.mark_color(target), Color.BLUE)
	assert_true(BorderEffects.is_mark_dashed(target))


func test_something_unmarked_has_no_mark() -> void:
	var host: Control = _host()

	assert_null(BorderEffects.mark_color(host))
	assert_false(BorderEffects.is_mark_dashed(host))
	assert_false(BorderEffects.is_glow_showing(host))


func test_a_mark_takes_the_place_of_the_glow_until_it_is_removed() -> void:
	var host: Control = _host()
	BorderEffects.add_glow(host, SIZE, Color.GREEN)
	assert_true(BorderEffects.is_glow_showing(host))

	BorderEffects.add_mark(host, SIZE, Color.RED, true)
	assert_false(BorderEffects.is_glow_showing(host))
	assert_eq(BorderEffects.glow_color(host), Color.GREEN, "The Glow is hidden, not gone.")

	BorderEffects.remove_mark(host)
	assert_true(BorderEffects.is_glow_showing(host))
	assert_null(BorderEffects.mark_color(host))


func test_marking_again_replaces_the_mark() -> void:
	var host: Control = _host()
	BorderEffects.add_mark(host, SIZE, Color.RED, true)

	BorderEffects.add_mark(host, SIZE, Color.BLUE, false)

	assert_eq(BorderEffects.mark_color(host), Color.BLUE)
	assert_false(BorderEffects.is_mark_dashed(host))


func test_a_dashed_border_runs_outside_what_it_marks() -> void:
	var border: DashedBorder = autofree(DashedBorder.new(SIZE, Color.RED, 3.0, 4.0))

	assert_eq(border.color(), Color.RED)
	assert_eq(border.outline(), Rect2(Vector2(-4, -4), SIZE + Vector2(8, 8)))
	assert_eq(border.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func _host() -> Control:
	var host: Control = Control.new()
	host.size = SIZE
	add_child_autofree(host)
	return host


func test_setting_a_glow_replaces_the_one_that_was_there() -> void:
	var host: Control = Control.new()
	add_child_autofree(host)
	BorderEffects.set_glow(host, SIZE, Color.GREEN)
	assert_eq(BorderEffects.glow_color(host), Color.GREEN, "With none to replace, it is simply added.")

	var old: Node = host.get_child(0)
	BorderEffects.set_glow(host, SIZE, Color.RED)

	assert_true(old.is_queued_for_deletion(), "The old one is freed, not left behind.")
	assert_eq(BorderEffects.glow_color(host), Color.RED)
	assert_eq(host.get_child_count(), 1)
	assert_true(BorderEffects.is_glow_showing(host))
