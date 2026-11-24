extends GutTest
## The Menu Backdrop (game glossary, game ADR 0081): Last Light, its still with its flicker
## played over it, ten frames a second for ten seconds, over and over.


## (3) It shows the frame its clock is on: each flicker pixel in that frame's color, every
## other pixel as the still has it.
func test_it_shows_each_flicker_pixel_in_its_color_on_the_frame_its_clock_is_on() -> void:
	var backdrop: MenuBackdrop = _backdrop()

	backdrop.advance(2.35)

	assert_eq(backdrop.frame(), 23)
	var picture: Image = backdrop.picture()
	var pixels: Array[Vector2i] = backdrop.flicker_pixels()
	var flickering: Dictionary[Vector2i, bool] = {}
	var wrong: Array[Vector2i] = []
	for column: int in pixels.size():
		flickering[pixels[column]] = true
		if picture.get_pixelv(pixels[column]) != backdrop.flicker_color(column, 23):
			wrong.append(pixels[column])
	assert_eq(wrong, [] as Array[Vector2i], "each flicker pixel in frame 23's color")
	var still: Image = backdrop.still()
	var changed: int = 0
	for y: int in MenuBackdrop.SIZE.y:
		for x: int in MenuBackdrop.SIZE.x:
			if not flickering.has(Vector2i(x, y)) and picture.get_pixel(x, y) != still.get_pixel(x, y):
				changed += 1
	assert_eq(changed, 0, "every other pixel as the still has it")


## (3) Ten frames a second.
func test_it_steps_ten_frames_a_second() -> void:
	var backdrop: MenuBackdrop = _backdrop()

	backdrop.advance(0.09)
	assert_eq(backdrop.frame(), 0)
	backdrop.advance(0.02)
	assert_eq(backdrop.frame(), 1)
	backdrop.advance(0.9)
	assert_eq(backdrop.frame(), 10)


## (3) After ten seconds it is back on its first frame, which is the still.
func test_after_ten_seconds_it_is_back_on_its_first_frame() -> void:
	var backdrop: MenuBackdrop = _backdrop()

	backdrop.advance(9.95)
	assert_eq(backdrop.frame(), 99, "its last frame")
	backdrop.advance(0.1)

	assert_eq(backdrop.frame(), 0)
	assert_eq(backdrop.picture().get_data(), backdrop.still().get_data(), "showing the still")


## (4) The still and the flicker agree: a hundred frames, each flicker pixel once and inside
## the picture, and on the first frame in the still's color.
func test_its_still_and_its_flicker_agree() -> void:
	var backdrop: MenuBackdrop = _backdrop()
	var still: Image = backdrop.still()
	var pixels: Array[Vector2i] = backdrop.flicker_pixels()

	assert_eq(still.get_size(), Backdrops.SIZE, "a Backdrop's size")
	assert_eq(MenuBackdrop.SIZE, Backdrops.SIZE)
	assert_eq(backdrop.frames(), 100, "ten seconds at ten frames a second")
	assert_gt(pixels.size(), 0)
	var seen: Dictionary[Vector2i, bool] = {}
	for column: int in pixels.size():
		var pixel: Vector2i = pixels[column]
		assert_false(seen.has(pixel), "%s once" % pixel)
		seen[pixel] = true
		assert_true(Rect2i(Vector2i.ZERO, MenuBackdrop.SIZE).has_point(pixel), "%s inside the picture" % pixel)
		assert_eq(backdrop.flicker_color(column, 0), still.get_pixelv(pixel), "%s on the first frame" % pixel)


## (1) It is drawn six screen pixels to each of its own, with hard edges, and takes no clicks.
func test_it_is_drawn_with_hard_edges_and_takes_no_clicks() -> void:
	var backdrop: MenuBackdrop = _backdrop()

	assert_eq(Vector2i(backdrop.texture.get_size()), MenuBackdrop.SIZE)
	assert_eq(backdrop.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_SCALE)
	assert_eq(backdrop.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_IGNORE)


## The window's top lies on row 67, the merlons' tops: six screen pixels to each row at 1080p.
func test_the_parapet_is_row_67() -> void:
	assert_eq(MenuBackdrop.PARAPET, 67)
	assert_eq(MenuBackdrop.parapet_y(1080.0), 402.0)
	assert_eq(MenuBackdrop.parapet_y(720.0), 268.0)


func _backdrop() -> MenuBackdrop:
	var backdrop: MenuBackdrop = MenuBackdrop.new()
	add_child_autofree(backdrop)
	backdrop.set_process(false)
	return backdrop
