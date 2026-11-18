extends GutTest
## Where a breathing Portrait is drawn in its square: grown from its center a whole screen
## pixel at a time, as the user chose in the breath lab.

const BOX: Vector2 = Vector2(192, 192)
const ART: Vector2 = Vector2(32, 32)


func test_at_rest_it_fills_the_square() -> void:
	assert_eq(BreathDrawing.rect(BOX, ART, 0.0), Rect2(Vector2.ZERO, BOX))


func test_one_art_pixel_of_growth_is_one_art_pixel_taller_and_wider_round_the_center() -> void:
	var grown: Rect2 = BreathDrawing.rect(BOX, ART, 1.0)

	assert_eq(grown.size, Vector2(198, 198))
	assert_eq(grown.get_center(), BOX / 2.0)


func test_it_grows_by_whole_screen_pixels_placed_on_whole_screen_pixels() -> void:
	var grown: Rect2 = BreathDrawing.rect(BOX, ART, 0.25)

	assert_eq(grown.size, Vector2(194, 194), "1.5 screen pixels rounds to 2.")
	assert_eq(grown.position, Vector2(-1, -1))
	var odd: Rect2 = BreathDrawing.rect(BOX, ART, 0.5)
	assert_eq(odd.size, Vector2(195, 195))
	assert_eq(odd.position, odd.position.floor())
