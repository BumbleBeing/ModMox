extends GutTest
## A Glow round a button drawn with a painted plate hugs the plate's own shape, corners and
## lip and all, and lights nothing the button does not reach (game ADR 0066). Round anything
## else it is rounded as before.

const GRAY: Color = Color("#4b4e55")
const GOLD: Color = Color("#f1dc9a")
const SIZE: Vector2 = Vector2(98, 34)


func after_each() -> void:
	await wait_process_frames(2)


func test_a_shaded_buttons_glow_is_a_halo_round_its_plate_in_its_color() -> void:
	var button: Button = _shaded()

	BorderEffects.add_glow(button, SIZE, GOLD)

	assert_true(BorderEffects.is_glow_hugging(button))
	assert_eq(BorderEffects.glow_color(button), GOLD)
	var halo: Panel = button.get_node(BorderEffects.GLOW).get_child(0) as Panel
	assert_eq(halo.self_modulate, GOLD, "One white halo for a plate, colored where it is drawn.")
	assert_eq(halo.position, Vector2(-7, -7), "As far out as a Glow reaches")
	assert_eq(halo.size, SIZE + Vector2(14, 14), "on every side.")
	assert_eq(halo.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_halo_lights_only_what_is_outside_the_plate_and_within_its_reach() -> void:
	# A rounded plate, as other screens' buttons still have, and a steel-framed one.
	for plate: StyleBoxTexture in [DitherShading.button_plate(GRAY, false, 34, 12), SteelFrame.plate(GRAY, "normal", 44)]:
		var shape: Image = plate.texture.get_image()
		var halo: StyleBoxTexture = DitherShading.halo_round(plate, 3, 7, 0.35)
		var lit: Image = halo.texture.get_image()

		assert_eq(lit.get_size(), shape.get_size() + Vector2i(14, 14))
		assert_eq(halo.texture_margin_left, plate.texture_margin_left + 7.0, "Stretched as the plate is.")
		var middle: int = lit.get_width() / 2
		assert_eq(lit.get_pixel(middle, 6).a, 1.0, "Solid just above the plate,")
		assert_almost_eq(lit.get_pixel(middle, 1).a, 0.35, 0.01, "soft further out,")
		assert_eq(lit.get_pixel(middle, lit.get_height() / 2).a, 0.0, "nothing over the plate itself,")
		assert_eq(lit.get_pixel(middle, lit.get_height() - 7).a, 1.0, "and solid just under its lip.")
		assert_eq(lit.get_pixel(0, 0).a, 0.0, "The far corner of the halo is dark: it is rounded as the plate is.")
		var wrong: int = 0
		for y: int in lit.get_height():
			for x: int in lit.get_width():
				var at: Vector2i = Vector2i(x - 7, y - 7)
				var is_on_plate: bool = at.x >= 0 and at.y >= 0 and at.x < shape.get_width() and at.y < shape.get_height() \
					and shape.get_pixelv(at).a > 0.0
				if is_on_plate and lit.get_pixel(x, y).a > 0.0:
					wrong += 1
		assert_eq(wrong, 0, "No pixel of the plate is lit.")
		# The pixel diagonally outside a corner the plate does not have is nearer the halo's
		# own corner than a rectangle's glow would allow.
		assert_gt(lit.get_pixel(7, 7).a, 0.0, "The cut corner of the plate is lit, hugging it.")


func test_a_button_given_another_plate_gets_a_new_glow_and_one_unchanged_keeps_its_own() -> void:
	var button: Button = _shaded()
	BorderEffects.set_glow(button, SIZE, GOLD)
	var first: Node = button.get_node(BorderEffects.GLOW)

	BorderEffects.set_glow(button, SIZE, GOLD)

	assert_eq(button.get_node(BorderEffects.GLOW), first, "The same Glow: nothing changed.")

	button.size = SIZE + Vector2(0, 10)
	ButtonShading.apply(button, GRAY)
	BorderEffects.set_glow(button, SIZE, GOLD)

	assert_ne(button.get_node(BorderEffects.GLOW), first, "Given a taller plate, so its Glow is made for the new shape.")
	assert_true(BorderEffects.is_glow_hugging(button))


func test_anything_else_glows_rounded_as_before() -> void:
	var face: Panel = Panel.new()
	add_child_autofree(face)
	face.size = Vector2(120, 168)
	var plain: Button = Button.new()
	add_child_autofree(plain)
	plain.size = SIZE

	BorderEffects.add_glow(face, face.size, GOLD)
	BorderEffects.add_glow(plain, SIZE, GOLD)

	assert_false(BorderEffects.is_glow_hugging(face), "A card is not a button.")
	assert_eq(face.get_node(BorderEffects.GLOW).get_child_count(), 2, "Its soft ring and its solid one.")
	assert_null(BorderEffects.plate_of(plain), "A button with no painted plate has no shape to hug.")
	assert_false(BorderEffects.is_glow_hugging(plain))


func _shaded() -> Button:
	var button: Button = Button.new()
	button.text = "Main 1"
	add_child_autofree(button)
	button.size = SIZE
	ButtonShading.apply(button, GRAY)
	return button
