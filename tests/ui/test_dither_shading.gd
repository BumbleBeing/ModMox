extends GutTest
## Dither Shading (the conventions' recurring look for a raised surface).

const TOP: Color = Color("#806040")
const BOTTOM: Color = Color("#201008")
const EDGE: Color = Color("#000000")


## Whether two colors match once stored in eight bits a channel.
func _near(seen: Color, wanted: Color) -> bool:
	return absf(seen.r - wanted.r) < 2.0 / 255.0 and absf(seen.g - wanted.g) < 2.0 / 255.0 \
			and absf(seen.b - wanted.b) < 2.0 / 255.0 and is_equal_approx(seen.a, wanted.a)


func _image(height: int, lip: int = 0) -> Image:
	return DitherShading.plate(TOP, BOTTOM, EDGE, 6, 1, lip, height).texture.get_image()


func test_a_plate_is_painted_for_the_height_it_is_given() -> void:
	assert_eq(_image(72).get_height(), 72)
	assert_eq(_image(42).get_height(), 42)


func test_it_runs_from_the_top_tone_down_to_the_bottom_tone() -> void:
	var image: Image = _image(72)
	var middle: int = image.get_width() / 2
	assert_true(_near(image.get_pixel(middle, 2), TOP))
	assert_true(_near(image.get_pixel(middle, 69), BOTTOM))


func test_its_tones_are_only_the_bands() -> void:
	var image: Image = _image(72)
	var bands: Array[Color] = []
	for band: int in DitherShading.BANDS:
		bands.append(TOP.lerp(BOTTOM, float(band) / float(DitherShading.BANDS - 1)))
	for y: int in range(1, 71):
		var seen: Color = image.get_pixel(image.get_width() / 2, y)
		var is_band: bool = false
		for color: Color in bands:
			is_band = is_band or _near(seen, color)
		assert_true(is_band, "row %d" % y)


func test_each_block_is_one_tone() -> void:
	for y: int in range(0, 60, DitherShading.BLOCK):
		for x: int in range(0, 12, DitherShading.BLOCK):
			var tone: Color = DitherShading.band_color(x, y, 72, TOP, BOTTOM)
			for inside: int in DitherShading.BLOCK:
				assert_eq(DitherShading.band_color(x + inside, y + inside, 72, TOP, BOTTOM), tone)


func test_where_bands_meet_neighboring_blocks_differ() -> void:
	var differs: bool = false
	for y: int in range(0, 72, DitherShading.BLOCK):
		var left: Color = DitherShading.band_color(0, y, 72, TOP, BOTTOM)
		var right: Color = DitherShading.band_color(DitherShading.BLOCK, y, 72, TOP, BOTTOM)
		differs = differs or left != right
	assert_true(differs, "some row is dithered")


func test_the_corners_are_cut_and_the_lip_is_edge_colored() -> void:
	var image: Image = _image(40, 4)
	assert_eq(image.get_pixel(0, 0).a, 0.0)
	assert_eq(image.get_pixel(image.get_width() / 2, 38), EDGE)


func test_with_a_lip_the_face_rounds_its_bottom_corners_above_the_lip_too() -> void:
	var lip: int = 4
	var image: Image = _image(40, lip)
	var above_lip: int = 40 - lip - 1

	assert_eq(image.get_pixel(1, above_lip), EDGE, "The face's corner curves away, with the lip showing beneath.")
	assert_false(image.get_pixel(image.get_width() / 2, above_lip - 1) == EDGE, "Across the middle the face reaches its edge, above the lip.")
	assert_eq(image.get_pixel(0, 0).a, 0.0, "The top corner is cut as before.")
	assert_false(image.get_pixel(2, 6) == EDGE, "And the face fills the top corner's curve, with no lip there.")
	assert_eq(image.get_pixel(0, 39).a, 0.0, "So is the lip's own corner.")


func test_a_buttons_text_is_centered_on_its_face_not_on_its_lip() -> void:
	for is_pressed: bool in [false, true]:
		var made: StyleBoxTexture = DitherShading.button_plate(Color("#4b4e55"), is_pressed, 42)
		var lip: int = DitherShading.PRESSED_LIP if is_pressed else DitherShading.LIP
		var height: float = 36.0
		var text_middle: float = (made.content_margin_top + height - made.content_margin_bottom) / 2.0
		assert_eq(text_middle, (height - lip) / 2.0, "Pressed: %s" % is_pressed)


func test_a_clickable_buttons_lip_is_dark_enough_to_show_against_the_pane() -> void:
	var fill: Color = Color("#4b4e55")
	var image: Image = DitherShading.button_plate(fill, false, 42).texture.get_image()

	var lip: Color = image.get_pixel(image.get_width() / 2, 40)
	assert_lt(lip.v, fill.darkened(0.7).v, "Far darker than the face, so the button stands up off the pane.")


func test_a_disabled_button_has_no_lip_and_its_text_is_centered() -> void:
	var made: StyleBoxTexture = DitherShading.disabled_plate(Color("#303238"), 42)
	var image: Image = made.texture.get_image()

	var near_bottom: Color = image.get_pixel(image.get_width() / 2, 39)
	assert_false(near_bottom.is_equal_approx(image.get_pixel(image.get_width() / 2, 41)),
		"The face reaches down to its one-pixel edge: no lip under it.")
	assert_eq(made.content_margin_top, made.content_margin_bottom)


func test_the_middle_columns_tile_so_the_dither_stays_even() -> void:
	var made: StyleBoxTexture = DitherShading.plate(TOP, BOTTOM, EDGE, 6, 1, 0, 40)
	assert_eq(made.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT)
