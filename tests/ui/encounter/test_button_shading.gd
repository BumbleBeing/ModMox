extends GutTest
## The encounter's made buttons: Dither Shaded in their own color, as the Inspector's and the
## sidebar's are, lighter under the cursor, sat down on their lip while held, and flat and
## gray while they cannot be pressed. They never change size for it.

const BLUE: Color = Color(0.17, 0.36, 0.66)
const HEIGHT: int = 58


func test_a_shaded_button_is_dithered_in_its_color_in_every_state() -> void:
	var button: Button = _button("Keep 7")

	ButtonShading.apply(button, BLUE)

	assert_eq(button.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_true(_same(button.get_theme_stylebox("normal"), DitherShading.button_plate(BLUE, false, HEIGHT)))
	assert_true(_same(button.get_theme_stylebox("hover"),
		DitherShading.button_plate(BLUE.lightened(InspectorParts.HOVER_LIGHTEN), false, HEIGHT)))
	assert_true(_same(button.get_theme_stylebox("pressed"), DitherShading.button_plate(BLUE, true, HEIGHT)))
	assert_true(_same(button.get_theme_stylebox("hover_pressed"), DitherShading.button_plate(BLUE, true, HEIGHT)))
	assert_true(_same(button.get_theme_stylebox("disabled"), DitherShading.disabled_plate(ButtonShading.DISABLED, HEIGHT)))
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


## Whether two Dither Shaded plates are painted alike, pixel for pixel.
func _same(a: StyleBox, b: StyleBox) -> bool:
	var left: StyleBoxTexture = a as StyleBoxTexture
	var right: StyleBoxTexture = b as StyleBoxTexture
	if left == null or right == null:
		return false
	return left.texture.get_image().get_data() == right.texture.get_image().get_data()
