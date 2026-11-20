class_name XStepper
extends Button
## The X stepper (game ADR 0066): the Pay answer while how much X to pay is asked, as the
## left half of the Info Panel's Answer Row. It is one plate, framed as any answer is
## (SteelFrame). Its ends are the − and the +, drawn on its own face with no shape of their
## own, and its number sits in a flat dark gray well between them. A press of an end steps
## X; a press anywhere on it selects it.

signal lowered
signal raised

## How wide each end is.
const END: float = 46.0
## The flat gray of the well the number sits in.
const WELL: Color = Color("#1e2228")
const AMOUNT_FONT: int = 24
const SIGN_FONT: int = 24
## How far an end lightens under the cursor.
const END_HOVER: float = 0.12

var _amount: Label
var _minus: Button
var _plus: Button
var _is_selected: bool = false


func _init(box: Rect2, amount: int, can_lower: bool, can_raise: bool, color: Color, is_selected: bool) -> void:
	position = box.position
	size = box.size
	focus_mode = Control.FOCUS_NONE
	_is_selected = is_selected
	SteelFrame.apply(self, color, is_selected)
	var face: float = SteelFrame.face_height(box.size.y)
	var frame: float = SteelFrame.FRAME
	var inner: float = face - frame * 2.0
	var well: ColorRect = ColorRect.new()
	well.color = WELL
	well.position = Vector2(END, frame)
	well.size = Vector2(box.size.x - END * 2.0, inner)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(well)
	for x: float in [END - 1.0, box.size.x - END]:
		var divider: ColorRect = ColorRect.new()
		divider.color = WELL.darkened(0.5)
		divider.position = Vector2(x, frame)
		divider.size = Vector2(1, inner)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(divider)
	_amount = Label.new()
	_amount.text = str(amount)
	_amount.position = well.position
	_amount.size = well.size
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_amount.add_theme_font_size_override("font_size", AMOUNT_FONT + UiText.RAISE)
	_amount.add_theme_color_override("font_color", Color.WHITE)
	_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amount.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_amount)
	_minus = _end("−", Rect2(frame, frame, END - 1.0 - frame, inner), can_lower, func() -> void: lowered.emit())
	_plus = _end("+", Rect2(box.size.x - END + 1.0, frame, END - 1.0 - frame, inner), can_raise, func() -> void: raised.emit())


func amount_text() -> String:
	return _amount.text


func minus_button() -> Button:
	return _minus


func plus_button() -> Button:
	return _plus


## Whether it is the Selected Answer, its ring white.
func is_selected() -> bool:
	return _is_selected


## One end: its sign on the plate's own face, and the press that steps. It has no plate of
## its own, only a lighter face under the cursor, eased as the plate's is.
func _end(sign_text: String, box: Rect2, is_enabled: bool, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = sign_text
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	button.disabled = not is_enabled
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_theme_font_size_override("font_size", SIGN_FONT + UiText.RAISE)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	for state: String in ButtonShading.STATES:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = Color(1, 1, 1, 0.0)
		if state in ["pressed", "hover_pressed"]:
			flat.bg_color = Color(0, 0, 0, 0.25)
		button.add_theme_stylebox_override(state, flat)
	button.pressed.connect(on_press)
	var lit: ColorRect = ColorRect.new()
	lit.color = Color(1, 1, 1, END_HOVER)
	lit.size = box.size
	HoverEase.ease(button, lit)
	add_child(button)
	return button
