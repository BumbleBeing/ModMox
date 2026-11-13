class_name PauseMenu
extends Control
## The Pause Menu (game glossary): a fixed window over the battlefield, with the rest of the
## screen dimmed behind it and taking no clicks. It offers Resume, Concede, Settings and
## Quit to main menu. Concede and Quit each ask once more before they happen (A298, A300).
## Settings is a page of its own, which holds the Game Speed, Auto-pass and Auto-tap.

signal resume_pressed
## Conceding was confirmed.
signal concede_confirmed
## Quitting was confirmed.
signal quit_confirmed
## A Game Speed was pressed on the settings page.
signal speed_chosen(speed: GameSpeed.Speed)
## The Auto-pass box was pressed on the settings page: it is now [param is_on].
signal auto_pass_chosen(is_on: bool)
## The Auto-tapping box was pressed on the settings page: it is now [param is_on].
signal auto_tap_chosen(is_on: bool)

enum Page { MENU, CONCEDE, QUIT, SETTINGS }

const RESUME: String = "Resume  [ESC]"
const CONCEDE: String = "Concede"
const SETTINGS: String = "Settings"
const QUIT: String = "Quit to main menu"
const BACK: String = "Back"
const QUIT_NOW: String = "Quit"
const SPEED_HEADING: String = "Game speed"
const AUTO_PASS: String = "Auto-pass"
const AUTO_TAP: String = "Auto-tapping"
## The border of the speed in use.
const CHOSEN: Color = Color("#f2d36b")
const SPEED_GAP: float = 6.0

## How long it takes to ease in or out; the Encounter Screen sets it.
var ease_seconds: float = 0.0
var _field: Rect2 = Rect2()
var _can_concede: bool = true
var _page: Page = Page.MENU
var _window: Panel = null
var _heading: Label = null
var _buttons: Dictionary[String, Button] = {}
var _speed: GameSpeed.Speed = GameSpeed.Speed.NORMAL
var _speed_buttons: Dictionary[GameSpeed.Speed, Button] = {}
var _is_auto_passing: bool = true
var _auto_pass: Button = null
var _is_auto_tapping: bool = true
var _auto_tap: Button = null


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


## Marks [param speed] as the Game Speed in use.
func show_game_speed(speed: GameSpeed.Speed) -> void:
	_speed = speed
	for shown: GameSpeed.Speed in _speed_buttons:
		_mark_speed(_speed_buttons[shown], shown == speed)


## The settings page's button for [param speed], or null on any other page.
func speed_button(speed: GameSpeed.Speed) -> Button:
	return _speed_buttons.get(speed, null) as Button


## Whether [param speed] is marked as the one in use.
func is_speed_chosen(speed: GameSpeed.Speed) -> bool:
	return _speed == speed


## Shows Auto-pass as on or off.
func show_auto_pass(is_on: bool) -> void:
	_is_auto_passing = is_on
	if _auto_pass != null:
		_auto_pass.text = _auto_pass_text()


## The settings page's Auto-pass box, or null on any other page.
func auto_pass_button() -> Button:
	return _auto_pass


## Shows Auto-tap (game glossary) as on or off in its box.
func show_auto_tap(is_on: bool) -> void:
	_is_auto_tapping = is_on
	if _auto_tap != null:
		_auto_tap.text = _box_text(is_on, AUTO_TAP)


## The Auto-tapping box: null except on the settings page.
func auto_tap_button() -> Button:
	return _auto_tap


func window_rect() -> Rect2:
	return Rect2(_window.position, _window.size)


func _show_page(shown: Page) -> void:
	_page = shown
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_speed_buttons.clear()
	_auto_pass = null
	_auto_tap = null
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
	elif shown == Page.SETTINGS:
		title = "Settings"
		names = [BACK]
	# The settings page has four rows above Back: a heading, the speeds, Auto-pass and
	# Auto-tapping.
	var rows_above: int = 4 if shown == Page.SETTINGS else 0
	var rect: Rect2 = EncounterLayout.pause_rect(names.size() + rows_above, _field)
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
		made.position = Vector2(60, EncounterLayout.PAUSE_HEADING + (index + rows_above) * EncounterLayout.PAUSE_ROW)
		made.size = Vector2(rect.size.x - 120, EncounterLayout.PAUSE_ROW - 12)
		_window.add_child(made)
		_buttons[names[index]] = made
	if shown == Page.MENU:
		_buttons[CONCEDE].disabled = not _can_concede
	elif shown == Page.SETTINGS:
		_add_speeds(rect.size.x)
		_add_auto_pass(rect.size.x)
		_add_auto_tap(rect.size.x)


## The settings page's Game Speed: a heading, and under it a button for each speed, slowest
## at the left, the one in use with a gold border.
func _add_speeds(window_width: float) -> void:
	var heading: Label = Label.new()
	heading.text = SPEED_HEADING
	heading.position = Vector2(60, EncounterLayout.PAUSE_HEADING)
	heading.size = Vector2(window_width - 120, EncounterLayout.PAUSE_ROW - 12)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	heading.add_theme_font_size_override("font_size", 19)
	heading.modulate = Color(1, 1, 1, 0.8)
	_window.add_child(heading)
	var count: int = GameSpeed.ALL.size()
	var width: float = (window_width - 120 - SPEED_GAP * (count - 1)) / count
	for index: int in count:
		var speed: GameSpeed.Speed = GameSpeed.ALL[index]
		var made: Button = _button(GameSpeed.name_of(speed), 17)
		made.position = Vector2(60 + index * (width + SPEED_GAP), EncounterLayout.PAUSE_HEADING + EncounterLayout.PAUSE_ROW)
		made.size = Vector2(width, EncounterLayout.PAUSE_ROW - 12)
		made.pressed.connect(_on_speed_pressed.bind(speed))
		_window.add_child(made)
		_speed_buttons[speed] = made
		_mark_speed(made, speed == _speed)


## The settings page's Auto-pass box, under the speeds.
func _add_auto_pass(window_width: float) -> void:
	_auto_pass = _button(_auto_pass_text(), 19)
	_auto_pass.position = Vector2(60, EncounterLayout.PAUSE_HEADING + EncounterLayout.PAUSE_ROW * 2.0)
	_auto_pass.size = Vector2(window_width - 120, EncounterLayout.PAUSE_ROW - 12)
	_auto_pass.pressed.connect(_on_auto_pass_pressed)
	_window.add_child(_auto_pass)


func _auto_pass_text() -> String:
	return _box_text(_is_auto_passing, AUTO_PASS)


## The settings page's Auto-tapping box, under Auto-pass.
func _add_auto_tap(window_width: float) -> void:
	_auto_tap = _button(_box_text(_is_auto_tapping, AUTO_TAP), 19)
	_auto_tap.position = Vector2(60, EncounterLayout.PAUSE_HEADING + EncounterLayout.PAUSE_ROW * 3.0)
	_auto_tap.size = Vector2(window_width - 120, EncounterLayout.PAUSE_ROW - 12)
	_auto_tap.pressed.connect(_on_auto_tap_pressed)
	_window.add_child(_auto_tap)


func _on_auto_tap_pressed() -> void:
	show_auto_tap(not _is_auto_tapping)
	auto_tap_chosen.emit(_is_auto_tapping)


static func _box_text(is_on: bool, text: String) -> String:
	return ("☑" if is_on else "☐") + "  " + text


func _on_auto_pass_pressed() -> void:
	show_auto_pass(not _is_auto_passing)
	auto_pass_chosen.emit(_is_auto_passing)


func _mark_speed(made: Button, is_chosen: bool) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var flat: StyleBoxFlat = made.get_theme_stylebox(state) as StyleBoxFlat
		flat.border_color = CHOSEN
		flat.set_border_width_all(2 if is_chosen else 0)


func _on_speed_pressed(speed: GameSpeed.Speed) -> void:
	show_game_speed(speed)
	speed_chosen.emit(speed)


func _button(text: String, font_size: int = 21) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.add_theme_font_size_override("font_size", font_size)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = PlayerPanel.PLAIN_COLOR.lightened(0.22) if state in ["hover", "pressed"] else PlayerPanel.PLAIN_COLOR
		if state == "disabled":
			flat.bg_color = Color("#262a32")
		flat.set_corner_radius_all(6)
		made.add_theme_stylebox_override(state, flat)
	if not GameSpeed.NAMES.values().has(text):
		made.pressed.connect(_on_pressed.bind(text))
	return made


func _on_pressed(text: String) -> void:
	if text == RESUME:
		resume_pressed.emit()
	elif text == BACK:
		_show_page(Page.MENU)
	elif text == QUIT:
		_show_page(Page.QUIT)
	elif text == SETTINGS:
		_show_page(Page.SETTINGS)
	elif text == QUIT_NOW:
		quit_confirmed.emit()
	elif text == CONCEDE and _page == Page.MENU:
		_show_page(Page.CONCEDE)
	elif text == CONCEDE:
		concede_confirmed.emit()
