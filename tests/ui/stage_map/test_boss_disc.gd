extends GutTest
## How a Boss is drawn (milestone 17): its Portrait fitted inside the clay, shadow and all,
## even at the top of its breath; the clay Dither Shaded with the ring's shadow across its
## top; the ring shaded smoothly.

const DEMON: String = "res://ui/sprites/portraits/purple_demon.png"


func test_the_portrait_and_its_shadow_stay_inside_the_clay_at_the_top_of_the_breath() -> void:
	var portrait: Texture2D = load(DEMON)
	var image: Image = portrait.get_image()
	var radius: int = 46
	var drop: float = BossDisc.shadow_drop(radius)
	var size: float = BossDisc.fit_scale(portrait, radius - drop) * (1.0 + BossDisc.BREATH_SCALE)
	var half: Vector2 = Vector2(image.get_size()) / 2.0

	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < 0.1:
				continue
			for corner: Vector2 in [Vector2(x, y), Vector2(x + 1, y + 1), Vector2(x + 1, y), Vector2(x, y + 1)]:
				var drawn: Vector2 = (corner - half) * size
				assert_lte(drawn.length(), radius + 0.001)
				assert_lte((drawn + Vector2(0, drop)).length(), radius + 0.001)


func test_the_boss_breathes_four_percent_each_way_once_every_three_seconds() -> void:
	assert_eq(BossDisc.breath(0.0), 1.0)
	assert_almost_eq(BossDisc.breath(0.75), 1.04, 0.0001)
	assert_almost_eq(BossDisc.breath(2.25), 0.96, 0.0001)
	assert_almost_eq(BossDisc.breath(3.0), 1.0, 0.0001)


## The whole disc, clay and ring, is one 32 x 32 pixel picture, scaled by a whole number
## to the disc's radius: four times on the Stage Map, eight in the Stage Intro.
func test_the_disc_is_a_32_pixel_picture_scaled_whole() -> void:
	var disc: Image = BossDisc.pixel_disc().get_image()

	assert_eq(disc.get_size(), Vector2i(32, 32))
	assert_eq(BossDisc.ring_scale(StageMapLayout.BOSS_RADIUS), 4)
	assert_eq(BossDisc.ring_scale(StageIntro.RING_RADIUS), 8)


## The ring is red edged dark, clear outside, shaded from light at the top to dark at the
## bottom, each row of pixels one color.
func test_the_ring_is_red_edged_dark_and_shaded_top_to_bottom() -> void:
	var disc: Image = BossDisc.pixel_disc().get_image()

	assert_eq(disc.get_pixel(0, 0).a, 0.0, "Clear outside.")
	assert_eq(disc.get_pixel(16, 2), BossDisc.EDGE, "Edged dark at the top...")
	assert_eq(disc.get_pixel(16, 29), BossDisc.EDGE, "...and the bottom.")
	assert_gt(disc.get_pixel(16, 3).v, disc.get_pixel(16, 28).v, "Lighter at the top.")
	assert_eq(disc.get_pixel(3, 16), disc.get_pixel(28, 16), "Each row one color: no dither.")
	assert_gt(disc.get_pixel(16, 3).r, disc.get_pixel(16, 3).g, "Red.")


## Inside, the clay is Dither Shaded a pixel at a time, and the ring casts a pixel of
## shadow down across its top.
func test_the_clay_is_dithered_by_the_pixel_under_the_rings_shadow() -> void:
	var disc: Image = BossDisc.pixel_disc().get_image()
	var colors: Dictionary[Color, bool] = {}
	for x: int in range(10, 22):
		colors[disc.get_pixel(x, 14)] = true

	assert_eq(disc.get_pixel(16, 16).a, 1.0, "Clay fills the middle.")
	assert_gt(colors.size(), 1, "Dithered: neighbors in a row differ.")
	assert_lt(disc.get_pixel(16, 5).v, disc.get_pixel(16, 8).v, "Shadowed under the ring's top.")
