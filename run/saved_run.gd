class_name SavedRun
extends RefCounted
## A run saved as a snapshot (ADR 0074): everything the Run holds, the Screen it was saved
## on and where the Deckbox's Close led from there, in a JSON file that names its format and
## the build that wrote it. A build loads only its own format: there is no migration while
## the format still changes from one playtest build to the next. Content is named by its
## path, so a change to Content applies to a loaded run.

## Where the game keeps its saved run. Tests use another.
const PATH: String = "user://saves/run.json"
## Bump it whenever a change would make an older snapshot load wrongly. 2: the Armor held
## and Worn (milestone 23). 3: the Potions held (milestone 24). 4: the stock of the Store the
## Hero stands on (milestone 24).
const FORMAT: int = 4
## The project setting that names the build's version (milestone 20).
const VERSION_SETTING: String = "application/config/version"

var run: Run = null
## The Screen the run was saved on, which Continue opens.
var screen: RunFlow.Screen = RunFlow.Screen.STAGE_MAP
## Where the Deckbox's Close led when it was saved.
var back_from_deckbox: RunFlow.Screen = RunFlow.Screen.STAGE_MAP


## [param saved_run] as plain data, saved on [param screen], with the Deckbox's Close leading
## to [param back].
static func data_of(saved_run: Run, screen_saved: RunFlow.Screen, back: RunFlow.Screen) -> Dictionary:
	return {
		"format": FORMAT,
		"build": build(),
		"screen": RunFlow.Screen.keys()[screen_saved],
		"back_from_deckbox": RunFlow.Screen.keys()[back],
		"run": saved_run.to_data(),
	}


## The snapshot [param data] holds, which must be of this build's format (is_current()).
static func from_data(data: Dictionary) -> SavedRun:
	var made: SavedRun = SavedRun.new()
	made.run = Run.from_data(data["run"])
	made.screen = RunFlow.Screen.get(str(data.get("screen", "")), RunFlow.Screen.STAGE_MAP) as RunFlow.Screen
	made.back_from_deckbox = RunFlow.Screen.get(
		str(data.get("back_from_deckbox", "")), RunFlow.Screen.STAGE_MAP) as RunFlow.Screen
	return made


## Whether [param data] is a snapshot of this build's format, which can be loaded.
static func is_current(data: Dictionary) -> bool:
	return data.has("run") and typeof(data.get("format")) in [TYPE_INT, TYPE_FLOAT] and int(data["format"]) == FORMAT


## The version of the build that wrote [param data], or "" if it does not say.
static func build_of(data: Dictionary) -> String:
	return str(data.get("build", ""))


## This build's version, as the main menu shows it.
static func build() -> String:
	return str(ProjectSettings.get_setting(VERSION_SETTING, ""))


## Writes [param data] to [param path], whole or not at all: it is written beside the file
## first and then put in its place, so a game that stops while saving keeps the last save.
## Returns whether it was saved.
static func write(data: Dictionary, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var writing: String = path + ".writing"
	var file: FileAccess = FileAccess.open(writing, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t", false, true))
	file.close()
	return DirAccess.rename_absolute(writing, path) == OK


## The snapshot at [param path] as plain data, or an empty Dictionary when there is none or
## it cannot be read. It is not checked here: ask is_current() before loading it.
static func read(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


static func exists(path: String) -> bool:
	return path != "" and FileAccess.file_exists(path)


static func delete(path: String) -> void:
	if exists(path):
		DirAccess.remove_absolute(path)


## The path Content [param resource] is saved by. A resource made in code has none and
## cannot be saved.
static func path_of(resource: Resource) -> String:
	assert(resource.resource_path != "", "Only Content can be saved, and %s has no file." % resource)
	return resource.resource_path


## The paths of [param resources], in order.
static func paths_of(resources: Array) -> Array[String]:
	var found: Array[String] = []
	for resource: Resource in resources:
		found.append(path_of(resource))
	return found
