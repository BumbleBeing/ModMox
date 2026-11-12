extends GutTest
## The Drag Card: the card of the Hero's hand that is pressed, held, or waiting on the
## Option Menu (A371 to A383).

const AT: Vector2 = Vector2(800, 950)
const GRAB: Vector2 = Vector2(40, 60)

var _drag: DragCard


func before_each() -> void:
	_drag = DragCard.new()


func test_nothing_is_held_to_begin_with() -> void:
	assert_eq(_drag.card_id(), DragCard.NONE)
	assert_false(_drag.is_pressed())
	assert_false(_drag.is_holding())
	assert_false(_drag.is_waiting())
	assert_false(_drag.is_lifted())
	assert_false(_drag.has_gap())
	assert_eq(_drag.gap(), DragCard.NONE)
	assert_false(_drag.move(AT + Vector2(50, 0)), "Moving the mouse with nothing pressed picks nothing up.")
	assert_false(_drag.is_holding())


func test_a_press_is_not_yet_a_drag() -> void:
	_drag.press(7, AT, GRAB)

	assert_true(_drag.is_pressed())
	assert_eq(_drag.card_id(), 7)
	assert_false(_drag.is_lifted())
	assert_eq(_drag.cursor(), AT)


func test_a_press_becomes_a_drag_once_the_cursor_has_moved_three_pixels() -> void:
	_drag.press(7, AT, GRAB)

	assert_false(_drag.move(AT + Vector2(2.9, 0)))
	assert_false(_drag.is_holding())
	assert_true(_drag.is_pressed())
	assert_true(_drag.move(AT + Vector2(0, -3)), "The move that picks it up says so.")
	assert_true(_drag.is_holding())
	assert_true(_drag.is_lifted())
	assert_false(_drag.is_pressed())
	assert_false(_drag.move(AT + Vector2(0, -30)), "Later moves do not.")
	assert_eq(DragCard.START_DISTANCE, 3.0)


func test_the_distance_is_measured_from_where_the_button_went_down() -> void:
	_drag.press(7, AT, GRAB)

	_drag.move(AT + Vector2(2, 0))
	assert_false(_drag.move(AT + Vector2(0, 2)), "Two small moves that end near the start are not a drag.")
	assert_true(_drag.move(AT + Vector2(2.2, 2.2)))


func test_a_held_card_is_drawn_under_the_cursor_as_it_was_grabbed() -> void:
	_drag.press(7, AT, GRAB)
	_drag.move(AT + Vector2(100, -200))

	assert_eq(_drag.place(), AT + Vector2(100, -200) - GRAB)
	assert_eq(_drag.cursor(), AT + Vector2(100, -200))


func test_hovering_says_when_the_hand_must_make_room_again() -> void:
	_drag.press(7, AT, GRAB)
	_drag.move(AT + Vector2(10, 0))

	assert_true(_drag.hover(false, 2), "The first place it is over.")
	assert_true(_drag.has_gap())
	assert_eq(_drag.gap(), 2)
	assert_false(_drag.is_above())
	assert_false(_drag.hover(false, 2), "The same place again changes nothing.")
	assert_true(_drag.hover(false, 3))
	assert_true(_drag.hover(true, DragCard.NONE))
	assert_true(_drag.is_above())
	assert_false(_drag.has_gap(), "Above the strip the hand closes up.")
	assert_false(_drag.hover(true, DragCard.NONE))
	assert_true(_drag.hover(false, 3))
	assert_true(_drag.has_gap())


func test_a_card_let_go_to_wait_stays_where_it_is_and_leaves_no_gap() -> void:
	_drag.press(7, AT, GRAB)
	_drag.move(Vector2(900, 400))
	_drag.hover(true, DragCard.NONE)

	_drag.wait()

	assert_true(_drag.is_waiting())
	assert_true(_drag.is_lifted())
	assert_false(_drag.is_holding())
	assert_false(_drag.has_gap())
	assert_eq(_drag.card_id(), 7)
	assert_false(_drag.move(Vector2(100, 100)), "It no longer follows the cursor.")
	assert_eq(_drag.place(), Vector2(900, 400) - GRAB)


func test_only_a_held_card_can_wait() -> void:
	_drag.wait()
	assert_false(_drag.is_waiting())
	_drag.press(7, AT, GRAB)
	_drag.wait()
	assert_false(_drag.is_waiting())
	assert_true(_drag.is_pressed())
	_drag.move(AT + Vector2(10, 0))
	_drag.hover(false, 1)
	_drag.wait()
	assert_true(_drag.is_waiting())
	assert_false(_drag.has_gap(), "A waiting card leaves no gap, wherever it was let go.")


func test_dropping_lets_go_of_everything() -> void:
	_drag.press(7, AT, GRAB)
	_drag.move(AT + Vector2(10, 0))
	_drag.hover(false, 2)
	_drag.hover(true, DragCard.NONE)
	_drag.hover(false, 2)

	_drag.drop()

	assert_eq(_drag.card_id(), DragCard.NONE)
	assert_false(_drag.is_lifted())
	assert_false(_drag.is_pressed())
	assert_false(_drag.is_above())
	assert_eq(_drag.gap(), DragCard.NONE)
	_drag.press(7, AT, GRAB)
	_drag.move(AT + Vector2(10, 0))
	_drag.hover(false, 1)
	_drag.wait()
	_drag.drop()
	assert_false(_drag.is_waiting())
	assert_false(_drag.has_gap())


func test_a_new_press_starts_over() -> void:
	_drag.press(7, AT, GRAB)
	_drag.move(AT + Vector2(10, 0))
	_drag.hover(true, DragCard.NONE)

	_drag.press(8, AT + Vector2(50, 0), GRAB)

	assert_eq(_drag.card_id(), 8)
	assert_true(_drag.is_pressed())
	assert_false(_drag.is_holding(), "Whatever was held is let go of.")
	assert_false(_drag.is_above())
	assert_false(_drag.move(AT + Vector2(52, 0)), "Measured from the new press.")
