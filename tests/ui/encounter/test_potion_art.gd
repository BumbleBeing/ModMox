extends GutTest
## A Potion Icon is always drawn on beige with a darker circle behind it, in the icon's own
## pixels (ADR 0033, A538): filling the icon's grid in the Inspector, and one art pixel
## wider all round and one lower in the small art.


func test_big_gulp_has_an_icon_of_its_own_on_the_sixteen_grid() -> void:
	assert_true(PotionArt.has_icon("big_gulp"))
	assert_eq(PotionArt.icon_of("big_gulp").get_size(), Vector2(16, 16))


func test_a_potion_without_an_icon_gets_the_plain_bottle() -> void:
	assert_false(PotionArt.has_icon("no_such_potion"))
	assert_eq(PotionArt.icon_of("no_such_potion"), PotionArt.icon_of(PotionArt.BOTTLE))
	assert_ne(PotionArt.icon_of("big_gulp"), PotionArt.icon_of(PotionArt.BOTTLE))


func test_the_large_art_has_a_margin_and_its_circle_fills_the_icons_grid() -> void:
	var art: PotionArt = autofree(PotionArt.new("big_gulp", 288, false))

	assert_eq(art.icon_rect(), Rect2(16, 16, 256, 256), "One art pixel of beige all round.")
	assert_eq(art.circle_rect(), art.icon_rect())
	assert_eq(art.icon_texture(), PotionArt.icon_of("big_gulp"))


func test_the_small_art_fills_the_square_with_a_circle_one_wider_and_one_lower() -> void:
	var art: PotionArt = autofree(PotionArt.new("big_gulp", 64, true))

	assert_eq(art.icon_rect(), Rect2(0, 0, 64, 64))
	assert_eq(art.circle_rect(), Rect2(-4, 0, 72, 72), "An art pixel is 4 px here.")
	assert_true(art.clip_contents, "The beige square cuts off what falls outside.")


func test_the_circle_is_drawn_in_art_pixels_and_is_round() -> void:
	var image: Image = PotionArt.circle_image(1)

	assert_eq(image.get_size(), Vector2i(18, 18))
	assert_eq(image.get_pixel(0, 0).a, 0.0, "The corners are clear.")
	assert_eq(image.get_pixel(9, 0), PotionArt.CIRCLE)
	assert_eq(image.get_pixel(9, 9), PotionArt.CIRCLE)
	for y: int in 18:
		for x: int in 18:
			assert_eq(image.get_pixel(x, y), image.get_pixel(17 - x, 17 - y))
