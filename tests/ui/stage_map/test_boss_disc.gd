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


func test_the_ring_casts_its_shadow_across_the_top_of_the_clay() -> void:
	var clay: Image = BossDisc.dithered_clay(46).get_image()

	var near_top: Color = clay.get_pixel(46, 1)
	var below_shadow: Color = clay.get_pixel(46, 6)
	assert_lt(near_top.v, below_shadow.v)
	assert_eq(clay.get_pixel(0, 0).a, 0.0, "Round: the corners are empty.")


func test_the_ring_is_shaded_smoothly_from_light_at_the_top_to_dark_at_the_bottom() -> void:
	var ring: Image = BossDisc.shaded_ring(52).get_image()

	assert_gt(ring.get_pixel(52, 2).v, ring.get_pixel(52, 101).v)
	assert_eq(ring.get_pixel(40, 30), ring.get_pixel(60, 30), "Each row is one color: no dither.")
