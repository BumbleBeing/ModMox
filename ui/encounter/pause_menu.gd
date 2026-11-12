class_name PauseMenu
extends Control
## The Pause Menu (game glossary): a fixed window over the battlefield, with the rest of the
## screen dimmed behind it and taking no clicks. It offers Resume, Concede, Settings (not
## built yet, so grayed out) and Quit to main menu. Concede and Quit each ask once more
## before they happen (A298, A300).

signal resume_pressed
## Conceding was confirmed.
signal concede_confirmed
## Quitting was confirmed.
signal quit_confirmed

enum Page { MENU, CONCEDE, QUIT }

const RESUME: String = "Resume  [ESC]"
const CONCEDE: String = "Concede"
const SETTINGS: String = "Settings"
const QUIT: String = "Quit to main menu"
const BACK: String = "Back"
const QUIT_NOW: String = "Quit"

## How long it takes to ease in or out; the Encounter Screen sets it.
var ease_seconds: float = 0.0
var _field: Rect2 = Rect2()
var _can_concede: bool = true
var _page: Page = Page.MENU
var _window: Panel = null
var _heading: Label = null
var _buttons: Dictionary[String, Button] = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


## Opens on its first page, centered on [param field]. [param can_concede] is false once
## the encounter is over.
func open(field: Rect2, can_concede: bool) -> void:
	_field = field
	_can_concede = can_concede
	_show_page(Page.MENU)
	Easing.appear(self, ease_seconds)


## Closes, easing out. It is closed at once and takes no clicks while it fades.
func close() -> void:
	Easing.disappear(self, ease_seconds)


func is_open() -> bool:
	return Easing.is_shown(self)


func page() -> Page:
	return _page


func heading_text() -> String:
	return _heading.text


## The button reading [param text] on the page showing, or null.
func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


func window_rect() -> Rect2:
	return Rect2(_window.position, _window.size)


func _show_page(shown: Page) -> void:
	_page = shown
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title: String = "Paused"
	var names: Array[String] = [RESUME, CONCEDE, SETTINGS, QUIT]
	if shown == Page.CONCEDE:
		title = "Concede this encounter?"
		names = [CONCEDE, BACK]
	elif shown == Page.QUIT:
		title = "Quit to the main menu?\nThis encounter will be lost."
		names = [QUIT_NOW, BACK]
	var rect: Rect2 = EncounterLayout.pause_rect(names.size(), _field)
	_window = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 0.98)
	style.border_color = InfoPanel.BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	_window.add_theme_stylebox_override("panel", style)
	_window.position = rect.position
	_window.size = rect.size
	add_child(_window)
	_heading = Label.new()
	_heading.text = title
	_heading.position = Vector2(20, 14)
	_heading.size = Vector2(rect.size.x - 40, EncounterLayout.PAUSE_HEADING - 24)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 32 if shown == Page.MENU else 23)
	_window.add_child(_heading)
	for index: int in names.size():
		var made: Button = _button(names[index])
		made.position = Vector2(60, EncounterLayout.PAUSE_HEADING + index * EncounterLayout.PAUSE_ROW)
		made.size = Vector2(rect.size.x - 120, EncounterLayout.PAUSE_ROW - 12)
		_window.add_child(made)
		_buttons[names[index]] = made
	if shown == Page.MENU:
		# Settings arrive with their own milestone; until then the row only marks the place.
		_buttons[SETTINGS].disabled = true
		_buttons[CONCEDE].disabled = not _can_concede


func _button(text: String) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.add_theme_font_size_override("font_size", 21)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = PlayerPanel.PLAIN_COLOR.lightened(0.22) if state in ["hover", "pressed"] else PlayerPanel.PLAIN_COLOR
		if state == "disabled":
			flat.bg_color = Color("#262a32")
		flat.set_corner_radius_all(6)
		made.add_theme_stylebox_override(state, flat)
	made.pressed.connect(_on_pressed.bind(text))
	return made


func _on_pressed(text: String) -> void:
	if text == RESUME:
		resume_pressed.emit()
	elif text == BACK:
		_show_page(Page.MENU)
	elif text == QUIT:
		_show_page(Page.QUIT)
	elif text == QUIT_NOW:
		quit_confirmed.emit()
	elif text == CONCEDE and _page == Page.MENU:
		_show_page(Page.CONCEDE)
	elif text == CONCEDE:
		concede_confirmed.emit()
