extends GutTest
## The Pass Button: over the Info Panel, always there, gray and shaded (13g, A489).

const BOX: Rect2 = Rect2(352, 904, 300, 46)


func test_it_passes_priority_and_names_its_key() -> void:
	var button: PassButton = _button()

	button.show_pass(true)

	assert_eq(button.text, "Pass Priority [SPACE]")
	assert_false(button.disabled)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)


func test_it_is_there_but_cannot_be_pressed_without_priority() -> void:
	var button: PassButton = _button()

	button.show_pass(false)

	assert_true(button.visible)
	assert_true(button.disabled)
	assert_eq(button.text, "Pass Priority [SPACE]")


func test_it_names_the_key_it_is_told() -> void:
	var button: PassButton = _button()
	button.show_pass(true)

	button.show_key("ENTER")

	assert_eq(button.text, "Pass Priority [ENTER]")
	button.show_pass(false)
	assert_eq(button.text, "Pass Priority [ENTER]")


func test_it_confirms_a_choice_and_is_a_pass_button_again_afterward() -> void:
	var button: PassButton = _button()

	button.show_confirm("Attack with 2", false)

	assert_eq(button.text, "Attack with 2 [SPACE]", "It still names its key (A495).")
	assert_true(button.disabled, "Grayed out until the choice is complete.")
	assert_eq(button.get_theme_font_size("font_size"), PassButton.CONFIRM_FONT)
	button.show_key("ENTER")
	assert_eq(button.text, "Attack with 2 [ENTER]", "A new key is named on the confirm text too.")
	button.show_confirm("Attack with 2", true)
	assert_false(button.disabled)

	button.show_pass(true)

	assert_eq(button.text, "Pass Priority [ENTER]")
	assert_eq(button.get_theme_font_size("font_size"), PassButton.PASS_FONT)


func test_a_cost_on_it_is_drawn_with_its_symbols() -> void:
	# Game ADR 0063: "Pay {2}", the 2 a pip, and no key named.
	var button: PassButton = _button()

	button.show_confirm("Pay {2}", true, false)

	assert_eq(button.shown_text(), "Pay {2}")
	assert_eq(button.text, "", "The words are drawn by the symbol line, not the button.")
	assert_true(button.symbol_line().visible)
	assert_eq(button.symbol_line().symbols(), ["2"] as Array[String])
	button.show_confirm("Confirm order", true)
	assert_false(button.symbol_line().visible, "Words with no symbol are the button's own.")
	assert_eq(button.text, "Confirm order [SPACE]")
	assert_eq(button.shown_text(), "Confirm order [SPACE]")


func test_it_fills_its_box_and_is_shaded_gray() -> void:
	var button: PassButton = _button()

	assert_eq(button.position, BOX.position)
	assert_eq(button.size, BOX.size)
	assert_eq(button.get_theme_stylebox("normal"), ButtonShading.plate(Inspector.palette().button, "normal", 46),
		"Dithered in the Inspector's gray.")
	assert_eq(button.get_theme_stylebox("disabled"), ButtonShading.plate(ButtonShading.DISABLED, "disabled", 46))
	var shading: StyleBox = button.get_theme_stylebox("normal")
	button.place(Rect2(Vector2(10, 10), BOX.size))
	assert_eq(button.get_theme_stylebox("normal"), shading, "Only moved, it is not shaded again.")


func _button() -> PassButton:
	var button: PassButton = PassButton.new()
	add_child_autofree(button)
	button.place(BOX)
	return button
