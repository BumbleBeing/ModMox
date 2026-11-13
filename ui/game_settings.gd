class_name GameSettings
extends RefCounted
## What the player has chosen, kept in a file between runs (13d-2). A file that is missing,
## cannot be read, or says something the game does not know gives the defaults.

## The game's own file. Tests use another.
const PATH: String = "user://settings.cfg"
const SECTION: String = "game"
const SPEED_KEY: String = "speed"
const AUTO_PASS_KEY: String = "auto_pass"
const AUTO_TAP_KEY: String = "auto_tap"

var game_speed: GameSpeed.Speed = GameSpeed.Speed.NORMAL
## Auto-pass (game glossary). On unless the file says "false".
var is_auto_passing: bool = true
## Auto-tap (game glossary). On unless the file says "false".
var is_auto_tapping: bool = true
## The Key Bindings (game glossary). A key the file does not name, or names wrongly, is
## its action's default.
var key_bindings: KeyBindings = KeyBindings.new()


## The settings kept at [param path]. The file is read line by line here, and not as a
## ConfigFile: Godot prints an error for a ConfigFile it cannot parse, and a file the player
## has broken is no error of the game's.
static func load_from(path: String) -> GameSettings:
	var settings: GameSettings = GameSettings.new()
	if path == "" or not FileAccess.file_exists(path):
		return settings
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var parts: PackedStringArray = line.split("=", true, 1)
		if parts.size() != 2:
			continue
		var value: String = parts[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
		if parts[0].strip_edges() == SPEED_KEY:
			settings.game_speed = GameSpeed.named(value)
		elif parts[0].strip_edges() == AUTO_PASS_KEY:
			settings.is_auto_passing = value != "false"
		elif parts[0].strip_edges() == AUTO_TAP_KEY:
			settings.is_auto_tapping = value != "false"
		else:
			for action: KeyBindings.Action in KeyBindings.ACTIONS:
				if parts[0].strip_edges() == KeyBindings.FILE_KEYS[action]:
					settings.key_bindings.bind_named(action, value)
	return settings


## Keeps these settings at [param path]. Returns whether they were saved; with no path
## nothing is.
func save_to(path: String) -> bool:
	if path == "":
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("[%s]\n%s=\"%s\"\n%s=%s\n%s=%s\n" % [
		SECTION, SPEED_KEY, GameSpeed.name_of(game_speed), AUTO_PASS_KEY, "true" if is_auto_passing else "false",
		AUTO_TAP_KEY, "true" if is_auto_tapping else "false",
	])
	for action: KeyBindings.Action in KeyBindings.ACTIONS:
		file.store_string("%s=\"%s\"\n" % [KeyBindings.FILE_KEYS[action], key_bindings.save_name_of(action)])
	file.close()
	return true
