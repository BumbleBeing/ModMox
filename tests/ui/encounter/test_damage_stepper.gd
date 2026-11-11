extends GutTest
## A DamageStepper shows how much damage one recipient is given, with a button to give it
## less and one to give it more.

const BOX: Rect2 = Rect2(40, 60, 112, 36)

var _events: Array[String] = []


func before_each() -> void:
	_events.clear()


func test_it_shows_its_amount_between_a_minus_and_a_plus() -> void:
	var stepper: DamageStepper = _stepper(3, false, true, true)

	assert_eq(stepper.position, BOX.position)
	assert_eq(stepper.size, BOX.size)
	assert_eq(stepper.amount_text(), "3")
	assert_eq(stepper.minus_button().text, "−")
	assert_eq(stepper.plus_button().text, "+")
	assert_lt(stepper.minus_button().position.x, stepper._amount.position.x, "Minus on the left,")
	assert_gt(stepper.plus_button().position.x, stepper._amount.position.x, "plus on the right.")
	assert_true(Rect2(Vector2.ZERO, BOX.size).encloses(Rect2(stepper.plus_button().position, stepper.plus_button().size)))
	assert_eq(stepper.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Only its buttons take clicks.")


func test_its_buttons_say_lower_and_raise() -> void:
	var stepper: DamageStepper = _stepper(3, false, true, true)

	stepper.plus_button().pressed.emit()
	stepper.minus_button().pressed.emit()
	stepper.minus_button().pressed.emit()

	assert_eq(_events, ["raised", "lowered", "lowered"] as Array[String])


func test_a_button_that_would_do_nothing_is_grayed_out() -> void:
	var full: DamageStepper = _stepper(0, false, false, true)
	var spent: DamageStepper = _stepper(4, true, true, false)

	assert_true(full.minus_button().disabled, "Nothing to take away.")
	assert_false(full.plus_button().disabled)
	assert_false(spent.minus_button().disabled)
	assert_true(spent.plus_button().disabled, "Nothing left to give.")
	var normal: Color = (spent.plus_button().get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	var disabled: Color = (spent.plus_button().get_theme_stylebox("disabled") as StyleBoxFlat).bg_color
	var hover: Color = (spent.plus_button().get_theme_stylebox("hover") as StyleBoxFlat).bg_color
	assert_lt(disabled.get_luminance(), normal.get_luminance(), "It looks like it cannot be pressed.")
	assert_gt(hover.get_luminance(), normal.get_luminance(), "And one that can brightens under the cursor.")


func test_a_lethal_amount_is_red() -> void:
	var lethal: DamageStepper = _stepper(2, true, true, true)
	var short: DamageStepper = _stepper(1, false, true, true)

	assert_true(lethal.shows_lethal())
	assert_eq(lethal._amount.get_theme_color("font_color"), DamageStepper.LETHAL)
	assert_false(short.shows_lethal())
	assert_eq(short._amount.get_theme_color("font_color"), Color.WHITE)


func test_the_left_chip_says_how_much_is_still_to_give_and_fades_at_nothing() -> void:
	var some: Control = DamageStepper.left_chip(BOX, 2)
	var none: Control = DamageStepper.left_chip(BOX, 0)
	add_child_autofree(some)
	add_child_autofree(none)

	assert_eq(some.position, BOX.position)
	assert_eq((some.get_node("Text") as Label).text, "2 left")
	assert_eq((some.get_node("Text") as Label).get_theme_color("font_color"), DamageStepper.LEFT)
	assert_eq((none.get_node("Text") as Label).text, "0 left")
	assert_lt((none.get_node("Text") as Label).get_theme_color("font_color").a, 1.0)


func _stepper(amount: int, is_lethal: bool, can_lower: bool, can_raise: bool) -> DamageStepper:
	var stepper: DamageStepper = DamageStepper.new(BOX, amount, is_lethal, can_lower, can_raise)
	add_child_autofree(stepper)
	stepper.lowered.connect(func() -> void: _events.append("lowered"))
	stepper.raised.connect(func() -> void: _events.append("raised"))
	return stepper
