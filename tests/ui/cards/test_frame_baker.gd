extends GutTest
## Frames are baked once per FrameSpec key from the committed frame images, and the
## Battlefield Face's border is cut from the baked Frame.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_baking_the_same_frame_twice_gives_the_cached_texture() -> void:
	var spec: FrameSpec = _spec([MmMana.Type.RED])

	var first: Texture2D = FrameBaker.texture(spec)

	assert_same(FrameBaker.texture(_spec([MmMana.Type.RED])), first)
	assert_not_same(FrameBaker.texture(_spec([MmMana.Type.GREEN])), first, "A different key bakes a new Frame.")


func test_a_baked_frame_is_the_bake_size() -> void:
	var baked: Image = FrameBaker.image(_spec([MmMana.Type.RED]))

	assert_eq(baked.get_size(), CardGeometry.BAKE_SIZE)


func test_a_gold_frame_shows_the_left_color_on_the_left_and_the_right_color_on_the_right() -> void:
	var baked: Image = FrameBaker.image(_spec([MmMana.Type.WHITE, MmMana.Type.BLUE]))
	var white: Image = FrameBaker.source("frames/w", CardGeometry.BAKE_SIZE)
	var blue: Image = FrameBaker.source("frames/u", CardGeometry.BAKE_SIZE)
	var left: Vector2i = _at(Vector2(0.15, 0.78))
	var right: Vector2i = _at(Vector2(0.85, 0.78))

	assert_true(baked.get_pixelv(left).is_equal_approx(white.get_pixelv(left)), "The rules box's left is white.")
	assert_true(baked.get_pixelv(right).is_equal_approx(blue.get_pixelv(right)), "The rules box's right is blue.")


func test_the_art_window_stays_transparent_so_art_shows_through() -> void:
	var baked: Image = FrameBaker.image(_spec([MmMana.Type.WHITE, MmMana.Type.BLUE]))

	assert_eq(baked.get_pixelv(_at(CardGeometry.ART.get_center())).a, 0.0)


func test_a_crown_covers_the_top_edge_in_black() -> void:
	var spec: FrameSpec = _spec([MmMana.Type.RED])
	spec.is_legendary = true

	var baked: Image = FrameBaker.image(spec)

	assert_true(baked.get_pixelv(_at(Vector2(0.5, 0.01))).is_equal_approx(Color.BLACK))


func test_a_battlefield_border_keeps_the_frame_down_to_the_art_and_the_strip_under_the_rules_box() -> void:
	var spec: FrameSpec = _spec([MmMana.Type.GREEN])
	var frame: Image = FrameBaker.image(spec.without_power_toughness())
	var top_end: int = roundi(CardGeometry.FIELD_TOP_END * CardGeometry.BAKE_SIZE.y)
	var strip_start: int = roundi(CardGeometry.FIELD_BOTTOM_START * CardGeometry.BAKE_SIZE.y)
	var strip_end: int = roundi(CardGeometry.FIELD_BOTTOM_END * CardGeometry.BAKE_SIZE.y)

	var border: Image = FrameBaker.field_border(spec)

	assert_eq(border.get_size(), Vector2i(CardGeometry.BAKE_SIZE.x, top_end + strip_end - strip_start))
	var x: int = CardGeometry.BAKE_SIZE.x / 2
	assert_eq(border.get_pixel(x, 10), frame.get_pixel(x, 10), "The name box is the frame's.")
	assert_eq(border.get_pixel(x, top_end + 2), frame.get_pixel(x, strip_start + 2), "Then the strip under the rules box.")


func test_a_battlefield_border_never_has_a_pt_box() -> void:
	var creature: FrameSpec = _spec([MmMana.Type.GREEN])
	creature.is_creature = true

	assert_same(FrameBaker.field_border(creature), FrameBaker.field_border(_spec([MmMana.Type.GREEN])))


func _spec(colors: Array[MmMana.Type]) -> FrameSpec:
	var spell: MmCardDefinition = Scenario.instant("Spell", Scenario.mana_cost(0, colors), [], [])
	return FrameSpec.of(CardLook.of_characteristics(MmCharacteristics.printed(spell)))


func _at(fraction: Vector2) -> Vector2i:
	return Vector2i(fraction * Vector2(CardGeometry.BAKE_SIZE))
