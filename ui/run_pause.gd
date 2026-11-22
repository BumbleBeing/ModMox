class_name RunPause
extends Control
## The Pause Menu on a run's screens away from an encounter (milestone 21): the Stage Map,
## the Deckbox and the Spoils screen each lay one over everything with over(). Escape opens
## and closes it. It has no Concede, since there is nothing to concede, and Quit goes at once:
## the run is saved where it was left. Abandon Run asks once more, then ends the run. Its
## settings are the game's, read from and kept at settings_path, which is empty in a test
## unless the test gives it a file of its own.

## How it opens the main menu; the screen hands it its own navigate.
var navigate: Callable = func(_scene: String) -> void: pass
## Where the game's settings are kept, or "" to keep none.
var settings_path: String = ""
## Whether this is a playtest build, whose settings page has the Share Run Logs box. Tests
## replace it.
var is_playtest: bool = OS.has_feature(MainMenu.PLAYTEST_FEATURE)
## What Open Run Logs folder does. Tests replace it.
var open_folder: Callable = func() -> void: RunLogShare.open_folder()

var _menu: PauseMenu = null
var _settings: GameSettings = GameSettings.new()


func _init() -> void:
	name = "RunPause"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A Pause Menu laid over everything on [param screen], leaving through [param leave] and
## keeping its settings at [param path].
static func over(screen: Control, leave: Callable, path: String) -> RunPause:
	var made: RunPause = RunPause.new()
	made.navigate = leave
	made.settings_path = path
	screen.add_child(made)
	return made


func _ready() -> void:
	_settings = GameSettings.load_from(settings_path)
	_menu = PauseMenu.new()
	_menu.has_concede = false
	_menu.asks_before_quitting = false
	_menu.has_share_box = is_playtest
	if RunFlow.run != null:
		_menu.show_run(RunFlow.run.run_seed)
	_menu.key_bindings = _settings.key_bindings
	_menu.show_game_speed(_settings.game_speed)
	_menu.show_auto_pass(_settings.is_auto_passing)
	_menu.show_auto_tap(_settings.is_auto_tapping)
	_menu.show_share_logs(_settings.is_sharing_run_logs)
	_menu.resume_pressed.connect(close)
	_menu.quit_confirmed.connect(func() -> void: navigate.call(Screens.scene(RunFlow.quit())))
	_menu.abandon_confirmed.connect(func() -> void: navigate.call(Screens.scene(RunFlow.abandon())))
	_menu.speed_chosen.connect(func(speed: GameSpeed.Speed) -> void:
		_settings.game_speed = speed
		_keep())
	_menu.auto_pass_chosen.connect(func(is_on: bool) -> void:
		_settings.is_auto_passing = is_on
		_menu.show_auto_pass(is_on)
		_keep())
	_menu.auto_tap_chosen.connect(func(is_on: bool) -> void:
		_settings.is_auto_tapping = is_on
		_menu.show_auto_tap(is_on)
		_keep())
	_menu.share_logs_chosen.connect(func(is_on: bool) -> void:
		_settings.has_answered_sharing = true
		_settings.is_sharing_run_logs = is_on
		_keep())
	_menu.keys_changed.connect(_keep)
	_menu.open_logs_pressed.connect(func() -> void: open_folder.call())
	add_child(_menu)


func menu() -> PauseMenu:
	return _menu


func is_open() -> bool:
	return _menu.is_open()


## Opens on its first page, in the middle of the screen.
func open() -> void:
	_menu.open(get_viewport_rect(), false)


func close() -> void:
	_menu.close()


## Does what pressing [param keycode] does: a row of the Controls Page waiting for a key
## takes it, and otherwise Escape opens or closes the menu.
func press_key(keycode: Key) -> void:
	if is_open() and _menu.is_waiting_for_key():
		_menu.take_key(keycode)
	elif keycode == KEY_ESCAPE:
		if is_open():
			close()
		else:
			open()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		press_key(key.keycode)
		get_viewport().set_input_as_handled()


func _keep() -> void:
	_settings.save_to(settings_path)
