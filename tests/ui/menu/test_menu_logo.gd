extends GutTest
## The Logo's node: it shows the first frame from the first moment, in whole pixels, plays
## its frames at eight a second, comes back to the first after three seconds, and lets time
## go by on its own.


func test_it_shows_the_first_frame_from_the_first_moment_in_whole_pixels() -> void:
	var logo: MenuLogo = _logo()

	assert_eq(logo.frame(), 0)
	assert_eq((logo.texture as AtlasTexture).region, Rect2(0, 0, MenuLogo.SHEET.get_width(), 32))
	assert_eq(logo.size, Vector2(MenuLogo.SHEET.get_width(), 32) * 2)
	assert_eq(logo.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(logo.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it takes no clicks")


func test_the_sheet_holds_every_frame_one_under_another_as_wide_as_the_word() -> void:
	assert_eq(MenuLogo.SHEET.get_height(), 32 * 24)
	assert_eq(MenuLogo.FRAMES, 24)
	assert_lt(MenuLogo.SHEET.get_width(), 32 * 6, "its six characters closer than their cells")


func test_it_plays_eight_frames_a_second_and_loops_every_three_seconds() -> void:
	assert_eq(MenuLogo.LOOP_SECONDS, 3.0)
	assert_eq(MenuLogo.frame_at(0.0), 0)
	assert_eq(MenuLogo.frame_at(0.124), 0)
	assert_eq(MenuLogo.frame_at(0.126), 1)
	assert_eq(MenuLogo.frame_at(2.99), 23)
	assert_eq(MenuLogo.frame_at(3.01), 0, "back to the first")
	assert_eq(MenuLogo.frame_at(7.6), 12)


func test_it_shows_whatever_frame_the_loop_is_on() -> void:
	var logo: MenuLogo = _logo()
	var shown: Dictionary[int, bool] = {}

	for step: int in 60:
		logo.advance(0.1)
		assert_eq((logo.texture as AtlasTexture).region.position, Vector2(0, logo.frame() * 32))
		shown[logo.frame()] = true

	assert_eq(shown.size(), 24, "every frame shows in six seconds")


func test_time_goes_by_for_it_on_its_own() -> void:
	var logo: MenuLogo = _logo()

	await wait_seconds(0.3)

	assert_gt(logo.frame(), 0)


func _logo() -> MenuLogo:
	var logo: MenuLogo = MenuLogo.new()
	add_child_autofree(logo)
	logo.size = logo.custom_minimum_size
	return logo
