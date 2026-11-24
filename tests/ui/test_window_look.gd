extends GutTest
## The Steel Rim (the conventions, signed off by the user from prototypes/window_border): a
## window standing over a screen is edged in three bands three pixels wide, near-black, dark
## steel, near-black, its corners stepped as a Steel Frame's are, round the window's own
## Dither Shading.

const HEIGHT: int = 120


func _image(height: int = HEIGHT) -> Image:
	return WindowLook.plate(height).texture.get_image()


## Whether two colors match once stored in eight bits a channel.
func _near(seen: Color, wanted: Color) -> bool:
	return absf(seen.r - wanted.r) < 2.0 / 255.0 and absf(seen.g - wanted.g) < 2.0 / 255.0 \
			and absf(seen.b - wanted.b) < 2.0 / 255.0 and is_equal_approx(seen.a, wanted.a)


func test_a_plate_is_painted_for_the_height_it_is_given() -> void:
	assert_eq(_image(120).get_height(), 120)
	assert_eq(_image(301).get_height(), 301)


func test_each_side_is_near_black_then_dark_steel_then_near_black_three_pixels_each() -> void:
	var image: Image = _image()
	var width: int = image.get_width()
	var bands: Array[Color] = [WindowLook.EDGE, WindowLook.STEEL, WindowLook.EDGE]
	assert_eq(WindowLook.RIM, WindowLook.RIM_BAND * bands.size())
	for depth: int in WindowLook.RIM:
		@warning_ignore("integer_division")
		var wanted: Color = bands[depth / WindowLook.RIM_BAND]
		assert_true(_near(image.get_pixel(depth, HEIGHT / 2), wanted), "left, %d in" % depth)
		assert_true(_near(image.get_pixel(width - 1 - depth, HEIGHT / 2), wanted), "right, %d in" % depth)
		assert_true(_near(image.get_pixel(width / 2, depth), wanted), "top, %d in" % depth)
		assert_true(_near(image.get_pixel(width / 2, HEIGHT - 1 - depth), wanted), "bottom, %d in" % depth)


func test_its_corners_step_in_blocks_of_a_band_and_are_never_rounded() -> void:
	var image: Image = _image()
	var width: int = image.get_width()
	for step: int in WindowLook.CORNER_STEPS:
		var y: int = step * WindowLook.RIM_BAND
		var first: int = (WindowLook.CORNER_STEPS - step) * WindowLook.RIM_BAND
		for row: int in [y, HEIGHT - 1 - y]:
			assert_eq(image.get_pixel(first - 1, row).a, 0.0, "clear short of the step, row %d" % row)
			assert_true(_near(image.get_pixel(first, row), WindowLook.EDGE), "the rim from the step, row %d" % row)
			assert_eq(image.get_pixel(width - first, row).a, 0.0, "clear on the right too, row %d" % row)
			assert_true(_near(image.get_pixel(width - 1 - first, row), WindowLook.EDGE), "and the rim, row %d" % row)


func test_inside_the_rim_is_the_windows_dither_shading_on_a_grid_from_its_corner() -> void:
	var image: Image = _image()
	var top: Color = WindowLook.FILL.lightened(0.06)
	var bottom: Color = WindowLook.FILL.darkened(0.3)
	var wrong: Array[Vector2i] = []
	for y: int in range(WindowLook.CORNER, HEIGHT - WindowLook.CORNER):
		for x: int in range(WindowLook.RIM, image.get_width() - WindowLook.RIM):
			var wanted: Color = DitherShading.band_color(posmod(x - WindowLook.CORNER, DitherShading.BLOCK * 2), y,
					HEIGHT, top, bottom)
			if not _near(image.get_pixel(x, y), wanted):
				wrong.append(Vector2i(x, y))
	assert_eq(wrong, [] as Array[Vector2i])


func test_it_stretches_only_between_its_corners_and_keeps_room_inside_the_rim() -> void:
	var made: StyleBoxTexture = WindowLook.plate(HEIGHT)

	assert_eq(made.texture_margin_left, float(WindowLook.CORNER))
	assert_eq(made.texture_margin_right, float(WindowLook.CORNER))
	assert_eq(made.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(made.get_content_margin(side), float(WindowLook.MARGIN))
	assert_eq(WindowLook.MARGIN, WindowLook.RIM + 22, "as clear of the rim as the old edge's windows were of it")


func test_a_shaded_window_is_painted_again_for_each_height_it_takes() -> void:
	var window: PanelContainer = PanelContainer.new()
	add_child_autofree(window)

	WindowLook.shade(window)
	window.size = Vector2(300, 200)
	assert_eq(window.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(_shown(window).get_data(), _image(200).get_data())

	window.size = Vector2(300, 260)
	assert_eq(_shown(window).get_data(), _image(260).get_data())


func _shown(window: Control) -> Image:
	return (window.get_theme_stylebox("panel") as StyleBoxTexture).texture.get_image()
