extends GutTest
## The X stepper (game ADR 0066): one framed plate whose ends are − and + and whose number
## sits in a flat dark gray well between them.

const BOX: Rect2 = Rect2(12, 114, 164, 44)
const GRAY: Color = Color("#4b4e55")


func test_it_is_one_framed_plate_with_its_number_in_a_flat_well_between_its_signs() -> void:
	var stepper: XStepper = _stepper(2, true, true, false)

	assert_eq(stepper.position, BOX.position)
	assert_eq(stepper.size, BOX.size)
	assert_eq(stepper.get_theme_stylebox("normal"), SteelFrame.plate(GRAY, "normal", 44, false), "Framed as any answer is.")
	assert_eq(stepper.amount_text(), "2")
	assert_eq(stepper.minus_button().text, "−")
	assert_eq(stepper.plus_button().text, "+")
	var well: ColorRect = _well(stepper)
	assert_eq(well.color, XStepper.WELL, "Flat: one color, not shaded.")
	assert_gt(well.position.x, stepper.minus_button().position.x + stepper.minus_button().size.x - 2.0, "Right of the −")
	assert_lt(well.position.x + well.size.x, stepper.plus_button().position.x + 2.0, "and left of the +.")
	var face: Rect2 = Rect2(0, 0, BOX.size.x, SteelFrame.face_height(BOX.size.y)).grow(-SteelFrame.FRAME)
	assert_true(face.encloses(Rect2(well.position, well.size)), "Inside the frame.")
	assert_true(face.encloses(Rect2(stepper.minus_button().position, stepper.minus_button().size)))
	assert_true(face.encloses(Rect2(stepper.plus_button().position, stepper.plus_button().size)))


func test_its_signs_have_no_shape_of_their_own() -> void:
	var stepper: XStepper = _stepper(2, true, true, false)

	var plain: StyleBoxFlat = stepper.minus_button().get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(plain)
	assert_eq(plain.bg_color.a, 0.0, "The plate's own face shows through.")
	assert_eq(plain.border_width_top, 0)


func test_an_end_lightens_under_the_cursor_with_the_same_ease() -> void:
	var stepper: XStepper = _stepper(2, true, true, false)
	var layer: Control = HoverEase.layer_of(stepper.plus_button())

	assert_not_null(layer)
	assert_eq(layer.modulate.a, 0.0)
	stepper.plus_button().mouse_entered.emit()
	await wait_seconds(0.15)
	assert_almost_eq(layer.modulate.a, 1.0, 0.01)
	assert_not_null(HoverEase.layer_of(stepper), "The plate itself too.")


func test_an_end_steps_and_the_plate_selects() -> void:
	var stepper: XStepper = _stepper(2, true, true, false)
	var said: Array[String] = []
	stepper.lowered.connect(func() -> void: said.append("lower"))
	stepper.raised.connect(func() -> void: said.append("raise"))
	stepper.pressed.connect(func() -> void: said.append("select"))

	stepper.minus_button().pressed.emit()
	stepper.plus_button().pressed.emit()
	stepper.pressed.emit()

	assert_eq(said, ["lower", "raise", "select"] as Array[String])
	assert_eq(stepper.focus_mode, Control.FOCUS_NONE)


func test_a_sign_that_cannot_step_is_dimmed() -> void:
	var lowest: XStepper = _stepper(0, false, true, false)
	var highest: XStepper = _stepper(4, true, false, false)

	assert_true(lowest.minus_button().disabled)
	assert_false(lowest.plus_button().disabled)
	assert_true(highest.plus_button().disabled)
	assert_false(highest.minus_button().disabled)


func test_selected_its_ring_is_white() -> void:
	var stepper: XStepper = _stepper(2, true, true, true)

	assert_true(stepper.is_selected())
	assert_eq(stepper.get_theme_stylebox("normal"), SteelFrame.plate(GRAY, "normal", 44, true))


func _well(stepper: XStepper) -> ColorRect:
	for child: Node in stepper.get_children():
		var rect: ColorRect = child as ColorRect
		if rect != null and rect.size.x > 2.0:
			return rect
	return null


func _stepper(amount: int, can_lower: bool, can_raise: bool, is_selected: bool) -> XStepper:
	var stepper: XStepper = XStepper.new(BOX, amount, can_lower, can_raise, GRAY, is_selected)
	add_child_autofree(stepper)
	return stepper
