extends GutTest
## The steel frame (game ADR 0066): how the Info Panel's buttons and the Pass Button are
## drawn. A ring of light steel three pixels thick with a dark line inside it, its corners
## stepped and never rounded, over the button's lip; white round a Selected Answer.

const GRAY: Color = Color("#4b4e55")
const HEIGHT: int = 44


func test_the_ring_is_steel_three_pixels_thick_with_a_dark_line_inside_it() -> void:
	var image: Image = _image("normal", false)
	var middle: int = image.get_width() / 2

	for y: int in SteelFrame.RING:
		assert_eq(image.get_pixel(middle, y), SteelFrame.STEEL, "Row %d of the ring." % y)
	assert_true(_is(image.get_pixel(middle, SteelFrame.RING), GRAY.darkened(0.65)), "Then the dark line")
	assert_false(_is(image.get_pixel(middle, SteelFrame.FRAME), GRAY.darkened(0.65)), "one pixel thick")
	assert_ne(image.get_pixel(middle, SteelFrame.FRAME), SteelFrame.STEEL, "and the face.")


func test_the_corners_step_in_whole_blocks_and_nothing_is_half_drawn() -> void:
	var image: Image = _image("normal", false)

	assert_eq(image.get_pixel(0, 0).a, 0.0, "The corner itself is cut away")
	assert_eq(image.get_pixel(SteelFrame.RING * 2 - 1, 0).a, 0.0)
	assert_eq(image.get_pixel(SteelFrame.RING * 2, 0), SteelFrame.STEEL, "two blocks in on the top row,")
	assert_eq(image.get_pixel(SteelFrame.RING, SteelFrame.RING), SteelFrame.STEEL, "one on the next,")
	assert_eq(image.get_pixel(0, SteelFrame.RING * 2), SteelFrame.STEEL, "none on the third.")
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha: float = image.get_pixel(x, y).a
			assert_true(alpha == 0.0 or alpha == 1.0, "No smoothed pixel at %d, %d." % [x, y])
			if alpha != 0.0 and alpha != 1.0:
				return


func test_a_selected_answers_ring_is_white() -> void:
	var image: Image = _image("normal", true)

	assert_eq(image.get_pixel(image.get_width() / 2, 0), Color.WHITE)
	assert_ne(SteelFrame.plate(GRAY, "normal", HEIGHT, true), SteelFrame.plate(GRAY, "normal", HEIGHT, false))


func test_it_stands_on_a_lip_and_lies_flat_when_it_cannot_be_pressed() -> void:
	var raised: Image = _image("normal", false)
	var flat: Image = _image("disabled", false)
	var middle: int = raised.get_width() / 2

	assert_true(_is(raised.get_pixel(middle, HEIGHT - 1), SteelFrame.STEEL.darkened(0.55)), "The lip, under the ring.")
	assert_eq(raised.get_pixel(middle, HEIGHT - DitherShading.LIP - 1), SteelFrame.STEEL, "The ring's bottom row above it.")
	assert_true(_is(flat.get_pixel(middle, HEIGHT - 1), SteelFrame.ring_color(false, true)), "No lip: the ring reaches the bottom")
	assert_ne(SteelFrame.ring_color(false, true), SteelFrame.STEEL, "and is faded toward the panel.")
	assert_eq(SteelFrame.plate(GRAY, "normal", HEIGHT).content_margin_bottom, float(DitherShading.LIP),
		"The text is centered on the face, above the lip.")
	assert_eq(SteelFrame.plate(GRAY, "disabled", HEIGHT).content_margin_bottom, 0.0)


func test_apply_frames_every_state_once_with_white_text() -> void:
	var one: Button = _button()
	var other: Button = _button()

	SteelFrame.apply(one, GRAY)
	SteelFrame.apply(other, GRAY)

	assert_eq(one.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	for state: String in ["normal", "pressed", "hover_pressed", "disabled"]:
		assert_eq(one.get_theme_stylebox(state), SteelFrame.plate(GRAY, state, HEIGHT), state)
	assert_eq(one.get_theme_stylebox("normal"), other.get_theme_stylebox("normal"), "Painted once and shared.")
	assert_eq(one.get_theme_color("font_color"), Color.WHITE)
	assert_eq(one.get_theme_color("font_disabled_color"), ButtonShading.DISABLED_TEXT)
	assert_eq(one.size, Vector2(160, HEIGHT), "A button keeps its size.")


## Whether a painted pixel is [param color], within a step of its 256.
func _is(pixel: Color, color: Color) -> bool:
	return absf(pixel.r - color.r) < 0.01 and absf(pixel.g - color.g) < 0.01 and absf(pixel.b - color.b) < 0.01


func test_the_cursor_lightens_its_face_with_an_ease_and_never_a_switch() -> void:
	var button: Button = _button()
	SteelFrame.apply(button, GRAY)
	var layer: Control = HoverEase.layer_of(button)

	assert_eq(HoverEase.TIME, 0.1)
	assert_eq(button.get_theme_stylebox("hover"), SteelFrame.plate(GRAY, "normal", HEIGHT), "No plate switches under the cursor.")
	assert_eq(layer.modulate.a, 0.0, "Unlit until the cursor comes.")
	assert_eq(layer.get_index(), 0, "Under anything drawn on the button later.")
	var lit: Image = SteelFrame.hover_plate(HEIGHT).texture.get_image()
	var middle: int = lit.get_width() / 2
	assert_almost_eq(lit.get_pixel(middle, HEIGHT / 2).a, InspectorParts.HOVER_LIGHTEN, 0.01, "White over the face, as far as a hover lightens,")
	assert_eq(lit.get_pixel(middle, 0).a, 0.0, "nothing over the ring")
	assert_eq(lit.get_pixel(middle, HEIGHT - 1).a, 0.0, "or the lip.")

	button.mouse_entered.emit()

	assert_eq(layer.modulate.a, 0.0, "Not lit at once: it is eased in.")
	await wait_seconds(0.15)
	assert_almost_eq(layer.modulate.a, 1.0, 0.01, "Lit within a tenth of a second.")
	button.mouse_exited.emit()
	await wait_seconds(0.16)
	assert_almost_eq(layer.modulate.a, 0.0, 0.01, "And settled as fast.")


func test_a_button_that_cannot_be_pressed_does_not_light_and_one_held_down_goes_dark() -> void:
	var button: Button = _button()
	SteelFrame.apply(button, GRAY)
	var layer: Control = HoverEase.layer_of(button)
	button.disabled = true

	button.mouse_entered.emit()
	await wait_seconds(0.15)

	assert_eq(layer.modulate.a, 0.0)
	button.disabled = false
	button.mouse_entered.emit()
	await wait_seconds(0.15)
	button.button_down.emit()
	assert_eq(layer.modulate.a, 0.0, "Held down, it sits on its lip unlit.")


func test_framing_a_button_again_leaves_it_one_hover_layer() -> void:
	var button: Button = _button()

	SteelFrame.apply(button, GRAY)
	SteelFrame.apply(button, GRAY, true)
	await wait_process_frames(2)

	var layers: int = 0
	for child: Node in button.get_children():
		if child.name.begins_with(HoverEase.LAYER):
			layers += 1
	assert_eq(layers, 1)


func _image(state: String, is_selected: bool) -> Image:
	return SteelFrame.plate(GRAY, state, HEIGHT, is_selected).texture.get_image()


func _button() -> Button:
	var button: Button = Button.new()
	button.text = "No"
	add_child_autofree(button)
	button.size = Vector2(160, HEIGHT)
	return button
