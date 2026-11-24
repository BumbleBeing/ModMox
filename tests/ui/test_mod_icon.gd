extends GutTest
## The Mod Icon on a Mod's entry (game glossary): the cog in its Rarity's color, drawn pixel
## for pixel. One that can be used turns, a quarter turn clockwise every loop as the Logo's
## cogs do; one that cannot is darkened and still.


func test_each_raritys_turning_sheet_is_its_frames_one_under_another() -> void:
	for rarity: Mod.Rarity in Mod.Rarity.values():
		var sheet: Texture2D = load(ModIcon.TURNING % ModIcon.file_name(rarity)) as Texture2D
		assert_not_null(sheet, Mod.Rarity.find_key(rarity))
		assert_eq(sheet.get_size(), Vector2(ModIcon.SIZE, ModIcon.SIZE * ModIcon.FRAMES), Mod.Rarity.find_key(rarity))


func test_it_turns_at_the_logos_pace() -> void:
	assert_eq(ModIcon.FRAMES, MenuLogo.FRAMES)
	assert_eq(ModIcon.FRAMES_PER_SECOND, MenuLogo.FRAMES_PER_SECOND)


func test_a_turning_icon_shows_its_raritys_frames_in_turn_and_loops_without_a_seam() -> void:
	var icon: ModIcon = autofree(ModIcon.turning(Mod.Rarity.RARE))

	assert_true(icon.is_turning())
	assert_eq(icon.rarity(), Mod.Rarity.RARE)
	assert_eq(icon.modulate, Color.WHITE)
	var shown: AtlasTexture = icon.texture as AtlasTexture
	assert_eq(shown.atlas.resource_path, ModIcon.TURNING % "rare")
	assert_eq(shown.region, Rect2(0, 0, ModIcon.SIZE, ModIcon.SIZE))

	icon.advance(1.0 / ModIcon.FRAMES_PER_SECOND)
	assert_eq(icon.frame(), 1)
	assert_eq((icon.texture as AtlasTexture).region, Rect2(0, ModIcon.SIZE, ModIcon.SIZE, ModIcon.SIZE))

	icon.advance(ModIcon.LOOP_SECONDS - 1.0 / ModIcon.FRAMES_PER_SECOND)
	assert_eq(icon.frame(), 0)


func test_a_darkened_icon_is_its_raritys_picture_darkened_and_never_moves() -> void:
	var icon: ModIcon = autofree(ModIcon.darkened(Mod.Rarity.COMMON))

	assert_false(icon.is_turning())
	assert_eq(icon.rarity(), Mod.Rarity.COMMON)
	assert_eq(icon.texture.resource_path, ModIcon.STILL % "common")
	assert_eq(icon.modulate, ModIcon.DARKENED)
	assert_lt(ModIcon.DARKENED.v, 0.7, "Darkened, not merely dimmed.")
	assert_eq(ModIcon.DARKENED.a, 1.0, "Not see-through.")

	icon.advance(1.0)
	assert_eq(icon.texture.resource_path, ModIcon.STILL % "common")


func test_it_is_drawn_pixel_for_pixel_at_its_own_size_and_takes_no_clicks() -> void:
	for icon: ModIcon in [autofree(ModIcon.turning(Mod.Rarity.MYTHIC)), autofree(ModIcon.darkened(Mod.Rarity.UNIQUE))]:
		assert_eq(icon.custom_minimum_size, Vector2(ModIcon.SIZE, ModIcon.SIZE))
		assert_eq(icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
