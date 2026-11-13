extends GutTest
## The cards of the opening-hand overlay are dealt from the library, go back to it, and
## ease to wherever a redraw puts them.

const LIBRARY: Vector2 = Vector2(1500, 500)
const FRAME: float = 0.01

var _motion: OpeningMotion


func before_each() -> void:
	_motion = OpeningMotion.new()
	_motion.seconds = 0.3
	_motion.gap_seconds = 0.06


func test_with_no_time_every_card_is_at_its_place_face_up() -> void:
	_motion.seconds = 0.0

	_motion.show_cards(_row([1, 2, 3]), _library(), true)

	for object_id: int in [1, 2, 3]:
		assert_true(_motion.pose_of(object_id).is_at(_place(object_id)))
		assert_eq(_motion.face_of(object_id), 1.0)
	assert_false(_motion.is_moving())


func test_a_new_hand_starts_at_the_library_face_down_and_ends_in_its_row_face_up() -> void:
	_motion.show_cards(_row([1, 2, 3]), _library(), true)

	for object_id: int in [1, 2, 3]:
		assert_true(_motion.pose_of(object_id).is_at(_library()), "Card %d starts at the library." % object_id)
		assert_eq(_motion.face_of(object_id), 0.0)
	_wait(0.3 + 0.06 * 2 + 0.02)

	for object_id: int in [1, 2, 3]:
		assert_true(_motion.pose_of(object_id).is_at(_place(object_id)))
		assert_eq(_motion.face_of(object_id), 1.0)
	assert_false(_motion.is_moving())


func test_each_card_of_a_new_hand_leaves_later_than_the_one_before() -> void:
	_motion.show_cards(_row([1, 2, 3]), _library(), true)

	_wait(0.05)
	assert_false(_motion.pose_of(1).is_at(_library()), "The first has left.")
	assert_true(_motion.pose_of(2).is_at(_library()), "The second has not.")
	_wait(0.06)
	assert_false(_motion.pose_of(2).is_at(_library()))
	assert_true(_motion.pose_of(3).is_at(_library()))
	assert_gt(_motion.face_of(1), _motion.face_of(2), "The one that left first is further turned over.")


func test_a_redraw_in_the_middle_of_a_deal_does_not_start_it_again() -> void:
	_motion.show_cards(_row([1, 2, 3]), _library(), true)
	_wait(0.15)
	var before: Vector2 = _motion.pose_of(1).center

	_motion.show_cards(_row([1, 2, 3]), _library(), false)

	assert_eq(_motion.pose_of(1).center, before)
	_wait(0.16)
	assert_true(_motion.pose_of(1).is_at(_place(1)), "It lands when it would have.")


func test_after_a_mulligan_the_old_cards_go_back_before_any_new_card_leaves() -> void:
	_motion.show_cards(_row([1, 2, 3]), _library(), true)
	_wait(1.0)

	_motion.show_cards(_row([4, 5, 6]), _library(), true)

	assert_eq(_motion.leaving_ids(), [1, 2, 3] as Array[int])
	assert_null(_motion.pose_of(1), "It is no longer in the row.")
	_wait(0.15)
	assert_false(_motion.leaving_pose(1).is_at(_place(1)), "The old cards are on their way,")
	assert_lt(_motion.leaving_face(1), 1.0, "turning face down,")
	assert_true(_motion.pose_of(4).is_at(_library()), "and no new card has left yet.")
	_wait(0.16)
	assert_eq(_motion.leaving_ids(), [] as Array[int], "They have gone.")
	_wait(0.05)
	assert_false(_motion.pose_of(4).is_at(_library()), "Now the new hand is dealt,")
	assert_true(_motion.pose_of(5).is_at(_library()), "a card at a time.")


func test_a_card_put_down_goes_to_the_library_and_the_rest_ease_together() -> void:
	_motion.show_cards(_row([1, 2, 3]), _library(), true)
	_wait(1.0)
	var closed: Dictionary[int, FacePose] = {1: _place(1), 3: _place(2)}

	_motion.show_cards(closed, _library(), false)

	assert_eq(_motion.leaving_ids(), [2] as Array[int])
	assert_true(_motion.pose_of(3).is_at(_place(3)), "The row has not jumped.")
	_wait(0.15)
	assert_between(_motion.pose_of(3).center.x, _place(2).center.x, _place(3).center.x)
	assert_between(_motion.leaving_pose(2).center.x, _place(2).center.x, LIBRARY.x)
	_wait(0.16)
	assert_true(_motion.pose_of(3).is_at(_place(2)))
	assert_eq(_motion.leaving_ids(), [] as Array[int])


func test_a_card_taken_back_on_its_way_turns_round_where_it_has_got_to() -> void:
	_motion.show_cards(_row([1, 2, 3]), _library(), true)
	_wait(1.0)
	_motion.show_cards({1: _place(1), 3: _place(2)} as Dictionary[int, FacePose], _library(), false)
	_wait(0.15)
	var reached: Vector2 = _motion.leaving_pose(2).center
	var turned: float = _motion.leaving_face(2)

	_motion.show_cards(_row([1, 2, 3]), _library(), false)

	assert_eq(_motion.leaving_ids(), [] as Array[int])
	assert_eq(_motion.pose_of(2).center, reached)
	assert_almost_eq(_motion.face_of(2), turned, 0.001)
	_wait(0.31)
	assert_true(_motion.pose_of(2).is_at(_place(2)))
	assert_eq(_motion.face_of(2), 1.0)
	assert_true(_motion.pose_of(3).is_at(_place(3)), "The row has opened for it again.")


func test_a_card_taken_back_after_it_has_gone_comes_from_the_library_at_once() -> void:
	_motion.show_cards(_row([1, 2, 3]), _library(), true)
	_wait(1.0)
	_motion.show_cards({1: _place(1), 3: _place(2)} as Dictionary[int, FacePose], _library(), false)
	_wait(1.0)

	_motion.show_cards(_row([1, 2, 3]), _library(), false)

	assert_true(_motion.pose_of(2).is_at(_library()))
	_wait(0.05)
	assert_false(_motion.pose_of(2).is_at(_library()), "With no wait: it is not a deal.")


func test_the_hand_moves_to_its_strip_from_wherever_each_card_is() -> void:
	_motion.show_cards(_row([1, 2]), _library(), true)
	_wait(1.0)
	var strip: Dictionary[int, FacePose] = {1: FacePose.of(Vector2(400, 1100), 250.0, -0.1), 2: FacePose.of(Vector2(500, 1100), 250.0, 0.1)}

	_motion.move_to(strip)

	assert_true(_motion.pose_of(1).is_at(_place(1)))
	assert_true(_motion.is_moving())
	_wait(0.31)
	assert_true(_motion.pose_of(1).is_at(strip[1]))
	assert_eq(_motion.pose_of(2).height, 250.0, "It shrinks to the size of a card in hand.")
	assert_eq(_motion.face_of(1), 1.0)


func test_a_flight_is_fastest_at_its_start_and_end_and_slowest_in_the_middle() -> void:
	assert_eq(OpeningMotion.ease_of(0.0), 0.0)
	assert_almost_eq(OpeningMotion.ease_of(1.0), 1.0, 0.0001)
	assert_almost_eq(OpeningMotion.ease_of(0.5), 0.5, 0.0001)
	var first: float = OpeningMotion.ease_of(0.1) - OpeningMotion.ease_of(0.0)
	var middle: float = OpeningMotion.ease_of(0.55) - OpeningMotion.ease_of(0.45)
	var last: float = OpeningMotion.ease_of(1.0) - OpeningMotion.ease_of(0.9)
	assert_gt(first, middle * 2.0, "Faster at the start,")
	assert_gt(last, middle * 2.0, "and at the end,")
	assert_almost_eq(first, last, 0.0001, "the same at both.")
	var whole_sine: float = acos(1.0 - 2.0 * 0.02) / PI
	assert_lt(OpeningMotion.ease_of(0.02), whole_sine * 0.75, "But flatter than the whole inverse sine, which jumps at its ends:")
	assert_lt(OpeningMotion.ease_of(0.001) / 0.001, 4.0, "the speed it leaves at has a limit.")
	var before: float = 0.0
	for step: int in range(1, 21):
		assert_gt(OpeningMotion.ease_of(step / 20.0), before, "It never goes back.")
		before = OpeningMotion.ease_of(step / 20.0)


func test_a_card_is_flying_from_the_deal_until_it_lands() -> void:
	_motion.show_cards(_row([1, 2]), _library(), true)

	assert_true(_motion.is_flying(2), "Waiting to be dealt counts.")
	_wait(0.31)
	assert_false(_motion.is_flying(1))
	assert_true(_motion.is_flying(2))
	_wait(0.07)
	assert_false(_motion.is_flying(2))
	assert_false(_motion.is_flying(9), "A card the row does not have.")


func test_a_shorter_trip_is_a_quicker_flight() -> void:
	_motion.full_distance = 1000.0
	_motion.show_cards(_row([1, 2]), _library(), false)
	_wait(1.0)
	var targets: Dictionary[int, FacePose] = {1: _far(_place(1), 1000.0), 2: _far(_place(2), 500.0)}

	_motion.show_cards(targets, _library(), false)

	_wait(0.16)
	assert_false(_motion.is_flying(2), "Half as far takes half as long,")
	assert_true(_motion.is_flying(1), "and the full distance takes the full time.")
	_wait(0.15)
	assert_false(_motion.is_flying(1))


func test_a_trip_longer_than_the_full_distance_takes_no_longer() -> void:
	_motion.full_distance = 1000.0
	_motion.show_cards(_row([1]), _library(), false)
	_wait(1.0)

	_motion.show_cards({1: _far(_place(1), 3000.0)}, _library(), false)

	_wait(0.31)
	assert_false(_motion.is_flying(1))


func test_the_shortest_trip_still_takes_a_share_of_the_time() -> void:
	_motion.full_distance = 1000.0
	_motion.show_cards(_row([1]), _library(), false)
	_wait(1.0)

	_motion.show_cards({1: _far(_place(1), 10.0)}, _library(), false)

	_wait(0.3 * OpeningMotion.SHORTEST_SHARE - 0.02)
	assert_true(_motion.is_flying(1), "It does not snap.")
	_wait(0.04)
	assert_false(_motion.is_flying(1))


func test_a_new_hand_waits_only_as_long_as_the_old_cards_take_to_go_back() -> void:
	_motion.full_distance = 2500.0
	_motion.show_cards(_row([1, 2, 3]), _library(), true)
	_wait(1.0)

	_motion.show_cards(_row([4, 5, 6]), _library(), true)

	var longest: float = 0.3 * _place(1).center.distance_to(LIBRARY) / 2500.0
	assert_gt(longest, 0.3 * OpeningMotion.SHORTEST_SHARE, "The test's own trips are above the shortest.")
	_wait(longest - 0.02)
	assert_true(_motion.pose_of(4).is_at(_library()), "No new card leaves while an old one is in the air,")
	assert_false(_motion.leaving_ids().is_empty())
	_wait(0.05)
	assert_false(_motion.pose_of(4).is_at(_library()), "and the first leaves as soon as the last has gone.")


func test_with_no_full_distance_every_flight_takes_the_whole_time() -> void:
	_motion.show_cards(_row([1]), _library(), false)
	_wait(1.0)

	_motion.show_cards({1: _far(_place(1), 10.0)}, _library(), false)

	_wait(0.25)
	assert_true(_motion.is_flying(1))


func test_with_no_library_to_come_from_nothing_moves() -> void:
	_motion.show_cards(_row([1, 2]), null, true)

	assert_true(_motion.pose_of(1).is_at(_place(1)))
	assert_false(_motion.is_moving())


func _wait(seconds: float) -> void:
	for frame: int in roundi(seconds / FRAME):
		_motion.advance(FRAME)


func _library() -> FacePose:
	return FacePose.of(LIBRARY, 150.0, 0.0)


func _place(slot: int) -> FacePose:
	return FacePose.of(Vector2(200.0 * slot, 700.0), 350.0, 0.06 * (slot - 2))


## [param pose] moved [param distance] to the right.
func _far(pose: FacePose, distance: float) -> FacePose:
	return FacePose.of(pose.center + Vector2(distance, 0.0), pose.height, pose.turn)


## Cards [param ids] in a row, the first in the first slot.
func _row(ids: Array) -> Dictionary[int, FacePose]:
	var row: Dictionary[int, FacePose] = {}
	for index: int in ids.size():
		row[ids[index] as int] = _place(index + 1)
	return row
