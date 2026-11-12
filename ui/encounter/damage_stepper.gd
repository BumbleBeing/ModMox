class_name DamageStepper
extends Control
## How much combat damage one recipient is given while damage is being divided: the amount
## between a "−" and a "+" button, on the creature itself or on the attacked player's
## portrait (A318). The amount is red once it is lethal (A319). A button that would do
## nothing is grayed out.

signal lowered
signal raised

const LETHAL: Color = Color("#ff5648")
const LEFT: Color = Color("#f3e9a0")

var _amount: Label
var _minus: Button
var _plus: Button


## A stepper at [param box] showing [param amount].
func _init(box: Rect2, amount: int, is_lethal: bool, can_lower: bool, can_raise: bool) -> void:
	position = box.position
	size = box.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(CardShapes.rounded(box.size, 7, Color(0, 0, 0, 0.82)))
	var side: float = box.size.y - 6.0
	_amount = _label(str(amount), Rect2(side + 4, 0, box.size.x - (side + 4) * 2.0, box.size.y), 24, LETHAL if is_lethal else Color.WHITE)
	_amount.set_meta("is_lethal", is_lethal)
	add_child(_amount)
	_minus = _button("−", Vector2(3, 3), side, can_lower, func() -> void: lowered.emit())
	_plus = _button("+", Vector2(box.size.x - side - 3, 3), side, can_raise, func() -> void: raised.emit())


## The chip on the creature whose damage is being divided, saying how much is still to give.
static func left_chip(box: Rect2, left: int) -> Control:
	var chip: Panel = CardShapes.rounded(box.size, 6, Color(0, 0, 0, 0.82))
	chip.name = "LeftChip"
	chip.position = box.position
	var text: Label = _label("%d left" % left, Rect2(Vector2.ZERO, box.size), 17, LEFT if left > 0 else Color(1, 1, 1, 0.6))
	text.name = "Text"
	chip.add_child(text)
	return chip


func amount_text() -> String:
	return _amount.text


## Whether the amount is drawn as lethal.
func shows_lethal() -> bool:
	return _amount.get_meta("is_lethal")


func minus_button() -> Button:
	return _minus


func plus_button() -> Button:
	return _plus


static func _label(text: String, box: Rect2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = box.position
	label.size = box.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, at: Vector2, side: float, is_enabled: bool, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = at
	button.size = Vector2(side, side)
	button.disabled = not is_enabled
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = Color("#4a5362").lightened(0.25) if state in ["hover", "pressed"] else Color("#4a5362")
		if state == "disabled":
			flat.bg_color = Color("#22262e")
		flat.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, flat)
	button.pressed.connect(on_press)
	add_child(button)
	return button
