extends GutTest
## A Potion Icon is a 32 × 32 pixel icon that stands on a raised plate in its Rarity's color
## (ADR 0033, as amended): large, in the Inspector, with a margin of one art pixel; small, on
## an entry, filling the plate.

const COMMON: MmCardDefinition.Rarity = MmCardDefinition.Rarity.COMMON
const UNCOMMON: MmCardDefinition.Rarity = MmCardDefinition.Rarity.UNCOMMON
const RARE: MmCardDefinition.Rarity = MmCardDefinition.Rarity.RARE
const MYTHIC: MmCardDefinition.Rarity = MmCardDefinition.Rarity.MYTHIC


func test_big_gulp_has_an_icon_of_its_own_on_the_thirty_two_grid() -> void:
	assert_true(PotionArt.has_icon("big_gulp"))
	assert_eq(PotionArt.icon_of("big_gulp").get_size(), Vector2(32, 32))


func test_a_potion_without_an_icon_gets_the_plain_bottle() -> void:
	assert_false(PotionArt.has_icon("no_such_potion"))
	assert_eq(PotionArt.icon_of("no_such_potion"), PotionArt.icon_of(PotionArt.BOTTLE))
	assert_ne(PotionArt.icon_of("big_gulp"), PotionArt.icon_of(PotionArt.BOTTLE))
	assert_eq(PotionArt.icon_of(PotionArt.BOTTLE).get_size(), Vector2(32, 32))


func test_the_glass_is_lined_with_a_see_through_silvery_gray() -> void:
	for key: String in ["big_gulp", PotionArt.BOTTLE]:
		var icon: Image = PotionArt.icon_of(key).get_image()
		# Just inside the neck's left wall, and just inside the body's, beside the liquid.
		for point: Vector2i in [Vector2i(13, 9), Vector2i(6, 21)]:
			var lining: Color = icon.get_pixelv(point)
			assert_between(lining.a, 0.3, 0.8, "%s at %s lets the plate show through." % [key, point])
			assert_almost_eq(lining.r, 195.0 / 255.0, 0.01, "%s at %s is the palette's silvery gray." % [key, point])
		assert_eq(icon.get_pixel(15, 15).a, 0.0, "The middle of the glass is still clear.")


func test_the_large_art_has_a_margin_of_one_art_pixel_on_its_plate() -> void:
	var art: PotionArt = autofree(PotionArt.new("big_gulp", 272, false, RARE))

	assert_eq(art.icon_rect(), Rect2(8, 8, 256, 256), "One art pixel of plate all round.")
	assert_eq(art.plate_rect(), Rect2(0, 0, 272, 272))
	assert_eq(art.icon_texture(), PotionArt.icon_of("big_gulp"))


func test_the_small_art_fills_its_plate() -> void:
	var art: PotionArt = autofree(PotionArt.new("big_gulp", 64, true, COMMON))

	assert_eq(art.icon_rect(), Rect2(0, 0, 64, 64))
	assert_eq(art.plate_rect(), Rect2(0, 0, 64, 64), "A row may be taller than the plate.")


func test_the_plate_is_its_rarity_s_color() -> void:
	var colors: Dictionary[MmCardDefinition.Rarity, Color] = {
		COMMON: Color("#8a8f98"), UNCOMMON: Color("#d5dbe3"), RARE: Color("#f2c744"), MYTHIC: Color("#a0522d"),
	}
	for rarity: MmCardDefinition.Rarity in colors:
		var art: PotionArt = autofree(PotionArt.new("big_gulp", 64, true, rarity))
		assert_eq(art.plate_color(), colors[rarity])


func test_every_rarity_has_a_plate() -> void:
	for rarity: MmCardDefinition.Rarity in MmCardDefinition.Rarity.values():
		assert_true(PotionArt.PLATES.has(rarity), "Rarity %d" % rarity)


func test_a_mythic_plate_is_sienna_though_the_inspector_glows_honey() -> void:
	for rarity: MmCardDefinition.Rarity in [COMMON, UNCOMMON, RARE]:
		assert_eq(PotionArt.PLATES[rarity], Inspector.glow_of(rarity), "The glow's own color.")
	assert_ne(PotionArt.PLATES[MYTHIC], Inspector.glow_of(MYTHIC), "A plate in honey would pass for Rare's gold.")


func test_a_potion_given_no_rarity_stands_on_the_common_plate() -> void:
	var art: PotionArt = autofree(PotionArt.new("big_gulp", 64, true, null))

	assert_eq(art.plate_color(), PotionArt.PLATES[COMMON])


func test_the_plate_is_shaded_from_a_lighter_top_to_a_darker_foot() -> void:
	var plate: Image = PotionArt.plate_style(PotionArt.PLATES[RARE], 64).texture.get_image()
	var middle: int = plate.get_width() / 2

	assert_eq(plate.get_height(), 64, "Painted for its own height, so its blocks are never stretched.")
	assert_gt(plate.get_pixel(middle, 4).get_luminance(), PotionArt.PLATES[RARE].get_luminance())
	assert_lt(plate.get_pixel(middle, 59).get_luminance(), PotionArt.PLATES[RARE].get_luminance())
	assert_eq(plate.get_pixel(middle, 0), PotionArt.EDGE, "Edged in near-black.")
