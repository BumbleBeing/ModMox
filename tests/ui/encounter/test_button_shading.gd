extends GutTest
## The encounter's made buttons: in the steel frame, Dither Shaded in their own color, as the
## Inspector's and the sidebar's are, lighter under the cursor, sat down on their lip while held, and flat and
## gray while they cannot be pressed. They never change size for it.

const BLUE: Color = Color(0.17, 0.36, 0.66)
const HEIGHT: int = 58


func test_a_shaded_button_is_framed_in_steel_and_dithered_in_its_color_in_every_state() -> void:
	var button: Button = _button("Keep 7")

	ButtonShading.apply(button, BLUE)

	assert_eq(button.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	for state: String in ButtonShading.STATES:
		assert_eq(button.get_theme_stylebox(state), SteelFrame.plate(BLUE, state, HEIGHT), state)
	var normal: Image = (button.get_theme_stylebox("normal") as StyleBoxTexture).texture.get_image()
	var middle: int = normal.get_width() / 2
	assert_eq(normal.get_pixel(middle, 0), SteelFrame.STEEL, "The steel ring every button has (game ADR 0066),")
	assert_true(_same_color(normal.get_pixel(middle, HEIGHT / 2), DitherShading.band_color(middle, HEIGHT / 2,
		HEIGHT - DitherShading.LIP, BLUE.lightened(0.12), BLUE.darkened(0.25))), "round its own color, dithered.")
	assert_false(_same(button.get_theme_stylebox("hover"), button.get_theme_stylebox("normal")), "Lighter under the cursor.")
	assert_false(_same(button.get_theme_stylebox("pressed"), button.get_theme_stylebox("normal")), "Sat down while held.")
	var flat: Image = (button.get_theme_stylebox("disabled") as StyleBoxTexture).texture.get_image()
	assert_ne(flat.get_pixel(middle, HEIGHT - 1), normal.get_pixel(middle, HEIGHT - 1), "Flat, with no lip, while it cannot be pressed.")
	assert_eq(ButtonShading.DISABLED, Inspector.palette().button_disabled, "Gray as the Inspector's are.")


func test_its_text_is_white_and_dim_while_it_cannot_be_pressed() -> void:
	var button: Button = _button("Keep 7")
	ButtonShading.apply(button, BLUE)
	assert_eq(button.get_theme_color("font_color"), Color.WHITE)
	assert_eq(button.get_theme_color("font_hover_color"), Color.WHITE)
	assert_eq(button.get_theme_color("font_disabled_color"), ButtonShading.DISABLED_TEXT)


func test_shade_leaves_the_text_colors_alone() -> void:
	var button: Button = _button("Emblems")
	button.add_theme_color_override("font_color", Color.GOLD)
	ButtonShading.shade(button, BLUE)
	assert_eq(button.get_theme_color("font_color"), Color.GOLD)


func test_each_plate_is_painted_once_and_shared() -> void:
	var one: Button = _button("Keep 7")
	var other: Button = _button("Mulligan")
	ButtonShading.apply(one, BLUE)
	ButtonShading.apply(other, BLUE)
	assert_eq(one.get_theme_stylebox("normal"), other.get_theme_stylebox("normal"))
	assert_eq(one.get_theme_stylebox("normal"), ButtonShading.plate(BLUE, "normal", HEIGHT))


func test_the_text_is_lifted_above_the_lip_with_little_room_round_it() -> void:
	var plate: StyleBox = ButtonShading.plate(BLUE, "normal", HEIGHT)
	assert_eq(plate.content_margin_top, 0.0)
	assert_eq(plate.content_margin_bottom, float(DitherShading.LIP))
	assert_eq(plate.content_margin_left, float(ButtonShading.SIDE))
	var flat: StyleBox = ButtonShading.plate(BLUE, "normal", HEIGHT, 2, false)
	assert_eq(flat.content_margin_bottom, 0.0, "Or centered on the whole plate where even that would not fit.")
	assert_eq(flat.content_margin_left, 2.0)


func test_a_button_keeps_its_size() -> void:
	var button: Button = _button("Pass Priority [SPACE]")
	button.size = Vector2(280, 46)
	button.add_theme_font_size_override("font_size", 21 + UiText.RAISE)
	ButtonShading.apply(button, BLUE)
	await wait_process_frames(1)
	assert_eq(button.size, Vector2(280, 46))


func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.size = Vector2(240, HEIGHT)
	add_child_autofree(button)
	return button


func _same_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Whether two Dither Shaded plates are painted alike, pixel for pixel.
func _same(a: StyleBox, b: StyleBox) -> bool:
	var left: StyleBoxTexture = a as StyleBoxTexture
	var right: StyleBoxTexture = b as StyleBoxTexture
	if left == null or right == null:
		return false
	return left.texture.get_image().get_data() == right.texture.get_image().get_data()
