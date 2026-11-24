class_name MenuDialog
extends Control
## A question or a notice the main menu puts over itself (milestone 21): the screen dimmed
## behind a window drawn as the menu's is, with a title, a few words under it and a row of
## the menu's buttons. Pressing one says which and closes the dialog. Nothing behind it takes
## a click while it is open.

signal chosen(text: String)

const TITLE_SIZE: int = 30
const BODY_SIZE: int = 22
## How wide the words may run before they wrap.
const BODY_WIDTH: int = 620
const DIM: Color = Color(0, 0, 0, 0.6)

var _window: PanelContainer
var _title: Label
var _body: Label
var _buttons: Dictionary[String, Button] = {}


## A dialog titled [param title], saying [param body], answered with one of [param answers],
## the first on the left.
static func make(title: String, body: String, answers: Array[String]) -> MenuDialog:
	var made: MenuDialog = MenuDialog.new()
	made._build(title, body, answers)
	return made


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


## The window the dialog's words and buttons sit in, edged in the Steel Rim as the menu's is.
func window() -> PanelContainer:
	return _window


## The button reading [param text], or null.
func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


func _build(title: String, body: String, answers: Array[String]) -> void:
	name = "MenuDialog"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_window = PanelContainer.new()
	WindowLook.shade(_window)
	center.add_child(_window)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(BODY_WIDTH, 0)
	column.add_theme_constant_override("separation", MainMenu.BUTTON_GAP)
	_window.add_child(column)
	_title = _label(title, TITLE_SIZE)
	_title.add_theme_font_override("font", UiText.bold())
	column.add_child(_title)
	_body = _label(body, BODY_SIZE)
	column.add_child(_body)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", MainMenu.BUTTON_GAP * 2)
	column.add_child(row)
	for answer: String in answers:
		var made: Button = MainMenu.menu_button(answer)
		made.custom_minimum_size.x = 220
		made.pressed.connect(_choose.bind(answer))
		row.add_child(made)
		_buttons[answer] = made


func _label(text: String, font_size: int) -> Label:
	var made: Label = Label.new()
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.text = text
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.custom_minimum_size = Vector2(BODY_WIDTH, 0)
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", SpoilsScreen.TEXT)
	return made


func _choose(answer: String) -> void:
	chosen.emit(answer)
	queue_free()
