extends GutTest
## The Counter Chip: a shaded bead in the top left corner of a permanent's art, green and
## reading "+2" for +1/+1 counters, violet and reading "-2" for -1/-1 counters.

const ART: Rect2 = Rect2(10, 30, 120, 90)
const BOX: Rect2 = Rect2(100, 200, 80, 40)
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const MINUS := MmCounter.Kind.MINUS_ONE_MINUS_ONE


func test_it_sits_in_the_arts_top_left_corner_as_big_as_a_damage_chip() -> void:
	var chip: Rect2 = CounterChip.box_in(ART, BOX)

	assert_almost_eq(chip.size, DamageChip.box_over(BOX).size, Vector2(0.001, 0.001), "The Damage Chip's size.")
	assert_almost_eq(chip.position, ART.position + Vector2(CounterChip.INSET, CounterChip.INSET), Vector2(0.001, 0.001))
	assert_eq(CounterChip.INSET, 4.0, "One unit in from the art's edges.")


func test_making_one_places_it_and_keeps_the_mouse_off_it() -> void:
	var chip: CounterChip = CounterChip.make(ART, BOX, MINUS, 3)
	add_child_autofree(chip)

	assert_eq(chip.kind, MINUS)
	assert_eq(chip.amount, 3)
	assert_almost_eq(chip.position, CounterChip.box_in(ART, BOX).position, Vector2(0.001, 0.001))
	assert_almost_eq(chip.size, CounterChip.box_in(ART, BOX).size, Vector2(0.001, 0.001))
	assert_eq(chip.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_it_reads_the_number_of_counters_with_their_sign() -> void:
	assert_eq(CounterChip.label_of(PLUS, 1), "+1")
	assert_eq(CounterChip.label_of(PLUS, 12), "+12")
	assert_eq(CounterChip.label_of(MINUS, 3), "-3")


func test_plus_counters_are_green_and_minus_counters_violet_each_shaded_dark_to_light() -> void:
	for kind: MmCounter.Kind in [PLUS, MINUS]:
		assert_gt(CounterChip.light_of(kind).get_luminance(), CounterChip.dark_of(kind).get_luminance())
		assert_gt(CounterChip.dark_of(kind).get_luminance(), DamageChip.RIM.get_luminance())
	assert_gt(CounterChip.light_of(PLUS).g, CounterChip.light_of(PLUS).r, "Green.")
	assert_gt(CounterChip.light_of(PLUS).g, CounterChip.light_of(PLUS).b)
	assert_gt(CounterChip.light_of(MINUS).b, CounterChip.light_of(MINUS).g, "Violet.")
	assert_gt(CounterChip.light_of(MINUS).r, CounterChip.light_of(MINUS).g)
	assert_ne(CounterChip.light_of(PLUS), DamageChip.LIGHT, "Neither is the Damage Chip's red.")
	assert_ne(CounterChip.light_of(MINUS), DamageChip.LIGHT)


func test_a_longer_number_is_written_smaller_and_every_number_is_centered() -> void:
	for amount: int in [1, 9, 12]:
		var chip: CounterChip = CounterChip.make(ART, BOX, PLUS, amount)
		add_child_autofree(chip)
		var font: Font = CardFonts.title()
		var text: String = CounterChip.label_of(PLUS, amount)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, chip.font_size()).x
		var digit_height: float = font.get_ascent(chip.font_size()) * DamageChip.DIGIT_HEIGHT

		var baseline: Vector2 = chip.number_at()

		assert_almost_eq(baseline.x + width / 2.0, chip.size.x / 2.0, 0.001, "Left and right.")
		assert_almost_eq(baseline.y - digit_height / 2.0, chip.size.y / 2.0, 0.001, "Up and down.")
		assert_lt(width, chip.size.x - DamageChip.RIM_WIDTH * 2.0, "%s fits inside the rim." % text)
	var short: CounterChip = CounterChip.make(ART, BOX, PLUS, 9)
	var long: CounterChip = CounterChip.make(ART, BOX, PLUS, 12)
	add_child_autofree(short)
	add_child_autofree(long)
	assert_eq(short.font_size(), int(short.size.y * CounterChip.NUMBER_SIZE))
	assert_eq(long.font_size(), int(long.size.y * CounterChip.LONG_NUMBER_SIZE))
	assert_lt(long.font_size(), short.font_size())
