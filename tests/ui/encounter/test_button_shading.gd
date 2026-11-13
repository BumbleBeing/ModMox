extends GutTest
## The buttons of the opening-hand overlay: lit from above, with rounded corners, a lighter
## rim and a shadow underneath.

const BLUE: Color = Color(0.17, 0.36, 0.66)
const HEIGHT: int = 58
const PAD: int = ButtonShading.PAD


func test_the_corners_are_rounded_and_the_middle_is_solid() -> void:
	var strip: Image = ButtonShading.image(BLUE, HEIGHT)

	assert_eq(strip.get_pixel(PAD, PAD).a, 0.0, "The very corner of the button is cut away.")
	assert_eq(strip.get_pixel(strip.get_width() / 2, PAD + HEIGHT / 2).a, 1.0)
	assert_eq(strip.get_pixel(PAD + 12, PAD + 3).a, 1.0, "Past the corner the top edge is whole.")


func test_it_is_lit_from_above() -> void:
	var strip: Image = ButtonShading.image(BLUE, HEIGHT)
	var middle: int = strip.get_width() / 2

	var top: Color = strip.get_pixel(middle, PAD + 6)
	var bottom: Color = strip.get_pixel(middle, PAD + HEIGHT - 6)

	assert_gt(top.get_luminance(), bottom.get_luminance())
	assert_gt(top.b, top.r, "And still blue.")


func test_the_rim_is_lighter_than_what_it_surrounds() -> void:
	var strip: Image = ButtonShading.image(BLUE, HEIGHT)
	var middle: int = strip.get_width() / 2

	assert_gt(strip.get_pixel(middle, PAD).get_luminance(), strip.get_pixel(middle, PAD + 4).get_luminance(), "Along the top,")
	assert_gt(strip.get_pixel(middle, PAD + HEIGHT - 1).get_luminance(), strip.get_pixel(middle, PAD + HEIGHT - 5).get_luminance(),
		"and along the bottom, where the button is darkest.")


func test_a_shadow_falls_under_it_and_none_above() -> void:
	var strip: Image = ButtonShading.image(BLUE, HEIGHT)
	var middle: int = strip.get_width() / 2

	var under: Color = strip.get_pixel(middle, PAD + HEIGHT + 2)
	assert_gt(under.a, 0.0)
	assert_lt(under.a, 1.0)
	assert_lt(under.get_luminance(), 0.05, "Dark.")
	assert_eq(strip.get_pixel(middle, 1).a, 0.0)


func test_the_box_stretches_only_its_middle_and_draws_its_shadow_outside_the_button() -> void:
	var made: StyleBoxTexture = ButtonShading.box(BLUE, HEIGHT)

	assert_eq(made.texture.get_height(), HEIGHT + PAD * 2, "As tall as the button and its shadow: nothing stretches up or down.")
	assert_gte(made.texture_margin_left, PAD + ButtonShading.RADIUS, "The rounded ends keep their shape.")
	assert_eq(made.texture_margin_left, made.texture_margin_right)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(made.get_expand_margin(side), float(PAD))
	assert_eq(ButtonShading.box(BLUE, HEIGHT), made, "Painted once and kept.")


func test_a_shaded_button_is_lighter_under_the_cursor_darker_held_down_and_gray_when_it_cannot_be_pressed() -> void:
	var button: Button = Button.new()
	add_child_autofree(button)
	button.size = Vector2(230, HEIGHT)

	ButtonShading.apply(button, BLUE)

	assert_eq(button.get_theme_stylebox("normal"), ButtonShading.box(BLUE, HEIGHT))
	assert_eq(button.get_theme_stylebox("hover"), ButtonShading.box(ButtonShading.hover_color(BLUE), HEIGHT))
	assert_eq(button.get_theme_stylebox("pressed"), ButtonShading.box(ButtonShading.pressed_color(BLUE), HEIGHT))
	assert_eq(button.get_theme_stylebox("disabled"), ButtonShading.box(ButtonShading.DISABLED, HEIGHT))
	assert_gt(ButtonShading.hover_color(BLUE).get_luminance(), BLUE.get_luminance())
	assert_lt(ButtonShading.pressed_color(BLUE).get_luminance(), BLUE.get_luminance())
	assert_almost_eq(ButtonShading.DISABLED.r, ButtonShading.DISABLED.b, 0.08, "Gray.")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		assert_eq(button.get_theme_stylebox(state).get_minimum_size(), button.get_theme_stylebox("normal").get_minimum_size(),
			"No state changes the button's size.")
