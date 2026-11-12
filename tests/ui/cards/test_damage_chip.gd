extends GutTest
## The Damage Chip: a shaded red bead with the damage marked on a creature, resting on the
## top of its power and toughness box, over the toughness (A361).

const BOX: Rect2 = Rect2(100, 200, 80, 40)


func test_it_rests_on_the_top_of_the_box_over_its_right_half() -> void:
	var chip: Rect2 = DamageChip.box_over(BOX)

	assert_almost_eq(chip.size, Vector2(28.8, 28.8), Vector2(0.001, 0.001), "72% of the box's height, and round.")
	assert_almost_eq(chip.get_center().x, 160.0, 0.001, "Centered on the box's right half.")
	assert_almost_eq(chip.position.y, 200.0 - 28.8 * 0.78, 0.001)
	assert_gt(chip.end.y, BOX.position.y, "It overlaps the box's top edge.")
	assert_lt(chip.get_center().y, BOX.position.y, "But most of it is above the box.")


func test_making_one_places_it_and_keeps_the_mouse_off_it() -> void:
	var chip: DamageChip = DamageChip.make(BOX, 4)
	add_child_autofree(chip)

	assert_eq(chip.amount, 4)
	assert_almost_eq(chip.position, DamageChip.box_over(BOX).position, Vector2(0.001, 0.001))
	assert_almost_eq(chip.size, DamageChip.box_over(BOX).size, Vector2(0.001, 0.001))
	assert_eq(chip.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_bead_is_shaded_from_a_dark_rim_to_a_highlight_up_and_to_the_left() -> void:
	var middle: Vector2 = Vector2(50, 50)

	assert_eq(DamageChip.shade_color(0.0), DamageChip.DARK)
	assert_eq(DamageChip.shade_color(1.0), DamageChip.LIGHT)
	assert_gt(DamageChip.LIGHT.get_luminance(), DamageChip.DARK.get_luminance())
	assert_gt(DamageChip.DARK.get_luminance(), DamageChip.RIM.get_luminance())
	assert_eq(DamageChip.shade_center(middle, 20.0, 0.0), middle, "The widest circle fills the bead.")
	assert_eq(DamageChip.shade_radius(20.0, 0.0), 20.0 - DamageChip.RIM_WIDTH)
	assert_almost_eq(DamageChip.shade_center(middle, 20.0, 1.0), middle + DamageChip.HIGHLIGHT * 20.0, Vector2(0.001, 0.001))
	assert_lt(DamageChip.HIGHLIGHT.x, 0.0)
	assert_lt(DamageChip.HIGHLIGHT.y, 0.0)
	assert_almost_eq(DamageChip.shade_radius(20.0, 1.0), 20.0 * DamageChip.HIGHLIGHT_SIZE, 0.001)
	assert_almost_eq(DamageChip.shade_center(middle, 20.0, 0.5), middle + DamageChip.HIGHLIGHT * 10.0, Vector2(0.001, 0.001))
	assert_almost_eq(DamageChip.shade_radius(20.0, 0.5), (18.0 + 20.0 * DamageChip.HIGHLIGHT_SIZE) / 2.0, 0.001)


func test_every_shaded_circle_stays_inside_the_rim() -> void:
	var middle: Vector2 = Vector2(50, 50)

	for step: int in DamageChip.SHADES:
		var along: float = DamageChip.shade_along(step)
		var reach: float = middle.distance_to(DamageChip.shade_center(middle, 20.0, along)) + DamageChip.shade_radius(20.0, along)
		assert_lte(reach, 20.0 - DamageChip.RIM_WIDTH + 0.001, "Circle %d." % step)
	assert_eq(DamageChip.shade_along(0), 0.0)
	assert_eq(DamageChip.shade_along(DamageChip.SHADES - 1), 1.0)
	assert_gt(DamageChip.SHADES, 8, "Enough circles to read as a gradient.")


func test_the_number_is_centered_on_the_digits_themselves() -> void:
	for amount: int in [1, 4, 12]:
		var chip: DamageChip = DamageChip.make(BOX, amount)
		add_child_autofree(chip)
		var font: Font = CardFonts.title()
		var width: float = font.get_string_size(str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, chip.font_size()).x
		var digit_height: float = font.get_ascent(chip.font_size()) * DamageChip.DIGIT_HEIGHT

		var baseline: Vector2 = chip.number_at()

		assert_almost_eq(baseline.x + width / 2.0, chip.size.x / 2.0, 0.001, "Left and right.")
		assert_almost_eq(baseline.y - digit_height / 2.0, chip.size.y / 2.0, 0.001, "Up and down: digits have no descender.")
		assert_eq(chip.font_size(), int(chip.size.y * DamageChip.NUMBER_SIZE))
