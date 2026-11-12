extends GutTest
## Face Motion: where each permanent's face is drawn while it eases from where the last
## redraw left it to where this one put it (A356, A364).

const SECONDS: float = 0.25
const HERE: Vector2 = Vector2(100, 200)
const THERE: Vector2 = Vector2(300, 200)

var _motion: FaceMotion
var _look: CardLook


func before_each() -> void:
	_motion = FaceMotion.new()
	_motion.seconds = SECONDS
	_look = CardLook.new()


func test_a_face_whose_place_changes_eases_from_the_old_place_to_the_new() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({7: FacePose.of(THERE, 150.0, 0.0)})

	assert_eq(_motion.pose_of(7).center, HERE, "It starts where it was.")
	_wait(SECONDS / 2.0)
	assert_almost_eq(_motion.pose_of(7).center.x, 200.0, 0.01, "Half-way at half-time.")
	_wait(SECONDS / 2.0)
	assert_eq(_motion.pose_of(7).center, THERE)
	assert_eq(_motion.rest_of(7).center, THERE)


func test_a_move_starts_and_ends_slowly() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({7: FacePose.of(THERE, 150.0, 0.0)})

	_wait(SECONDS / 4.0)
	var early: float = _motion.pose_of(7).center.x - HERE.x
	_wait(SECONDS / 2.0)
	var late: float = THERE.x - _motion.pose_of(7).center.x

	assert_almost_eq(early, 200.0 * 0.15625, 0.01, "A quarter of the time covers under a sixth of the way.")
	assert_almost_eq(late, early, 0.01, "And it slows down the same way it sped up.")


func test_size_and_turn_ease_the_same_way() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({7: FacePose.of(HERE, 120.0, 1.0)})

	_wait(SECONDS / 2.0)

	assert_almost_eq(_motion.pose_of(7).height, 135.0, 0.01)
	assert_almost_eq(_motion.pose_of(7).turn, 0.5, 0.0001)
	_wait(SECONDS)
	assert_eq(_motion.pose_of(7).height, 120.0)
	assert_eq(_motion.pose_of(7).turn, 1.0)


func test_a_second_change_mid_move_starts_from_where_the_face_is() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({7: FacePose.of(THERE, 150.0, 0.0)})
	_wait(SECONDS / 2.0)

	_show({7: FacePose.of(Vector2(200, 400), 150.0, 0.0)})

	assert_almost_eq(_motion.pose_of(7).center, Vector2(200, 200), Vector2(0.01, 0.01))
	_wait(SECONDS / 2.0)
	assert_almost_eq(_motion.pose_of(7).center, Vector2(200, 300), Vector2(0.01, 0.01))
	_wait(SECONDS / 2.0)
	assert_eq(_motion.pose_of(7).center, Vector2(200, 400))


func test_showing_the_same_place_again_restarts_nothing() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({7: FacePose.of(THERE, 150.0, 0.0)})
	_wait(SECONDS / 2.0)

	_show({7: FacePose.of(THERE, 150.0, 0.0)})
	_wait(SECONDS / 2.0)

	assert_eq(_motion.pose_of(7).center, THERE, "The move ended when it would have.")


func test_a_new_face_fades_in_at_its_place() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)

	_show({7: FacePose.of(HERE, 150.0, 0.0), 8: FacePose.of(THERE, 150.0, 1.0)})

	assert_eq(_motion.pose_of(8).alpha, 0.0)
	assert_eq(_motion.pose_of(8).center, THERE)
	assert_eq(_motion.pose_of(8).turn, 1.0, "It arrives already turned.")
	assert_eq(_motion.pose_of(7).alpha, 1.0)
	_wait(SECONDS / 2.0)
	assert_almost_eq(_motion.pose_of(8).alpha, 0.5, 0.0001)
	_wait(SECONDS / 2.0)
	assert_eq(_motion.pose_of(8).alpha, 1.0)


func test_a_face_that_moves_while_fading_in_keeps_fading() -> void:
	_show({8: FacePose.of(HERE, 150.0, 0.0)})
	_wait(SECONDS / 2.0)

	_show({8: FacePose.of(THERE, 150.0, 0.0)})

	assert_almost_eq(_motion.pose_of(8).alpha, 0.5, 0.0001)
	_wait(SECONDS)
	assert_eq(_motion.pose_of(8).alpha, 1.0)


func test_a_face_that_leaves_is_a_ghost_that_fades_where_it_was() -> void:
	var look: CardLook = CardLook.new()
	_motion.show_faces({7: FacePose.of(HERE, 150.0, 1.0)}, {7: look}, true)

	_show({})

	assert_eq(_motion.ghost_ids(), [7] as Array[int])
	assert_eq(_motion.ghost_look(7), look)
	assert_eq(_motion.ghost_pose(7).center, HERE)
	assert_eq(_motion.ghost_pose(7).height, 150.0)
	assert_eq(_motion.ghost_pose(7).turn, 1.0)
	assert_eq(_motion.ghost_pose(7).alpha, 1.0)
	assert_null(_motion.pose_of(7), "It is no longer a face.")
	_wait(SECONDS / 2.0)
	assert_almost_eq(_motion.ghost_pose(7).alpha, 0.5, 0.0001)
	assert_eq(_motion.ghost_pose(7).center, HERE)
	_wait(SECONDS / 2.0)
	assert_eq(_motion.ghost_ids(), [] as Array[int], "The ghost is gone when the fade ends.")
	assert_null(_motion.ghost_pose(7))
	assert_null(_motion.ghost_look(7))


func test_a_face_that_leaves_mid_move_leaves_its_ghost_where_it_had_got_to() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)})
	_wait(SECONDS)
	_show({7: FacePose.of(THERE, 100.0, 0.0)})
	_wait(SECONDS / 2.0)

	_show({})

	assert_almost_eq(_motion.ghost_pose(7).center.x, 200.0, 0.01)
	assert_almost_eq(_motion.ghost_pose(7).height, 125.0, 0.01)


func test_a_ghost_of_a_face_that_was_still_fading_in_starts_as_faint_as_it_was() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)})
	_wait(SECONDS / 2.0)

	_show({})

	assert_almost_eq(_motion.ghost_pose(7).alpha, 0.5, 0.0001)
	_wait(SECONDS / 2.0)
	assert_almost_eq(_motion.ghost_pose(7).alpha, 0.25, 0.0001)


func test_a_face_that_comes_back_is_no_longer_a_ghost() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({})

	_show({7: FacePose.of(HERE, 150.0, 0.0)})

	assert_eq(_motion.ghost_ids(), [] as Array[int])
	assert_not_null(_motion.pose_of(7))


func test_a_forgotten_face_leaves_no_ghost() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0), 8: FacePose.of(THERE, 150.0, 0.0)}, true)

	_motion.forget(7)
	_show({})

	assert_eq(_motion.ghost_ids(), [8] as Array[int])


func test_ghosts_are_listed_in_id_order() -> void:
	_show({8: FacePose.of(HERE, 150.0, 0.0), 7: FacePose.of(THERE, 150.0, 0.0)}, true)

	_show({})

	assert_eq(_motion.ghost_ids(), [7, 8] as Array[int])


func test_a_face_is_drawn_from_its_latest_look() -> void:
	var newer: CardLook = CardLook.new()
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_motion.show_faces({7: FacePose.of(HERE, 150.0, 0.0)}, {7: newer}, false)

	_show({})

	assert_eq(_motion.ghost_look(7), newer, "Its ghost looks as it did when it left, not when it arrived.")


func test_a_forgotten_ghost_is_gone() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0), 8: FacePose.of(THERE, 150.0, 0.0)}, true)
	_show({})

	_motion.forget(7)

	assert_eq(_motion.ghost_ids(), [8] as Array[int])
	assert_null(_motion.ghost_look(7))


func test_snapping_puts_every_face_at_its_place_at_once_and_leaves_no_ghosts() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0), 8: FacePose.of(HERE, 150.0, 0.0), 6: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({6: FacePose.of(HERE, 150.0, 0.0), 7: FacePose.of(HERE, 150.0, 0.0)})
	assert_eq(_motion.ghost_ids(), [8] as Array[int])

	_show({7: FacePose.of(THERE, 100.0, 1.0), 9: FacePose.of(HERE, 150.0, 0.0)}, true)

	assert_eq(_motion.pose_of(7).center, THERE)
	assert_eq(_motion.pose_of(7).height, 100.0)
	assert_eq(_motion.pose_of(7).turn, 1.0)
	assert_eq(_motion.pose_of(9).alpha, 1.0, "A new face is simply there.")
	assert_eq(_motion.ghost_ids(), [] as Array[int], "Neither the old ghost nor the face that just left.")
	assert_false(_motion.is_moving())


func test_with_no_time_to_move_in_everything_snaps() -> void:
	_motion.seconds = 0.0
	_show({7: FacePose.of(HERE, 150.0, 0.0), 8: FacePose.of(HERE, 150.0, 0.0)})
	assert_eq(_motion.pose_of(7).alpha, 1.0)

	_show({7: FacePose.of(THERE, 150.0, 1.0)})

	assert_eq(_motion.pose_of(7).center, THERE)
	assert_eq(_motion.pose_of(7).turn, 1.0)
	assert_eq(_motion.ghost_ids(), [] as Array[int])
	assert_false(_motion.is_moving())


func test_it_is_moving_until_every_face_and_ghost_is_done() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0), 8: FacePose.of(HERE, 150.0, 0.0)}, true)
	assert_false(_motion.is_moving())

	_show({7: FacePose.of(THERE, 150.0, 0.0), 8: FacePose.of(HERE, 150.0, 0.0)})
	assert_true(_motion.is_moving())
	_wait(SECONDS - 0.01)
	assert_true(_motion.is_moving())
	_wait(0.02)
	assert_false(_motion.is_moving())

	_show({7: FacePose.of(THERE, 150.0, 0.0)})
	assert_true(_motion.is_moving(), "A ghost is fading.")
	_wait(SECONDS)
	assert_false(_motion.is_moving())


func test_a_long_frame_counts_as_a_thirtieth_of_a_second() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({7: FacePose.of(THERE, 150.0, 0.0)})

	_motion.advance(0.2)

	var slow: float = _motion.pose_of(7).center.x
	_motion = FaceMotion.new()
	_motion.seconds = SECONDS
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({7: FacePose.of(THERE, 150.0, 0.0)})
	_motion.advance(FaceMotion.LONGEST_FRAME)
	assert_eq(slow, _motion.pose_of(7).center.x, "The frame that redrew the board does not eat the move.")
	assert_almost_eq(FaceMotion.LONGEST_FRAME, 1.0 / 30.0, 0.00001)
	assert_gt(slow, HERE.x)
	assert_lt(slow, HERE.x + 10.0)


func test_a_face_whose_line_was_scrolled_moves_from_where_the_scroll_left_it() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)

	_motion.rebase(7, HERE + Vector2(-60, 0))
	_show({7: FacePose.of(HERE + Vector2(-60, 0), 150.0, 0.0)})

	assert_false(_motion.is_moving(), "Scrolling is not a move.")
	assert_eq(_motion.pose_of(7).center, HERE + Vector2(-60, 0))


func test_a_scroll_mid_move_carries_the_move_with_it() -> void:
	_show({7: FacePose.of(HERE, 150.0, 0.0)}, true)
	_show({7: FacePose.of(THERE, 150.0, 0.0)})
	_wait(SECONDS / 2.0)

	_motion.rebase(7, THERE + Vector2(0, 50))

	assert_almost_eq(_motion.pose_of(7).center, Vector2(200, 250), Vector2(0.01, 0.01))
	assert_eq(_motion.rest_of(7).center, THERE + Vector2(0, 50))
	_motion.rebase(99, HERE)
	assert_null(_motion.pose_of(99), "Rebasing a face it never saw does nothing.")


func test_poses_blend_and_compare() -> void:
	var from: FacePose = FacePose.of(HERE, 100.0, 0.0, 0.0)
	var to: FacePose = FacePose.of(THERE, 200.0, 1.0, 1.0)

	var middle: FacePose = from.blend(to, 0.25)

	assert_eq(middle.center, Vector2(150, 200))
	assert_eq(middle.height, 125.0)
	assert_eq(middle.turn, 0.25)
	assert_eq(middle.alpha, 0.25)
	assert_true(to.is_at(FacePose.of(THERE + Vector2(0.2, 0), 200.0, 1.0, 0.3)), "How faint it is does not matter.")
	assert_false(to.is_at(FacePose.of(THERE + Vector2(1, 0), 200.0, 1.0)))
	assert_false(to.is_at(FacePose.of(THERE + Vector2(0, 1), 200.0, 1.0)))
	assert_false(to.is_at(FacePose.of(THERE, 201.0, 1.0)))
	assert_false(to.is_at(FacePose.of(THERE, 200.0, 0.0)))
	assert_eq(FacePose.of(HERE, 1.0, 0.0).alpha, 1.0)


func _show(poses: Dictionary, is_snapping: bool = false) -> void:
	var targets: Dictionary[int, FacePose] = {}
	var looks: Dictionary[int, CardLook] = {}
	for object_id: int in poses:
		targets[object_id] = poses[object_id]
		looks[object_id] = _look
	_motion.show_faces(targets, looks, is_snapping)


## Lets [param seconds] go by in short frames, and a hair more, so that adding fifty
## fractions up never falls just short of the end of a move.
func _wait(seconds: float) -> void:
	var frames: int = 50
	for frame: int in frames:
		_motion.advance(seconds / frames)
	_motion.advance(0.000001)
