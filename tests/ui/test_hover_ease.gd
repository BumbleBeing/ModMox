extends GutTest
## Every button lightens under the cursor with a smooth, quick ease, a tenth of a second in
## and out, and never a switch (game ADR 0066).

const GRAY: Color = Color("#4b4e55")
const HEIGHT: int = 46


func after_each() -> void:
	HoverEase.unwatch(get_tree())
	await wait_process_frames(2)


func test_a_watched_button_is_made_ready_only_when_the_cursor_first_reaches_it() -> void:
	HoverEase.watch(get_tree())
	var button: Button = _shaded()
	var hover: StyleBox = button.get_theme_stylebox("hover")

	assert_null(HoverEase.layer_of(button), "Nothing is built for a button the cursor never reaches.")
	assert_eq(button.get_theme_stylebox("hover"), hover)

	button.mouse_entered.emit()

	var layer: Control = HoverEase.layer_of(button)
	assert_not_null(layer)
	assert_eq(button.get_theme_stylebox("hover"), button.get_theme_stylebox("normal"), "It draws its normal style under the cursor")
	assert_eq(layer.modulate.a, 0.0, "and the layer over it is not lit at once.")
	assert_eq(layer.get_index(), 0)
	assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(layer.size, button.size)
	await wait_seconds(HoverEase.TIME + 0.06)
	assert_almost_eq(layer.modulate.a, 1.0, 0.01, "Lit within a tenth of a second.")
	button.mouse_exited.emit()
	await wait_seconds(HoverEase.TIME + 0.06)
	assert_almost_eq(layer.modulate.a, 0.0, 0.01, "And settled as fast.")
	assert_eq(HoverEase.TIME, 0.1)


func test_the_layer_over_a_painted_plate_makes_it_the_hover_plate() -> void:
	var normal: StyleBoxTexture = DitherShading.button_plate(GRAY, false, HEIGHT)
	var hover: StyleBoxTexture = DitherShading.button_plate(GRAY.lightened(0.1), false, HEIGHT)

	var difference: StyleBoxTexture = HoverEase.difference_of(normal, hover) as StyleBoxTexture

	assert_not_null(difference)
	assert_eq(difference.texture_margin_left, hover.texture_margin_left, "Stretched as the plate is.")
	var under: Image = normal.texture.get_image()
	var over: Image = hover.texture.get_image()
	var wash: Image = difference.texture.get_image()
	assert_eq(wash.get_size(), over.get_size())
	assert_eq(wash.get_pixel(0, 0).a, 0.0, "Nothing outside the plate's rounded corner.")
	for at: Vector2i in [Vector2i(under.get_width() / 2, 4), Vector2i(under.get_width() / 2, HEIGHT / 2), Vector2i(3, HEIGHT / 2)]:
		var blended: Color = under.get_pixelv(at).lerp(Color(wash.get_pixelv(at), 1.0), wash.get_pixelv(at).a)
		assert_almost_eq(blended.r, over.get_pixelv(at).r, 0.02, "Red at %s." % at)
		assert_almost_eq(blended.g, over.get_pixelv(at).g, 0.02, "Green at %s." % at)
		assert_almost_eq(blended.b, over.get_pixelv(at).b, 0.02, "Blue at %s." % at)
	assert_eq(HoverEase.difference_of(normal, hover), difference, "Worked out once for a pair of plates.")


func test_a_flat_buttons_layer_is_white_for_a_lighter_hover_and_black_for_a_darker_one() -> void:
	assert_eq(HoverEase.wash(GRAY, GRAY).a, 0.0)
	var lighter: Color = HoverEase.wash(GRAY, GRAY.lightened(0.25))
	assert_almost_eq(lighter.a, 0.25, 0.01)
	assert_eq(Color(lighter, 1.0), Color.WHITE)
	var darker: Color = HoverEase.wash(GRAY, GRAY.darkened(0.25))
	assert_almost_eq(darker.a, 0.25, 0.01)
	assert_eq(Color(darker, 1.0), Color.BLACK)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = GRAY
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = GRAY.lightened(0.18)
	hover.set_corner_radius_all(5)

	var difference: StyleBoxFlat = HoverEase.difference_of(normal, hover) as StyleBoxFlat

	assert_almost_eq(difference.bg_color.a, 0.18, 0.01)
	assert_eq(difference.corner_radius_top_left, 5, "The hover's own shape.")


func test_a_hover_whose_difference_cannot_be_drawn_is_left_to_switch() -> void:
	HoverEase.watch(get_tree())
	var button: Button = Button.new()
	button.text = "Same"
	var one: StyleBoxFlat = StyleBoxFlat.new()
	one.bg_color = Color(0.2, 0.2, 0.2, 0.6)
	var other: StyleBoxFlat = StyleBoxFlat.new()
	other.bg_color = Color(0.9, 0.2, 0.2, 0.8)
	button.add_theme_stylebox_override("normal", one)
	button.add_theme_stylebox_override("hover", other)
	add_child_autofree(button)

	button.mouse_entered.emit()

	assert_null(HoverEase.layer_of(button))
	assert_eq(button.get_theme_stylebox("hover"), other, "Its hover is as it made it.")
	assert_null(HoverEase.difference_of(one, one), "Nor is there one between a style and itself.")


func test_a_button_that_cannot_be_pressed_or_is_toggled_on_does_not_light_and_one_held_goes_dark() -> void:
	HoverEase.watch(get_tree())
	var off: Button = _shaded()
	off.disabled = true
	var toggled: Button = _shaded()
	toggled.toggle_mode = true
	toggled.button_pressed = true
	var held: Button = _shaded()

	off.mouse_entered.emit()
	toggled.mouse_entered.emit()
	held.mouse_entered.emit()
	await wait_seconds(HoverEase.TIME + 0.06)

	assert_eq(HoverEase.layer_of(off).modulate.a, 0.0)
	assert_eq(HoverEase.layer_of(toggled).modulate.a, 0.0)
	assert_almost_eq(HoverEase.layer_of(held).modulate.a, 1.0, 0.01)
	held.button_down.emit()
	assert_eq(HoverEase.layer_of(held).modulate.a, 0.0, "Held down, it shows its pressed style unlit.")


func test_a_button_styled_anew_gets_a_new_layer_the_next_time_the_cursor_comes() -> void:
	HoverEase.watch(get_tree())
	var button: Button = _shaded()
	button.mouse_entered.emit()
	button.mouse_exited.emit()
	var first: StyleBox = HoverEase.layer_of(button).get_theme_stylebox("panel")

	ButtonShading.apply(button, Color(0.17, 0.36, 0.66))
	button.mouse_entered.emit()
	await wait_process_frames(2)

	assert_ne(HoverEase.layer_of(button).get_theme_stylebox("panel"), first)
	assert_eq(button.get_theme_stylebox("hover"), button.get_theme_stylebox("normal"))
	var layers: int = 0
	for child: Node in button.get_children():
		if child.name.begins_with(HoverEase.LAYER):
			layers += 1
	assert_eq(layers, 1, "Still one layer.")


func test_only_plain_buttons_are_watched_and_a_steel_framed_one_keeps_its_own_layer() -> void:
	HoverEase.watch(get_tree())
	var box: CheckBox = CheckBox.new()
	add_child_autofree(box)
	var framed: Button = Button.new()
	add_child_autofree(framed)
	framed.size = Vector2(160, 44)
	SteelFrame.apply(framed, GRAY)
	var own: Control = HoverEase.layer_of(framed)

	box.mouse_entered.emit()
	framed.mouse_entered.emit()

	assert_null(box.get_node_or_null(HoverEase.LAYER), "A checkbox is not a plain button.")
	assert_eq(HoverEase.layer_of(framed), own, "Its own layer, not a second.")


func test_the_main_menu_watches_the_whole_tree_and_watching_twice_is_once() -> void:
	assert_false(HoverEase.is_watching(get_tree()))

	HoverEase.watch(get_tree())
	HoverEase.watch(get_tree())

	assert_true(HoverEase.is_watching(get_tree()))
	var source: String = FileAccess.get_file_as_string("res://ui/menu/main_menu.gd")
	assert_true(source.contains("HoverEase.watch(get_tree())"), "The game always opens on the main menu.")


func _shaded() -> Button:
	var button: Button = Button.new()
	button.text = "Keep 7"
	add_child_autofree(button)
	button.size = Vector2(200, HEIGHT)
	ButtonShading.apply(button, GRAY)
	return button
