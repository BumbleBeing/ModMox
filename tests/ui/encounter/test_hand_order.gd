extends GutTest
## The Hand Order: the order the Hero keeps their hand in, by Card Identity (A374, A379).

var _order: HandOrder


func before_each() -> void:
	_order = HandOrder.new()


func test_cards_first_stand_in_the_order_they_are_handed_in() -> void:
	_order.update([5, 3, 9] as Array[int], false)

	assert_eq(_order.cards(), [5, 3, 9] as Array[int])
	assert_eq(_order.place_of(3), 1)
	assert_eq(_order.place_of(4), -1)


func test_a_new_card_joins_at_the_right_end_wherever_the_engine_lists_it() -> void:
	_order.update([5, 3, 9] as Array[int], false)

	_order.update([4, 5, 3, 9] as Array[int], false)

	assert_eq(_order.cards(), [5, 3, 9, 4] as Array[int])


func test_a_new_card_joins_at_the_right_end_on_a_rewind_too() -> void:
	_order.update([5, 3] as Array[int], false)

	_order.update([4, 5, 3] as Array[int], true)

	assert_eq(_order.cards(), [5, 3, 4] as Array[int])


func test_a_card_is_placed_among_the_others_and_stays_there() -> void:
	_order.update([5, 3, 9] as Array[int], false)

	_order.place(9, 0)
	assert_eq(_order.cards(), [9, 5, 3] as Array[int])
	_order.place(9, 1)
	assert_eq(_order.cards(), [5, 9, 3] as Array[int])
	_order.place(5, 2)
	assert_eq(_order.cards(), [9, 3, 5] as Array[int], "Past the last of the others is the right end.")
	_order.place(5, 7)
	assert_eq(_order.cards(), [9, 3, 5] as Array[int])
	_order.place(5, -1)
	assert_eq(_order.cards(), [5, 9, 3] as Array[int], "Before the first is the left end.")

	_order.update([3, 5, 9] as Array[int], false)
	assert_eq(_order.cards(), [5, 9, 3] as Array[int], "A redraw of the same hand keeps the Hero's order.")


func test_a_lone_card_can_be_put_down_again() -> void:
	_order.update([5] as Array[int], false)

	_order.place(5, 0)

	assert_eq(_order.cards(), [5] as Array[int])


func test_a_card_that_is_not_in_hand_cannot_be_placed() -> void:
	_order.update([5, 3] as Array[int], false)

	_order.place(8, 0)

	assert_eq(_order.cards(), [5, 3] as Array[int])


func test_a_card_that_leaves_is_no_longer_listed() -> void:
	_order.update([5, 3, 9] as Array[int], false)

	_order.update([5, 9] as Array[int], false)

	assert_eq(_order.cards(), [5, 9] as Array[int])
	assert_eq(_order.place_of(3), -1)


func test_a_card_that_a_rewind_brings_back_takes_the_place_it_had() -> void:
	_order.update([5, 3, 9] as Array[int], false)
	_order.update([5, 9] as Array[int], false)

	_order.update([5, 9, 3] as Array[int], true)

	assert_eq(_order.cards(), [5, 3, 9] as Array[int])


func test_a_card_that_comes_back_any_other_way_joins_at_the_right_end() -> void:
	_order.update([5, 3, 9] as Array[int], false)
	_order.update([5, 9] as Array[int], false)

	_order.update([3, 5, 9] as Array[int], false)

	assert_eq(_order.cards(), [5, 9, 3] as Array[int])
	_order.update([5, 9] as Array[int], true)
	_order.update([5, 9, 3] as Array[int], true)
	assert_eq(_order.cards(), [5, 9, 3] as Array[int], "And that is the place a later rewind gives it back.")


func test_rearranging_while_a_card_is_away_leaves_its_place_beside_its_old_neighbor() -> void:
	_order.update([5, 3, 9] as Array[int], false)
	_order.update([5, 9] as Array[int], false)

	_order.place(9, 0)
	_order.update([5, 9, 3] as Array[int], true)

	assert_eq(_order.cards(), [9, 5, 3] as Array[int], "It was right of 5, and still is.")


func test_a_card_cannot_be_placed_while_it_is_away() -> void:
	_order.update([5, 3, 9] as Array[int], false)
	_order.update([5, 9] as Array[int], false)

	_order.place(3, 0)
	_order.update([5, 9, 3] as Array[int], true)

	assert_eq(_order.cards(), [5, 3, 9] as Array[int])
