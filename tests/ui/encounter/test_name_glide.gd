extends GutTest
## A Player Name too long for its Player Panel glides from one end to the other and back:
## it rests at its start, glides at a steady pace until its end meets the box's, rests
## there, glides back, and so on, a whole pixel at a time.

const OVERFLOW: float = 60.0


func test_a_name_that_fits_never_moves() -> void:
	var glide: NameGlide = NameGlide.new(0.0)

	assert_false(glide.is_gliding())
	glide.advance(10.0)
	assert_eq(glide.offset(), 0)


func test_it_rests_at_its_start_first() -> void:
	var glide: NameGlide = NameGlide.new(OVERFLOW)

	assert_true(glide.is_gliding())
	assert_eq(glide.offset(), 0)
	glide.advance(NameGlide.REST_SECONDS - 0.01)
	assert_eq(glide.offset(), 0, "Still resting.")


func test_it_glides_at_a_steady_pace_until_its_end_meets_the_boxes() -> void:
	var glide: NameGlide = NameGlide.new(OVERFLOW)
	glide.advance(NameGlide.REST_SECONDS + 1.0)

	assert_eq(glide.offset(), -int(NameGlide.PIXELS_PER_SECOND), "One second's glide in.")
	glide.advance(OVERFLOW / NameGlide.PIXELS_PER_SECOND - 1.0)
	assert_eq(glide.offset(), -int(OVERFLOW), "Its end meets the box's.")
	glide.advance(NameGlide.REST_SECONDS - 0.01)
	assert_eq(glide.offset(), -int(OVERFLOW), "And rests there.")


func test_it_glides_back_and_starts_over() -> void:
	var glide: NameGlide = NameGlide.new(OVERFLOW)
	var glide_seconds: float = OVERFLOW / NameGlide.PIXELS_PER_SECOND
	glide.advance(NameGlide.REST_SECONDS * 2.0 + glide_seconds + glide_seconds / 2.0)

	assert_eq(glide.offset(), -int(OVERFLOW / 2.0), "Halfway back.")
	glide.advance(glide_seconds / 2.0 + 0.01)
	assert_eq(glide.offset(), 0, "Back at its start, resting again.")
	glide.advance(NameGlide.REST_SECONDS + 1.0)
	assert_eq(glide.offset(), -int(NameGlide.PIXELS_PER_SECOND), "And round again.")


func test_it_moves_a_whole_pixel_at_a_time() -> void:
	var glide: NameGlide = NameGlide.new(OVERFLOW)
	glide.advance(NameGlide.REST_SECONDS)
	for step: int in 300:
		glide.advance(0.01)
		assert_eq(typeof(glide.offset()), TYPE_INT)
		assert_between(glide.offset(), -int(OVERFLOW), 0)


func test_a_fraction_of_a_pixel_over_still_glides_to_the_end() -> void:
	var glide: NameGlide = NameGlide.new(10.4)
	glide.advance(NameGlide.REST_SECONDS + 11.0 / NameGlide.PIXELS_PER_SECOND)

	assert_eq(glide.offset(), -11, "Its last letter shows in full.")
