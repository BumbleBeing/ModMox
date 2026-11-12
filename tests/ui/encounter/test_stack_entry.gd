extends GutTest
## A Stack Window entry: two cut lines, its color on its border and stripe, the Glow's
## color on its border while it can be chosen, and move buttons while it is being ordered.

const COLOR: Color = Color("#9a86c9")


func test_it_shows_its_two_lines_each_cut_to_one_line_with_an_ellipsis() -> void:
	var entry: StackEntry = _entry("This creature deals 1 damage to any target.", "Hero → Villain")

	assert_eq(entry.name_text(), "This creature deals 1 damage to any target.")
	assert_eq(entry.detail_text(), "Hero → Villain")
	assert_true(entry.is_cut())


func test_a_long_first_line_does_not_make_the_entry_taller_or_wider() -> void:
	var short: StackEntry = _entry("Bolt", "Hero")
	var long: StackEntry = _entry("At the beginning of your upkeep, you gain X life, where X is the number of cards in your hand minus 4.", "Hero")
	short.size.x = 300
	long.size.x = 300
	await wait_process_frames(2)

	assert_eq(long.size.y, short.size.y)
	assert_eq(long.get_combined_minimum_size().x, short.get_combined_minimum_size().x)


func test_a_stack_object_has_its_color_on_its_border_and_its_stripe() -> void:
	var entry: StackEntry = _entry("Bolt", "Hero")

	assert_eq(entry.color(), COLOR)
	assert_eq(entry.border_color(), COLOR)
	assert_eq(entry.stripe_color(), COLOR)
	assert_false(entry.is_dashed())
	assert_null(entry.click_catcher(), "It takes no click unless it can be chosen.")
	assert_null(entry.up_button())


func test_one_that_can_be_chosen_glows_as_a_target_and_keeps_its_stripe() -> void:
	var entry: StackEntry = _entry("Bolt", "Hero")
	watch_signals(entry)

	var catcher: ClickCatcher = entry.make_targetable()

	assert_eq(entry.border_color(), DecisionClicks.color_of(DecisionClicks.Kind.TARGET))
	assert_eq(entry.stripe_color(), COLOR, "Still recognizable (A354).")
	assert_eq(entry.color(), COLOR)
	assert_eq(entry.click_catcher(), catcher)
	catcher.mouse_entered.emit()
	assert_signal_emitted_with_parameters(entry, "hovered", [true])
	catcher.mouse_exited.emit()
	assert_signal_emitted_with_parameters(entry, "hovered", [false])


func test_the_cursor_coming_and_going_is_reported() -> void:
	var entry: StackEntry = _entry("Bolt", "Hero")
	watch_signals(entry)

	entry.mouse_entered.emit()
	assert_signal_emitted_with_parameters(entry, "hovered", [true])
	entry.mouse_exited.emit()
	assert_signal_emitted_with_parameters(entry, "hovered", [false])


func test_a_trigger_being_ordered_is_dashed_with_no_stripe() -> void:
	var entry: StackEntry = StackEntry.new("", "You gain 1 life.", "Hero", StackColors.PLAIN, true)
	add_child_autofree(entry)

	assert_true(entry.is_dashed())
	assert_null(entry.stripe_color())
	assert_eq(entry.color(), StackColors.PLAIN)


func test_move_buttons_say_which_way_and_are_disabled_when_they_cannot_move() -> void:
	var entry: StackEntry = StackEntry.new("", "You gain 1 life.", "Hero", StackColors.PLAIN, true)
	add_child_autofree(entry)
	watch_signals(entry)

	entry.add_move_buttons(false, true)

	assert_true(entry.up_button().disabled)
	assert_false(entry.down_button().disabled)
	entry.down_button().pressed.emit()
	assert_signal_emitted_with_parameters(entry, "moved", [1])
	entry.up_button().pressed.emit()
	assert_signal_emitted_with_parameters(entry, "moved", [-1])


func test_move_buttons_can_be_the_other_way_round() -> void:
	var entry: StackEntry = StackEntry.new("", "You gain 1 life.", "Hero", StackColors.PLAIN, true)
	add_child_autofree(entry)

	entry.add_move_buttons(true, false)

	assert_false(entry.up_button().disabled)
	assert_true(entry.down_button().disabled)


func _entry(first: String, second: String) -> StackEntry:
	var entry: StackEntry = StackEntry.new("", first, second, COLOR)
	add_child_autofree(entry)
	return entry
