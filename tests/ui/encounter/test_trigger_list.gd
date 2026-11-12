extends GutTest
## The list triggers are dragged into order in (13e-2): a press becomes a drag after three
## pixels, the held entry follows the cursor up and down inside the list, the others make
## room, and letting go puts it down. Nothing is made again for any of it.

const WIDTH: float = 360.0

var _list: TriggerList
var _entries: Array[StackEntry]
var _height: float
var _moves: Array = []


func after_each() -> void:
	await wait_process_frames(2)


func test_the_entries_stand_in_the_order_given_each_as_wide_as_the_list() -> void:
	_open(3, [2, 0, 1])

	assert_eq(_list.order(), [2, 0, 1] as Array[int])
	assert_eq(_list.entries_in_order(), [_entries[2], _entries[0], _entries[1]] as Array[StackEntry])
	assert_eq(_entries[2].position, Vector2.ZERO)
	assert_eq(_entries[0].position, Vector2(0, _slot(1)))
	assert_eq(_entries[1].position, Vector2(0, _slot(2)))
	for entry: StackEntry in _entries:
		assert_eq(entry.size, Vector2(WIDTH, _height))
		assert_not_null(entry.grip())
		assert_eq(entry.get_parent(), _list)
	assert_eq(_list.custom_minimum_size.y, _slot(2) + _height, "Tall enough for all three, so its window can scroll to them.")
	assert_eq(_list.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Only its entries take the mouse.")
	assert_eq(_list.entry_of(1), _entries[1])


func test_it_fills_its_windows_width_and_its_entries_follow_when_that_changes() -> void:
	_open(3)
	assert_eq(_list.size_flags_horizontal, Control.SIZE_EXPAND_FILL)

	_list.size = Vector2(500, 400)

	for entry: StackEntry in _entries:
		assert_eq(entry.size.x, 500.0, "At once, without waiting for a frame.")


func test_its_entries_are_at_their_places_as_soon_as_it_is_in_the_tree() -> void:
	var entries: Array[StackEntry] = []
	for number: int in 3:
		entries.append(StackEntry.new("", "Trigger %d" % number, "Hero", StackColors.PLAIN, true))
	var list: TriggerList = TriggerList.new(entries, [2, 1, 0] as Array[int])
	list.set_process(false)

	add_child_autofree(list)

	var height: float = list.entry_height()
	assert_eq(entries[2].position.y, 0.0)
	assert_eq(entries[1].position.y, EncounterLayout.trigger_slot(1, height))
	assert_eq(entries[0].position.y, EncounterLayout.trigger_slot(2, height), "Never stacked on top of one another for a frame.")
	assert_eq(list.custom_minimum_size.y, EncounterLayout.trigger_list_height(3, height))


func test_the_layout_puts_each_place_one_entry_and_a_gap_below_the_last() -> void:
	assert_eq(EncounterLayout.trigger_slot(0, 60.0), 0.0)
	assert_eq(EncounterLayout.trigger_slot(2, 60.0), 132.0)
	assert_eq(EncounterLayout.trigger_list_height(3, 60.0), 192.0)
	assert_eq(EncounterLayout.trigger_list_height(1, 60.0), 60.0)
	assert_eq(EncounterLayout.trigger_list_height(0, 60.0), 0.0)
	assert_eq(EncounterLayout.trigger_held_top(100.0, 10.0, 3, 60.0), 90.0)
	assert_eq(EncounterLayout.trigger_held_top(-50.0, 10.0, 3, 60.0), 0.0, "Never above the list.")
	assert_eq(EncounterLayout.trigger_held_top(900.0, 10.0, 3, 60.0), 132.0, "Nor below its last place.")
	assert_eq(EncounterLayout.trigger_gap(0.0, 3, 60.0), 0)
	assert_eq(EncounterLayout.trigger_gap(32.0, 3, 60.0), 0)
	assert_eq(EncounterLayout.trigger_gap(34.0, 3, 60.0), 1, "Past halfway to the next place.")
	assert_eq(EncounterLayout.trigger_gap(132.0, 3, 60.0), 2)
	assert_eq(EncounterLayout.trigger_gap(999.0, 3, 60.0), 2)
	assert_eq(EncounterLayout.trigger_gap(-20.0, 3, 60.0), 0)


func test_a_press_is_not_a_drag_until_the_cursor_has_moved_three_pixels() -> void:
	_open(3)
	var at: Vector2 = Vector2(50, 20)

	_list.press(0, at)
	assert_true(_list.is_pressed())
	assert_false(_list.is_holding())
	assert_eq(_list.held_number(), 0)
	_list.drag_to(at + Vector2(0, 2.9))
	assert_false(_list.is_holding())
	assert_eq(_entries[0].position, Vector2.ZERO, "It has not moved.")
	_list.drag_to(at + Vector2(0, 3))

	assert_true(_list.is_holding())
	assert_true(_list.is_pressed(), "Held is still pressed: the mouse is followed.")


func test_sideways_counts_toward_picking_it_up_but_it_only_moves_up_and_down() -> void:
	_open(3)

	_list.press(1, Vector2(50, _slot(1) + 20.0))
	_list.drag_to(Vector2(90, _slot(1) + 20.0))

	assert_true(_list.is_holding())
	assert_eq(_entries[1].position, Vector2(0, _slot(1)))


func test_the_held_entry_follows_the_cursor_as_it_was_grabbed_over_the_rest_and_lit() -> void:
	_open(3)

	_list.press(0, Vector2(50, 20))
	_list.drag_to(Vector2(50, 70))

	assert_eq(_entries[0].position, Vector2(0, 50), "Grabbed twenty pixels below its top.")
	assert_eq(_entries[0].z_index, 1)
	assert_eq(_entries[0].modulate, TriggerList.HELD)
	assert_eq(_entries[1].z_index, 0)
	assert_eq(_entries[1].modulate, Color.WHITE)


func test_the_held_entry_stays_inside_the_list() -> void:
	_open(3)
	_list.press(1, Vector2(50, _slot(1) + 20.0))

	_list.drag_to(Vector2(50, -400))
	assert_eq(_entries[1].position.y, 0.0)
	_list.drag_to(Vector2(50, 4000))
	assert_eq(_entries[1].position.y, _slot(2))


func test_the_others_make_room_where_the_held_entry_would_be_put_down() -> void:
	_open(3)
	_list.press(0, Vector2(50, 20))

	_list.drag_to(Vector2(50, _slot(2) + 20.0))
	_list.place(1.0)

	assert_eq(_entries[1].position.y, _slot(0), "The two it passed close up")
	assert_eq(_entries[2].position.y, _slot(1), "and leave the last place open.")
	_list.drag_to(Vector2(50, _slot(1) + 20.0))
	_list.place(1.0)
	assert_eq(_entries[1].position.y, _slot(0))
	assert_eq(_entries[2].position.y, _slot(2), "The gap is in the middle now.")
	assert_eq(_list.order(), [0, 1, 2] as Array[int], "Nothing has changed until it is let go.")


func test_the_others_ease_to_their_places_a_part_of_the_way_each_frame() -> void:
	_open(3)
	_list.press(0, Vector2(50, 20))
	_list.drag_to(Vector2(50, _slot(2) + 20.0))

	assert_eq(_entries[1].position.y, _slot(1), "Picking it up moves nothing else at once.")
	_list.place(0.5)
	assert_almost_eq(_entries[1].position.y, _slot(1) / 2.0, 0.01)
	_list.place(0.5)
	assert_almost_eq(_entries[1].position.y, _slot(1) / 4.0, 0.01)


func test_letting_go_puts_it_down_and_says_where_it_went_in_one_move() -> void:
	_open(4)
	_list.press(0, Vector2(50, 20))
	_list.drag_to(Vector2(50, _slot(2) + 20.0))

	_list.release()

	assert_eq(_moves, [[0, 2]], "One move, two places.")
	assert_eq(_list.order(), [1, 2, 0, 3] as Array[int])
	assert_false(_list.is_pressed())
	_list.place(1.0)
	assert_eq(_entries[0].position.y, _slot(2))
	assert_eq(_entries[0].z_index, 0)
	assert_eq(_entries[0].modulate, Color.WHITE)
	assert_eq(_entries[3].position.y, _slot(3))


func test_an_entry_can_be_dragged_up_and_is_known_by_its_number_not_its_place() -> void:
	_open(3, [2, 0, 1])

	_list.press(1, Vector2(50, _slot(2) + 20.0))
	_list.drag_to(Vector2(50, 20))
	_list.release()

	assert_eq(_moves, [[2, 0]])
	assert_eq(_list.order(), [1, 2, 0] as Array[int])


func test_let_go_where_it_was_or_never_picked_up_it_is_no_move() -> void:
	_open(3)

	_list.press(1, Vector2(50, _slot(1) + 20.0))
	_list.release()
	assert_false(_list.is_pressed())
	_list.press(1, Vector2(50, _slot(1) + 20.0))
	_list.drag_to(Vector2(50, _slot(1) + 40.0))
	assert_true(_list.is_holding())
	_list.release()

	assert_eq(_moves, [])
	assert_eq(_list.order(), [0, 1, 2] as Array[int])
	_list.place(1.0)
	assert_eq(_entries[1].position.y, _slot(1), "It goes back to its place.")


func test_canceling_puts_it_back_without_a_move() -> void:
	_open(3)
	_list.press(0, Vector2(50, 20))
	_list.drag_to(Vector2(50, _slot(2) + 20.0))

	_list.cancel()

	assert_false(_list.is_pressed())
	assert_eq(_moves, [])
	assert_eq(_list.order(), [0, 1, 2] as Array[int])
	_list.place(1.0)
	assert_eq(_entries[0].position.y, 0.0)
	assert_eq(_entries[0].modulate, Color.WHITE)
	_list.drag_to(Vector2(50, _slot(2)))
	assert_false(_list.is_holding(), "And the mouse is no longer followed.")


func test_a_new_order_is_shown_by_easing_the_same_entries() -> void:
	_open(3)

	_list.set_order([2, 1, 0] as Array[int])

	assert_eq(_entries[2].position.y, _slot(2), "Nothing jumps.")
	_list.place(0.5)
	assert_almost_eq(_entries[2].position.y, _slot(1), 0.01, "Halfway to the top.")
	_list.place(1.0)
	assert_eq(_entries[2].position.y, 0.0)
	assert_eq(_list.get_child_count(), 3, "The same three entries.")


func test_a_left_press_on_an_entry_presses_it_where_the_cursor_is_in_the_list() -> void:
	_open(3)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(50, 20)

	_entries[1].gui_input.emit(press)
	_list.drag_to(Vector2(50, _slot(1) + 30.0))

	assert_eq(_list.held_number(), 1)
	assert_eq(_entries[1].position.y, _slot(1) + 10.0, "Grabbed twenty pixels below its own top.")
	_list.cancel()
	press.button_index = MOUSE_BUTTON_RIGHT
	_entries[1].gui_input.emit(press)
	assert_false(_list.is_pressed(), "Only the left button picks one up.")
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = false
	_entries[1].gui_input.emit(press)
	assert_false(_list.is_pressed(), "And only going down.")


func test_the_list_eases_by_itself_each_frame() -> void:
	_open(3)
	_list.set_order([1, 0, 2] as Array[int])

	await wait_seconds(0.4)

	assert_almost_eq(_entries[1].position.y, 0.0, 0.5)
	assert_almost_eq(_entries[0].position.y, _slot(1), 0.5)


func _open(count: int, order: Array = []) -> void:
	_entries = []
	_moves = []
	var numbers: Array[int] = []
	for number: int in count:
		_entries.append(StackEntry.new("", "Trigger %d" % number, "Hero", StackColors.PLAIN, true))
		numbers.append(number)
	if not order.is_empty():
		numbers.assign(order)
	_list = TriggerList.new(_entries, numbers)
	_list.moved.connect(func(from: int, to: int) -> void: _moves.append([from, to]))
	_list.set_process(false)
	add_child_autofree(_list)
	_list.size = Vector2(WIDTH, 400)
	_height = _list.entry_height()
	_list.place(1.0)


func _slot(place: int) -> float:
	return EncounterLayout.trigger_slot(place, _height)
