extends GutTest
## The Wisp's sprites: a stand-in in each of the Menu Soldier's flash colors, on his grid,
## and a flicker through every frame a color has, so that drawn frames drop in.


func test_there_is_a_stand_in_wisp_in_each_flash_color() -> void:
	for flash: String in SoldierAnimations.FLASH_COLORS:
		var frames: Array[Texture2D] = MenuWisp.textures_of(flash)

		assert_gt(frames.size(), 0, flash)
		for frame: Texture2D in frames:
			assert_eq(frame.get_size(), Vector2.ONE * MenuWisp.SPRITE_SIZE, flash)
	assert_eq(MenuWisp.SCALE, MenuSoldier.SCALE, "on the soldier's grid")


func test_each_is_drawn_in_its_flash_color() -> void:
	for flash: String in SoldierAnimations.FLASH_COLORS:
		var image: Image = MenuWisp.textures_of(flash)[0].get_image()
		var found: bool = false
		for y: int in image.get_height():
			for x: int in image.get_width():
				found = found or image.get_pixel(x, y).is_equal_approx(SoldierAnimations.FLASH_COLORS[flash])

		assert_true(found, "%s has its color" % flash)


func test_it_flickers_through_every_frame_a_color_has() -> void:
	assert_eq(MenuWisp.frame_at(0.0, 3), 0)
	assert_eq(MenuWisp.frame_at(MenuWisp.HOLD * 1.5, 3), 1)
	assert_eq(MenuWisp.frame_at(MenuWisp.HOLD * 3.5, 3), 0, "and round again")
	assert_eq(MenuWisp.frame_at(5.0, 1), 0, "one frame is always shown")
