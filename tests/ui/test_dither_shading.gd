extends GutTest
## Dither Shading (the conventions' recurring look for a raised surface).

const TOP: Color = Color("#806040")
const BOTTOM: Color = Color("#201008")
const EDGE: Color = Color("#000000")


func _image(height: int, lip: int = 0) -> Image:
	return DitherShading.plate(TOP, BOTTOM, EDGE, 6, 1, lip, height).texture.get_image()


func test_a_plate_is_painted_for_the_height_it_is_given() -> void:
	assert_eq(_image(72).get_height(), 72)
	assert_eq(_image(42).get_height(), 42)


func test_it_runs_from_the_top_tone_down_to_the_bottom_tone() -> void:
	var image: Image = _image(72)
	var middle: int = image.get_width() / 2
	assert_eq(image.get_pixel(middle, 2), TOP)
	assert_eq(image.get_pixel(middle, 69), BOTTOM)


func test_its_tones_are_only_the_bands() -> void:
	var image: Image = _image(72)
	var bands: Array[Color] = []
	for band: int in DitherShading.BANDS:
		bands.append(TOP.lerp(BOTTOM, float(band) / float(DitherShading.BANDS - 1)))
	for y: int in range(1, 71):
		var seen: Color = image.get_pixel(image.get_width() / 2, y)
		var is_band: bool = false
		for color: Color in bands:
			is_band = is_band or seen.is_equal_approx(color)
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


func test_the_middle_columns_tile_so_the_dither_stays_even() -> void:
	var made: StyleBoxTexture = DitherShading.plate(TOP, BOTTOM, EDGE, 6, 1, 0, 40)
	assert_eq(made.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT)
