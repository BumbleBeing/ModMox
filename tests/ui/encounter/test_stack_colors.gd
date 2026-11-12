extends GutTest
## Each object on the stack has a color of its own for as long as it is there (A335).


func test_an_object_takes_the_hue_at_its_id() -> void:
	var colors: StackColors = StackColors.new()

	colors.update([11] as Array[int])

	assert_eq(colors.color_of(11), StackColors.HUES[11 % StackColors.HUES.size()])


func test_two_objects_whose_ids_share_a_hue_get_different_ones() -> void:
	var colors: StackColors = StackColors.new()

	colors.update([3, 11] as Array[int])

	assert_eq(colors.color_of(3), StackColors.HUES[3])
	assert_eq(colors.color_of(11), StackColors.HUES[4], "The next free hue.")


func test_the_next_free_hue_wraps_round_to_the_first() -> void:
	var colors: StackColors = StackColors.new()

	colors.update([7, 15] as Array[int])

	assert_eq(colors.color_of(15), StackColors.HUES[0])


func test_an_object_keeps_its_hue_as_others_join_and_leave() -> void:
	var colors: StackColors = StackColors.new()
	colors.update([3, 11] as Array[int])

	colors.update([11] as Array[int])
	colors.update([11, 19, 4] as Array[int])

	assert_eq(colors.color_of(11), StackColors.HUES[4], "It never changes while it is on the stack.")
	assert_eq(colors.color_of(19), StackColors.HUES[3], "The hue the object that left had is free again.")
	assert_eq(colors.color_of(4), StackColors.HUES[5])


func test_with_every_hue_taken_a_hue_is_shared() -> void:
	var colors: StackColors = StackColors.new()
	var ids: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 9]

	colors.update(ids)

	assert_eq(colors.color_of(9), StackColors.HUES[1])


func test_something_not_on_the_stack_has_the_plain_color() -> void:
	var colors: StackColors = StackColors.new()
	colors.update([3] as Array[int])
	colors.update([] as Array[int])

	assert_eq(colors.color_of(3), StackColors.PLAIN)


func test_no_hue_is_one_of_the_glows_or_the_block_lines_colors() -> void:
	var taken: Array[Color] = [BlockLines.CHOSEN, BlockLines.DECLARED]
	for kind: DecisionClicks.Kind in DecisionClicks.COLORS:
		taken.append(DecisionClicks.color_of(kind))
	assert_eq(StackColors.HUES.size(), 8)
	for index: int in StackColors.HUES.size():
		for other: Color in taken:
			assert_gt(_distance(StackColors.HUES[index], other), 0.2, "Hue %d is too close to %s." % [index, other.to_html()])
		assert_false(StackColors.HUES[index].is_equal_approx(StackColors.PLAIN))
		for later: int in range(index + 1, StackColors.HUES.size()):
			assert_gt(_distance(StackColors.HUES[index], StackColors.HUES[later]), 0.08, "Hues %d and %d are too alike." % [index, later])


func _distance(one: Color, other: Color) -> float:
	return Vector3(one.r - other.r, one.g - other.g, one.b - other.b).length()
