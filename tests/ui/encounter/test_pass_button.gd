extends GutTest
## The Pass Button: at the right end of the hand's strip, always there, gray inside a steel
## frame, with what it does in large type and its key under it (13g, A489, game ADR 0066).

const BOX: Rect2 = Rect2(1378, 978, 360, 96)


func test_it_passes_priority_and_names_its_key_under_its_words() -> void:
	var button: PassButton = _button()

	button.show_pass(true)

	assert_eq(button.shown_text(), "Pass Priority")
	assert_eq(button.key_text(), "SPACE", "Without brackets.")
	assert_eq(button.text, "", "Its two lines are drawn over it.")
	assert_gt(button.key_line().position.y, button.symbol_line().position.y, "The key is under the words")
	assert_lt(button.key_line().get_theme_font_size("font_size"), PassButton.WORDS_FONT, "and smaller.")
	assert_false(button.disabled)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)


func test_without_priority_it_is_there_gray_and_blank() -> void:
	var button: PassButton = _button()

	button.show_pass(false)

	assert_true(button.visible)
	assert_true(button.disabled)
	assert_eq(button.shown_text(), "", "No words")
	assert_eq(button.key_text(), "", "and no key.")
	button.show_pass(true)
	assert_eq(button.shown_text(), "Pass Priority", "They come back with priority.")
	assert_eq(button.key_text(), "SPACE")


func test_a_choice_still_being_made_keeps_its_words() -> void:
	var button: PassButton = _button()

	button.show_confirm("Confirm discard", false)

	assert_true(button.disabled)
	assert_eq(button.shown_text(), "Confirm discard", "It says what is still to do.")


func test_its_border_flashes_once_whenever_it_becomes_one_that_can_be_pressed() -> void:
	var button: PassButton = _button()
	button.show_pass(false)
	await wait_process_frames(2)
	assert_eq(button.flash_count(), 0)

	button.show_pass(true)
	await wait_process_frames(2)

	assert_eq(button.flash_count(), 1)
	# A redraw turns it off and on again within a frame: that is not becoming active.
	button.show_pass(false)
	button.show_confirm("Attack with 1", true)
	await wait_process_frames(2)
	assert_eq(button.flash_count(), 1, "Still pressable, so no new flash.")
	button.show_pass(false)
	await wait_process_frames(2)
	button.show_confirm("Yes", true)
	await wait_process_frames(2)
	assert_eq(button.flash_count(), 2, "Off, then on again.")
	await wait_seconds(PassButton.FLASH_TIME + 0.15)
	assert_almost_eq(button._flash.modulate.a, 0.0, 0.01, "It settles.")


func test_the_flash_is_the_frames_own_ring_and_lights_no_corner_the_button_does_not_have() -> void:
	var button: PassButton = _button()

	assert_eq(button._flash.get_theme_stylebox("panel"), SteelFrame.ring_plate(96))
	assert_eq(button._flash.size, BOX.size)
	var ring: Image = SteelFrame.ring_plate(96).texture.get_image()
	var frame: Image = SteelFrame.plate(Inspector.palette().button, "normal", 96).texture.get_image()
	for y: int in ring.get_height():
		for x: int in ring.get_width():
			var is_lit: bool = ring.get_pixel(x, y).a > 0.0
			var is_steel: bool = frame.get_pixel(x, y).is_equal_approx(SteelFrame.STEEL)
			if is_lit != is_steel:
				fail_test("The flash and the steel ring differ at %d, %d." % [x, y])
				return
	assert_eq(ring.get_pixel(0, 0).a, 0.0, "The cut corner stays dark.")
	pass_test("The flash covers the steel ring exactly.")


func test_it_names_the_key_it_is_told() -> void:
	var button: PassButton = _button()
	button.show_pass(true)

	button.show_key("ENTER")

	assert_eq(button.key_text(), "ENTER")
	button.show_pass(false)
	button.show_pass(true)
	assert_eq(button.key_text(), "ENTER")
	assert_eq(button.shown_text(), "Pass Priority")


func test_it_confirms_a_choice_and_is_a_pass_button_again_afterward() -> void:
	var button: PassButton = _button()

	button.show_confirm("Attack with 2", false)

	assert_eq(button.shown_text(), "Attack with 2")
	assert_eq(button.key_text(), "SPACE", "It still names its key (A495).")
	assert_true(button.disabled, "Grayed out until the choice is complete.")
	button.show_key("ENTER")
	assert_eq(button.key_text(), "ENTER", "A new key is named under the confirm text too.")
	button.show_confirm("Attack with 2", true)
	assert_false(button.disabled)

	button.show_pass(true)

	assert_eq(button.shown_text(), "Pass Priority")
	assert_eq(button.key_text(), "ENTER")


func test_a_cost_on_it_is_drawn_with_its_symbols() -> void:
	# Game ADR 0063: "Pay {2}", the 2 a pip.
	var button: PassButton = _button()

	button.show_confirm("Pay {2}", true)

	assert_eq(button.shown_text(), "Pay {2}")
	assert_eq(button.symbol_line().symbols(), ["2"] as Array[String])
	assert_eq(button.key_text(), "SPACE", "Once an answer is selected, the key gives it (game ADR 0066).")
	button.show_confirm("Confirm order", true)
	assert_eq(button.symbol_line().symbols(), [] as Array[String])
	assert_eq(button.shown_text(), "Confirm order")


func test_with_no_answer_selected_it_reads_choose_an_answer_with_no_key_and_cannot_be_pressed() -> void:
	# Game ADR 0066.
	var button: PassButton = _button()

	button.show_confirm("Choose an answer", false, false)

	assert_eq(button.shown_text(), "Choose an answer")
	assert_eq(button.key_text(), "")
	assert_false(button.key_line().visible)
	assert_true(button.disabled)
	button.show_pass(true)
	assert_eq(button.key_text(), "SPACE", "A pass names its key again.")


func test_it_fills_its_box_in_gray_inside_a_steel_frame() -> void:
	var button: PassButton = _button()

	assert_eq(button.position, BOX.position)
	assert_eq(button.size, BOX.size)
	assert_eq(button.get_theme_stylebox("normal"), SteelFrame.plate(Inspector.palette().button, "normal", 96),
		"Dithered in the Inspector's gray, framed.")
	assert_eq(button.get_theme_stylebox("disabled"), SteelFrame.plate(Inspector.palette().button, "disabled", 96))
	var framing: StyleBox = button.get_theme_stylebox("normal")
	button.place(Rect2(Vector2(10, 10), BOX.size))
	assert_eq(button.get_theme_stylebox("normal"), framing, "Only moved, it is not framed again.")


func test_both_lines_are_inside_it_above_its_lip() -> void:
	var button: PassButton = _button()
	button.show_pass(true)

	var face: Rect2 = Rect2(0, 0, BOX.size.x, SteelFrame.face_height(BOX.size.y))
	assert_true(face.encloses(Rect2(button.symbol_line().position, button.symbol_line().size)))
	assert_true(face.encloses(Rect2(button.key_line().position, button.key_line().size)))


func _button() -> PassButton:
	var button: PassButton = PassButton.new()
	add_child_autofree(button)
	button.place(BOX)
	return button
