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
				var pixel: Color = image.get_pixel(x, y)
				found = found or Color(pixel, 1.0).is_equal_approx(SoldierAnimations.FLASH_COLORS[flash])

		assert_true(found, "%s has its color" % flash)


## Its far edge lets six tenths of it show, the ring in from that eight tenths, and its middle
## all of it.
func test_its_far_edge_is_at_six_tenths_and_the_ring_in_at_eight_tenths() -> void:
	var alphas: Array[float] = [0.6, 0.8, 1.0]
	for flash: String in SoldierAnimations.FLASH_COLORS:
		for frame: Texture2D in MenuWisp.textures_of(flash):
			var image: Image = frame.get_image()
			var rings: Dictionary[Vector2i, int] = _rings(image)
			assert_gt(rings.size(), 0, flash)
			for pixel: Vector2i in rings:
				var ring: int = mini(rings[pixel], alphas.size() - 1)
				assert_almost_eq(image.get_pixelv(pixel).a, alphas[ring], 1.0 / 255,
						"%s at %s, ring %d from the edge" % [flash, pixel, rings[pixel]])


## Each pixel the sprite draws, with how many rings in from its edge it is: 0 where it meets
## nothing or the sprite's border, 1 where it meets ring 0, and so on.
func _rings(image: Image) -> Dictionary[Vector2i, int]:
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, image.get_size())
	var left: Array[Vector2i] = []
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				left.append(Vector2i(x, y))
	var rings: Dictionary[Vector2i, int] = {}
	var ring: int = 0
	while not left.is_empty():
		var this_ring: Array[Vector2i] = []
		for pixel: Vector2i in left:
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = pixel + step
				var outside: bool = not bounds.has_point(next) or image.get_pixelv(next).a == 0.0
				if outside or (rings.has(next) and rings[next] == ring - 1):
					this_ring.append(pixel)
					break
		for pixel: Vector2i in this_ring:
			rings[pixel] = ring
			left.erase(pixel)
		ring += 1
	return rings


func test_it_flickers_through_every_frame_a_color_has() -> void:
	assert_eq(MenuWisp.frame_at(0.0, 3), 0)
	assert_eq(MenuWisp.frame_at(MenuWisp.HOLD * 1.5, 3), 1)
	assert_eq(MenuWisp.frame_at(MenuWisp.HOLD * 3.5, 3), 0, "and round again")
	assert_eq(MenuWisp.frame_at(5.0, 1), 0, "one frame is always shown")
