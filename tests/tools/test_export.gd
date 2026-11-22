extends GutTest
## Milestone 20: the game exports as its playtesters get it. The export presets, the user
## directory, and the files the presets must carry or leave out.

const PRESETS: String = "res://export_presets.cfg"
## The presets, by name: their platform and where each exports to.
const PLATFORMS: Dictionary[String, String] = {"Linux": "Linux", "Windows Desktop": "Windows Desktop"}
const EXPORT_PATHS: Dictionary[String, String] = {
	"Linux": "build/linux/ModMox.x86_64",
	"Windows Desktop": "build/windows/ModMox.exe",
}
## What every preset carries beside its resources: the files the game reads that are not
## resources.
const CARRIED: Array[String] = ["*.txt", "*.json"]
## What every preset leaves out: everything that is not the game.
const LEFT_OUT: Array[String] = ["tests/*", "prototypes/*", "tools/*", "build/*", "addons/gut/*",
	"addons/modmox_rules/tests/*", "addons/modmox_ai/tests/*", "*.aseprite"]
## The folders LEFT_OUT leaves out, as res:// paths.
const LEFT_OUT_FOLDERS: Array[String] = ["res://tests/", "res://prototypes/", "res://tools/", "res://build/",
	"res://addons/gut/", "res://addons/modmox_rules/tests/", "res://addons/modmox_ai/tests/"]
## Kinds of file Godot does not export as resources: a shipped script that names one needs
## an include filter to carry it.
const NOT_RESOURCES: Array[String] = ["txt", "json", "cfg", "csv", "md", "ini", "yaml", "yml", "xml", "html"]
## The files the game is known to read that are not resources, so the scan is seen to work.
const KNOWN_READS: Array[String] = [
	"res://content/credits/credits.txt",
	"res://content/art/art.json",
	"res://content/art/emblems/art.json",
	"res://ui/sprites/portraits/art.json",
	"res://ui/sprites/portraits/breath.json",
]
## The paths under a left-out folder that a shipped script may name, each with the one
## script that names it: the main menu's developer entries, which a playtest build hides
## (T3).
const DEVELOPER_PATHS: Dictionary[String, String] = {
	"res://tools/card_gallery/card_gallery.tscn": "res://ui/menu/main_menu.gd",
}


## T2: the game keeps its saves, settings and logs in a user directory of its own, named
## ModMox, outside wherever it is installed, so a new build leaves them alone.
func test_the_game_keeps_its_user_files_in_a_directory_of_its_own() -> void:
	assert_true(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
	assert_eq(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""), "ModMox")
	assert_true(OS.get_user_data_dir().ends_with("/ModMox"), OS.get_user_data_dir())


## T4: both presets are as agreed: their platform, x86_64 with the pck embedded, the
## playtest feature, what they carry and leave out, and where they export to.
func test_both_presets_are_as_agreed() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_eq(presets.load(PRESETS), OK, "export_presets.cfg is there.")

	for name: String in PLATFORMS:
		var section: String = _section_of(presets, name)
		assert_ne(section, "", "A preset named %s." % name)
		if section == "":
			continue
		assert_eq(presets.get_value(section, "platform"), PLATFORMS[name], name)
		assert_eq(presets.get_value(section, "export_filter"), "all_resources", name)
		assert_eq(presets.get_value(section, "export_path"), EXPORT_PATHS[name], name)
		assert_has(_list(presets.get_value(section, "custom_features", "")), MainMenu.PLAYTEST_FEATURE, name)
		var carried: Array[String] = _list(presets.get_value(section, "include_filter", ""))
		for pattern: String in CARRIED:
			assert_has(carried, pattern, "%s carries %s." % [name, pattern])
		var left_out: Array[String] = _list(presets.get_value(section, "exclude_filter", ""))
		for pattern: String in LEFT_OUT:
			assert_has(left_out, pattern, "%s leaves out %s." % [name, pattern])
		var options: String = section + ".options"
		assert_eq(presets.get_value(options, "binary_format/embed_pck", false), true, name)
		assert_eq(presets.get_value(options, "binary_format/architecture", ""), "x86_64", name)


## T5: every res:// file a shipped script names is a resource, or matched by an include
## filter, so the export carries what the game reads.
func test_every_file_the_game_names_is_carried() -> void:
	var named: Dictionary[String, String] = _named_paths()
	for known: String in KNOWN_READS:
		assert_has(named, known, "The scan finds %s." % known)

	for path: String in named:
		if not NOT_RESOURCES.has(path.get_extension().to_lower()):
			continue
		var plain: String = path.trim_prefix("res://")
		var is_carried: bool = CARRIED.any(func(pattern: String) -> bool: return plain.matchn(pattern))
		assert_true(is_carried, "%s, named in %s, is carried." % [path, named[path]])


## T7: no shipped script names a path under a folder the export leaves out, but for the
## developer entries a playtest build hides.
func test_no_shipped_script_names_a_left_out_path() -> void:
	var named: Dictionary[String, String] = _named_paths()
	var found: Dictionary[String, String] = {}
	for path: String in named:
		if LEFT_OUT_FOLDERS.any(func(folder: String) -> bool: return path.begins_with(folder)):
			found[path] = named[path]

	assert_eq(found, DEVELOPER_PATHS)


## T7: no shipped script names a class defined under a folder the export leaves out.
func test_no_shipped_script_names_a_left_out_class() -> void:
	var classes: Array[String] = []
	var left_out_scripts: Array[String] = []
	for folder: String in LEFT_OUT_FOLDERS:
		if DirAccess.dir_exists_absolute(folder):
			_collect(folder, left_out_scripts, [])
	var declared: RegEx = RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	for file: String in left_out_scripts:
		for found: RegExMatch in declared.search_all(FileAccess.get_file_as_string(file)):
			classes.append(found.get_string(1))
	assert_gt(classes.size(), 5, "The scan finds the tools' and tests' classes.")

	for file: String in _shipped_scripts():
		var code: String = _without_comments(FileAccess.get_file_as_string(file))
		for name: String in classes:
			var word: RegEx = RegEx.create_from_string("\\b%s\\b" % name)
			assert_null(word.search(code), "%s names %s." % [file, name])


## T8, found in the dry run: an exported game lists a resource as "name.tres.remap", so a
## shipped script that lists a folder for its .tres files must allow for that, or it finds
## nothing there (the deckbuilder sample's Collection came up empty).
func test_every_shipped_folder_listing_allows_for_remapped_resources() -> void:
	var listers: int = 0
	for file: String in _shipped_scripts():
		var code: String = _without_comments(FileAccess.get_file_as_string(file))
		if code.contains("get_files_at(") and code.contains("\".tres\""):
			listers += 1
			assert_string_contains(code, "\".remap\"", "%s lists .tres files." % file)
	assert_gt(listers, 3, "The scan finds the Content loaders.")


## Every res:// path the shipped scripts name, each with a script that names it.
func _named_paths() -> Dictionary[String, String]:
	var named: Dictionary[String, String] = {}
	var literal: RegEx = RegEx.create_from_string("\"(res://[^\"%]+)\"")
	for file: String in _shipped_scripts():
		for found: RegExMatch in literal.search_all(FileAccess.get_file_as_string(file)):
			if not named.has(found.get_string(1)):
				named[found.get_string(1)] = file
	return named


## Every script the export ships: every .gd file but those under the folders it leaves out.
func _shipped_scripts() -> Array[String]:
	var files: Array[String] = []
	_collect("res://", files, LEFT_OUT_FOLDERS)
	assert_gt(files.size(), 100, "The scan finds the game's scripts.")
	return files


func _collect(folder: String, files: Array[String], skipping: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		var inner: String = folder + sub + "/"
		if not sub.begins_with(".") and not skipping.has(inner):
			_collect(inner, files, skipping)
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			files.append(folder + file)


## [param code] with everything from a # to the end of its line taken out, so that a
## comment naming a class does not count.
func _without_comments(code: String) -> String:
	return RegEx.create_from_string("#[^\\n]*").sub(code, "", true)


func _section_of(presets: ConfigFile, name: String) -> String:
	for section: String in presets.get_sections():
		if not section.ends_with(".options") and presets.get_value(section, "name", "") == name:
			return section
	return ""


## A preset's comma-separated list.
func _list(value: Variant) -> Array[String]:
	var made: Array[String] = []
	for part: String in str(value).split(",", false):
		made.append(part.strip_edges())
	return made
