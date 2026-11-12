class_name ChoicePrompt
extends Control
## A small window over the deckbuilder that asks one question and offers a few answers.
## Nothing behind it takes clicks until one is chosen. It reports the answer and does
## nothing else.

signal chosen(index: int)

const WINDOW: Vector2 = Vector2(640, 220)
const PAD: float = 24.0
const DIM: Color = Color(0, 0, 0, 0.6)
const FILL: Color = Color("#23272e")
const BORDER: Color = Color("#4a515d")
const MUTED: Color = Color("#9aa3af")

var _buttons: Array[Button] = []
var _message: Label = null


## Asks [param message] under [param title], with a button for each of [param choices].
func setup(title: String, message: String, choices: Array[String]) -> void:
	theme = DeckbuilderLook.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var window: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FILL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	window.add_theme_stylebox_override("panel", style)
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.offset_left = -WINDOW.x / 2.0
	window.offset_right = WINDOW.x / 2.0
	window.offset_top = -WINDOW.y / 2.0
	window.offset_bottom = WINDOW.y / 2.0
	add_child(window)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	rows.position = Vector2(PAD, PAD)
	rows.size = WINDOW - 2.0 * Vector2(PAD, PAD)
	window.add_child(rows)
	var heading: Label = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 26)
	rows.add_child(heading)
	_message = Label.new()
	_message.text = message
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message.add_theme_font_size_override("font_size", 18)
	_message.add_theme_color_override("font_color", MUTED)
	rows.add_child(_message)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	rows.add_child(row)
	for index: int in choices.size():
		var button: Button = Button.new()
		button.text = choices[index]
		button.custom_minimum_size = Vector2(120, 40)
		button.add_theme_font_size_override("font_size", 20)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: chosen.emit(index))
		row.add_child(button)
		_buttons.append(button)


## The button for the answer at [param index].
func button(index: int) -> Button:
	return _buttons[index]


func message() -> String:
	return _message.text
