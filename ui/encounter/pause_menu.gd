class_name PauseMenu
extends Control
## The Pause Menu (game glossary): a fixed window over the battlefield, with the rest of the
## screen dimmed behind it and taking no clicks. It offers Resume, Concede, Settings and
## Quit to main menu. Concede and Quit each ask once more before they happen (A298, A300).
## Settings is a page of its own, which holds the Game Speed, Auto-pass and Auto-tap, and
## a Controls button that opens the Controls Page (game glossary): a row for each action that has
## a key, which waits for the next key pressed once it is clicked, with "Reset controls" under
## them. Rows that share a key are red (ADR 0034).
##
## In a run (milestone 21) it also offers Abandon Run under Quit, which asks once more, and
## shows the Run Seed at its foot; on a run's screens away from an encounter it has no
## Concede, and Quit goes at once, since nothing is lost there. In a run's encounter Quit
## says the encounter will start over. The settings page has the Open Run Logs folder button,
## and in a playtest build the Share Run Logs box.
##
## It is drawn as the Spoils screen's window is (WindowLook): an edged, well rounded window
## with Dither Shading, and rounded, dithered slate-gray buttons; the Game Speed in use has
## a gold ring.

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

## A row of the Controls Page was given another key, or every key was reset.
signal keys_changed
## Abandoning the run was confirmed.
signal abandon_confirmed
## The Share Run Logs box was pressed on the settings page: it is now [param is_on].
signal share_logs_chosen(is_on: bool)
## Open Run Logs folder was pressed.
signal open_logs_pressed

enum Page { MENU, CONCEDE, QUIT, SETTINGS, CONTROLS, ABANDON }

const RESUME: String = "Resume  [ESC]"
const CONCEDE: String = "Concede"
const SETTINGS: String = "Settings"
const QUIT: String = "Quit to main menu"
const BACK: String = "Back"
const CONTROLS: String = "Controls"
const RESET_KEYS: String = "Reset controls"
## What a row of the Controls Page reads while it waits for a key.
const WAITING: String = "Press a key…"
## Rows of the Controls Page whose actions share a key.
const SHARED: Color = Color("#ff5c4d")
const QUIT_NOW: String = "Quit"
const ABANDON: String = "Abandon Run"
const ABANDON_NOW: String = "Abandon"
const OPEN_LOGS: String = "Open Run Logs folder"
const SHARE_LOGS: String = "Share Run Logs"
const RUN_SEED: String = "Run Seed %d"
const RUN_SEED_SIZE: int = 18
const SPEED_HEADING: String = "Game speed"
const AUTO_PASS: String = "Auto-pass"
const AUTO_TAP: String = "Auto-tapping"
## The border of the speed in use.
const CHOSEN: Color = Color("#f2d36b")
const SPEED_GAP: float = 6.0
## How rounded the window is.
const RADIUS: int = WindowLook.RADIUS
## What rings the Game Speed in use.
const RING: String = "Chosen"
const RING_WIDTH: int = 2

static var _rings: Dictionary[int, StyleBoxTexture] = {}

## How long it takes to ease in or out; the Encounter Screen sets it.
var ease_seconds: float = 0.0
## Whether it offers Concede: in an encounter, and not on a run's other screens.
var has_concede: bool = true
## Whether Quit asks once more before it happens: in an encounter, where something is lost.
var asks_before_quitting: bool = true
## Whether the settings page has the Share Run Logs box: in a playtest build.
var has_share_box: bool = false
var _is_in_run: bool = false
var _run_seed: int = 0
var _is_sharing: bool = false
var _share_box: Button = null
var _run_seed_label: Label = null
var _field: Rect2 = Rect2()
var _can_concede: bool = true
var _page: Page = Page.MENU
var _window: Panel = null
var _heading: Label = null
var _buttons: Dictionary[String, Button] = {}
var _speed_heading: Label = null
var _speed: GameSpeed.Speed = GameSpeed.Speed.NORMAL
var _speed_buttons: Dictionary[GameSpeed.Speed, Button] = {}
var _is_auto_passing: bool = true
var _auto_pass: Button = null
var _is_auto_tapping: bool = true
var _auto_tap: Button = null
## The Key Bindings the Controls Page shows and changes; the Encounter Screen gives it the
## ones in use.
var key_bindings: KeyBindings = KeyBindings.new()
## The action whose row waits for a key, or KeyBindings.NOTHING.
var _waiting: int = KeyBindings.NOTHING
var _key_buttons: Dictionary[KeyBindings.Action, Button] = {}
var _key_labels: Dictionary[KeyBindings.Action, Label] = {}


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


## Shows the menu as a run's: Abandon Run under Quit, and [param run_seed] at its foot.
func show_run(run_seed: int) -> void:
	_is_in_run = true
	_run_seed = run_seed


## The Run Seed at the first page's foot, or null outside a run or on another page.
func run_seed_label() -> Label:
	return _run_seed_label


## Marks the Share Run Logs box [param is_on].
func show_share_logs(is_on: bool) -> void:
	_is_sharing = is_on
	if _share_box != null:
		_share_box.text = _box_text(is_on, SHARE_LOGS)


## The settings page's Share Run Logs box, or null on any other page or outside a playtest
## build.
func share_box() -> Button:
	return _share_box


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


## Whether a row of the Controls Page waits for a key: the next key pressed is its, not the
## game's.
func is_waiting_for_key() -> bool:
	return _waiting != KeyBindings.NOTHING


## Gives [param keycode] to the row that waits for a key. Escape, which is never bound,
## only stops the row waiting.
func take_key(keycode: Key) -> void:
	if not is_waiting_for_key():
		return
	var is_bound: bool = key_bindings.bind(_waiting as KeyBindings.Action, keycode)
	_waiting = KeyBindings.NOTHING
	_show_page(Page.CONTROLS)
	if is_bound:
		keys_changed.emit()


## The Controls Page's button for [param action], which shows its key, or null on any other
## page.
func key_button(action: KeyBindings.Action) -> Button:
	return _key_buttons.get(action)


## Whether the Controls Page shows [param action] in red, as sharing its key.
func shows_shared(action: KeyBindings.Action) -> bool:
	return _key_labels.has(action) and _key_labels[action].get_theme_color("font_color") == SHARED


## The window of the page showing.
func window() -> Panel:
	return _window


## The "Game speed" heading of the settings page, or null on any other page.
func speed_heading() -> Label:
	return _speed_heading if is_instance_valid(_speed_heading) else null


## The gold ring on the button for [param speed], shown while it is the Game Speed in use;
## null on any other page.
func chosen_ring(speed: GameSpeed.Speed) -> Panel:
	var made: Button = speed_button(speed)
	return made.get_node(RING) as Panel if made != null else null


func window_rect() -> Rect2:
	return Rect2(_window.position, _window.size)


func _show_page(shown: Page) -> void:
	_page = shown
	if shown != Page.CONTROLS:
		_waiting = KeyBindings.NOTHING
	_key_buttons.clear()
	_key_labels.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_speed_buttons.clear()
	_auto_pass = null
	_auto_tap = null
	_share_box = null
	_run_seed_label = null
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title: String = "Paused"
	var names: Array[String] = [RESUME]
	if has_concede:
		names.append(CONCEDE)
	names.append_array([SETTINGS, QUIT])
	if _is_in_run:
		names.append(ABANDON)
	if shown == Page.CONCEDE:
		title = "Concede this encounter?"
		names = [CONCEDE, BACK]
	elif shown == Page.QUIT:
		title = "Quit to the main menu?\nThis encounter will %s." % ("start over when you continue" if _is_in_run else "be lost")
		names = [QUIT_NOW, BACK]
	elif shown == Page.ABANDON:
		title = "Abandon this run?\nIt can't be continued."
		names = [ABANDON_NOW, BACK]
	elif shown == Page.SETTINGS:
		title = "Settings"
		names = [CONTROLS, OPEN_LOGS, BACK]
	elif shown == Page.CONTROLS:
		title = "Controls"
		names = [RESET_KEYS, BACK]
	# The settings page has four rows above its buttons: a heading, the speeds, Auto-pass
	# and Auto-tapping. The Controls Page has a row for each action.
	# A playtest build's settings page has the Share Run Logs box under them. The first page
	# of a run's menu has a row under its buttons for the Run Seed.
	var rows_above: int = 0
	if shown == Page.SETTINGS:
		rows_above = 5 if has_share_box else 4
	elif shown == Page.CONTROLS:
		rows_above = KeyBindings.ACTIONS.size()
	var rows_below: int = 1 if shown == Page.MENU and _is_in_run else 0
	var rect: Rect2 = EncounterLayout.pause_rect(names.size() + rows_above + rows_below, _field)
	_window = Panel.new()
	_window.position = rect.position
	_window.size = rect.size
	add_child(_window)
	InspectorParts.shade_background(_window, null, WindowLook.FILL, WindowLook.EDGE, WindowLook.EDGE_WIDTH, RADIUS)
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
		_shade(made)
		_window.add_child(made)
		_buttons[names[index]] = made
	if shown == Page.MENU:
		if has_concede:
			_buttons[CONCEDE].disabled = not _can_concede
		if _is_in_run:
			_add_run_seed(rect.size.x, names.size())
	elif shown == Page.SETTINGS:
		_add_speeds(rect.size.x)
		_add_auto_pass(rect.size.x)
		_add_auto_tap(rect.size.x)
		if has_share_box:
			_add_share_box(rect.size.x)
	elif shown == Page.CONTROLS:
		_add_key_rows(rect.size.x)


## The Controls Page's rows: each action's name, and a button showing its key that waits for
## another when pressed. An action that shares its key is red.
func _add_key_rows(window_width: float) -> void:
	for index: int in KeyBindings.ACTIONS.size():
		var action: KeyBindings.Action = KeyBindings.ACTIONS[index]
		var top: float = EncounterLayout.PAUSE_HEADING + index * EncounterLayout.PAUSE_ROW
		var label: Label = Label.new()
		label.text = KeyBindings.name_of(action)
		label.position = Vector2(40, top)
		label.size = Vector2(180, EncounterLayout.PAUSE_ROW - 12)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 21)
		_window.add_child(label)
		_key_labels[action] = label
		var made: Button = _button(WAITING if action == _waiting else key_bindings.label_of(action))
		made.position = Vector2(230, top)
		made.size = Vector2(window_width - 270, EncounterLayout.PAUSE_ROW - 12)
		_shade(made)
		made.pressed.connect(_on_key_row_pressed.bind(action))
		_window.add_child(made)
		_key_buttons[action] = made
		if key_bindings.is_shared(action) and action != _waiting:
			label.add_theme_color_override("font_color", SHARED)
			for color: String in ["font_color", "font_hover_color", "font_pressed_color"]:
				made.add_theme_color_override(color, SHARED)


func _on_key_row_pressed(action: KeyBindings.Action) -> void:
	_waiting = action
	_show_page(Page.CONTROLS)


## The settings page's Game Speed: a heading, and under it a button for each speed, slowest
## at the left, the one in use with a gold border.
func _add_speeds(window_width: float) -> void:
	var heading: Label = Label.new()
	heading.text = SPEED_HEADING
	heading.position = Vector2(60, EncounterLayout.PAUSE_HEADING)
	heading.size = Vector2(window_width - 120, EncounterLayout.PAUSE_ROW - 12)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	heading.add_theme_font_size_override("font_size", 19)
	heading.modulate = Color(1, 1, 1, 0.8)
	_window.add_child(heading)
	_speed_heading = heading
	var count: int = GameSpeed.ALL.size()
	var width: float = (window_width - 120 - SPEED_GAP * (count - 1)) / count
	for index: int in count:
		var speed: GameSpeed.Speed = GameSpeed.ALL[index]
		var made: Button = _button(GameSpeed.name_of(speed), 17)
		made.position = Vector2(60 + index * (width + SPEED_GAP), EncounterLayout.PAUSE_HEADING + EncounterLayout.PAUSE_ROW)
		made.size = Vector2(width, EncounterLayout.PAUSE_ROW - 12)
		_shade(made)
		# The ring is painted round the button's own plate, so its corners are the button's.
		var ring: Panel = Panel.new()
		ring.name = RING
		ring.size = made.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.add_theme_stylebox_override("panel", _chosen_ring_of(made))
		made.add_child(ring)
		made.pressed.connect(_on_speed_pressed.bind(speed))
		_window.add_child(made)
		_speed_buttons[speed] = made
		_mark_speed(made, speed == _speed)


## The settings page's Auto-pass box, under the speeds.
func _add_auto_pass(window_width: float) -> void:
	_auto_pass = _button(_auto_pass_text(), 19)
	_auto_pass.position = Vector2(60, EncounterLayout.PAUSE_HEADING + EncounterLayout.PAUSE_ROW * 2.0)
	_auto_pass.size = Vector2(window_width - 120, EncounterLayout.PAUSE_ROW - 12)
	_shade(_auto_pass)
	_auto_pass.pressed.connect(_on_auto_pass_pressed)
	_window.add_child(_auto_pass)


func _auto_pass_text() -> String:
	return _box_text(_is_auto_passing, AUTO_PASS)


## The settings page's Auto-tapping box, under Auto-pass.
func _add_auto_tap(window_width: float) -> void:
	_auto_tap = _button(_box_text(_is_auto_tapping, AUTO_TAP), 19)
	_auto_tap.position = Vector2(60, EncounterLayout.PAUSE_HEADING + EncounterLayout.PAUSE_ROW * 3.0)
	_auto_tap.size = Vector2(window_width - 120, EncounterLayout.PAUSE_ROW - 12)
	_shade(_auto_tap)
	_auto_tap.pressed.connect(_on_auto_tap_pressed)
	_window.add_child(_auto_tap)


## The settings page's Share Run Logs box, under Auto-tapping.
func _add_share_box(window_width: float) -> void:
	_share_box = _button(_box_text(_is_sharing, SHARE_LOGS), 19)
	_share_box.position = Vector2(60, EncounterLayout.PAUSE_HEADING + EncounterLayout.PAUSE_ROW * 4.0)
	_share_box.size = Vector2(window_width - 120, EncounterLayout.PAUSE_ROW - 12)
	_shade(_share_box)
	_share_box.pressed.connect(func() -> void:
		show_share_logs(not _is_sharing)
		share_logs_chosen.emit(_is_sharing))
	_window.add_child(_share_box)


## The Run Seed, muted, in the row under the first page's [param button_count] buttons.
func _add_run_seed(window_width: float, button_count: int) -> void:
	_run_seed_label = Label.new()
	_run_seed_label.text = RUN_SEED % _run_seed
	_run_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_run_seed_label.add_theme_font_size_override("font_size", RUN_SEED_SIZE)
	_run_seed_label.add_theme_color_override("font_color", CreditsScreen.MUTED)
	_run_seed_label.position = Vector2(20, EncounterLayout.PAUSE_HEADING + button_count * EncounterLayout.PAUSE_ROW)
	_run_seed_label.size = Vector2(window_width - 40, EncounterLayout.PAUSE_ROW - 12)
	_window.add_child(_run_seed_label)


func _on_auto_tap_pressed() -> void:
	show_auto_tap(not _is_auto_tapping)
	auto_tap_chosen.emit(_is_auto_tapping)


static func _box_text(is_on: bool, text: String) -> String:
	return ("☑" if is_on else "☐") + "  " + text


func _on_auto_pass_pressed() -> void:
	show_auto_pass(not _is_auto_passing)
	auto_pass_chosen.emit(_is_auto_passing)


func _mark_speed(made: Button, is_chosen: bool) -> void:
	made.get_node(RING).visible = is_chosen


func _on_speed_pressed(speed: GameSpeed.Speed) -> void:
	show_game_speed(speed)
	speed_chosen.emit(speed)


func _button(text: String, font_size: int = 21) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.add_theme_font_size_override("font_size", font_size)
	if [RESUME, CONCEDE, SETTINGS, QUIT, BACK, QUIT_NOW, CONTROLS, RESET_KEYS, ABANDON, ABANDON_NOW, OPEN_LOGS].has(text):
		made.pressed.connect(_on_pressed.bind(text))
	return made


## The gold ring round [param made], shaped as the plate it is drawn with. Painted once for
## each plate.
static func _chosen_ring_of(made: Button) -> StyleBoxTexture:
	var plate: StyleBoxTexture = made.get_theme_stylebox("normal") as StyleBoxTexture
	var key: int = plate.get_instance_id()
	if not _rings.has(key):
		_rings[key] = DitherShading.ring_round(plate, RING_WIDTH, CHOSEN)
	return _rings[key]


## Dither Shades [param made], its size already set, as the Spoils screen's buttons are,
## and in the Inspector's gray while it cannot be pressed.
static func _shade(made: Button) -> void:
	ButtonShading.shade(made, WindowLook.BUTTON, Inspector.palette().button_disabled)


func _on_pressed(text: String) -> void:
	if text == RESUME:
		resume_pressed.emit()
	elif text == BACK and _page == Page.CONTROLS:
		_show_page(Page.SETTINGS)
	elif text == CONTROLS:
		_show_page(Page.CONTROLS)
	elif text == RESET_KEYS:
		key_bindings.reset()
		_waiting = KeyBindings.NOTHING
		_show_page(Page.CONTROLS)
		keys_changed.emit()
	elif text == BACK:
		_show_page(Page.MENU)
	elif text == QUIT and asks_before_quitting:
		_show_page(Page.QUIT)
	elif text == QUIT:
		quit_confirmed.emit()
	elif text == ABANDON:
		_show_page(Page.ABANDON)
	elif text == ABANDON_NOW:
		abandon_confirmed.emit()
	elif text == OPEN_LOGS:
		open_logs_pressed.emit()
	elif text == SETTINGS:
		_show_page(Page.SETTINGS)
	elif text == QUIT_NOW:
		quit_confirmed.emit()
	elif text == CONCEDE and _page == Page.MENU:
		_show_page(Page.CONCEDE)
	elif text == CONCEDE:
		concede_confirmed.emit()
