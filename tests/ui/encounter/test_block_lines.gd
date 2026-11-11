extends GutTest
## BlockLines draws a line from each blocker to its attacker.


func test_it_shows_the_lines_it_is_given_and_replaces_them_with_the_next() -> void:
	var lines: BlockLines = BlockLines.new()
	add_child_autofree(lines)
	assert_eq(lines.line_count(), 0)

	lines.show_lines([[Vector2(100, 500), Vector2(140, 440), true], [Vector2(300, 500), Vector2(140, 440), false]])

	assert_eq(lines.line_count(), 2)
	assert_eq(lines.line_from(0), Vector2(100, 500))
	assert_eq(lines.line_to(0), Vector2(140, 440))
	assert_eq(lines.line_to(1), lines.line_to(0), "Two blockers on one attacker meet at it.")

	lines.show_lines([])

	assert_eq(lines.line_count(), 0)


func test_a_block_still_being_chosen_is_gold_and_a_declared_one_white() -> void:
	var lines: BlockLines = BlockLines.new()
	add_child_autofree(lines)

	lines.show_lines([[Vector2(100, 500), Vector2(140, 440), true], [Vector2(300, 500), Vector2(140, 440), false]])

	assert_eq(lines.line_color(0), BlockLines.CHOSEN)
	assert_eq(lines.line_color(1), BlockLines.DECLARED)
	assert_ne(BlockLines.CHOSEN, BlockLines.DECLARED)


func test_it_covers_the_screen_and_never_takes_the_mouse() -> void:
	var lines: BlockLines = BlockLines.new()
	add_child_autofree(lines)

	assert_eq(lines.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(lines.anchor_right, 1.0)
	assert_eq(lines.anchor_bottom, 1.0)


func test_changing_what_was_given_afterwards_does_not_change_what_is_shown() -> void:
	var lines: BlockLines = BlockLines.new()
	add_child_autofree(lines)
	var given: Array = [[Vector2(100, 500), Vector2(140, 440), true]]

	lines.show_lines(given)
	(given[0] as Array)[0] = Vector2(999, 999)
	given.clear()

	assert_eq(lines.line_count(), 1)
	assert_eq(lines.line_from(0), Vector2(100, 500))


func test_it_draws_without_error_even_a_line_of_no_length() -> void:
	var lines: BlockLines = BlockLines.new()
	add_child_autofree(lines)

	lines.show_lines([[Vector2(100, 500), Vector2(140, 440), true], [Vector2(50, 50), Vector2(50, 50), false]])
	await wait_process_frames(2)

	assert_eq(lines.line_count(), 2)
