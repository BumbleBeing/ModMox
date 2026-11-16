extends GutTest
## The run is the game's model and knows nothing of screens (conventions, "Game-side code"):
## nothing in run/ names a class of ui/ or tools/, or a file under them. The GUI reads the
## run and changes it through its methods; RunFlow says which Screen comes next, and the GUI
## alone knows which scene that is.

const RUN: String = "res://run/"
const GUI_FOLDERS: Array[String] = ["res://ui/", "res://tools/"]
const FORBIDDEN_PATHS: Array[String] = ["res://ui/", "res://tools/"]

var _class_name: RegEx = RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")


func test_nothing_in_the_run_names_a_gui_class() -> void:
	var gui_classes: Array[String] = []
	for folder: String in GUI_FOLDERS:
		for file: String in _scripts(folder):
			var found: RegExMatch = _class_name.search(FileAccess.get_file_as_string(file))
			if found != null:
				gui_classes.append(found.get_string(1))
	assert_gt(gui_classes.size(), 20, "The scan found the GUI's classes.")
	assert_true(gui_classes.has("CardLook"))
	var run_files: Array[String] = _scripts(RUN)
	assert_gt(run_files.size(), 10, "The scan found the run's scripts.")
	for file: String in run_files:
		var source: String = FileAccess.get_file_as_string(file)
		for gui_class: String in gui_classes:
			var word: RegEx = RegEx.create_from_string("\\b%s\\b" % gui_class)
			assert_false(word.search(source) != null, "%s names %s." % [file, gui_class])


func test_nothing_in_the_run_names_a_gui_file() -> void:
	for file: String in _scripts(RUN):
		var source: String = FileAccess.get_file_as_string(file)
		for path: String in FORBIDDEN_PATHS:
			assert_false(source.contains(path), "%s names %s." % [file, path])


func _scripts(folder: String) -> Array[String]:
	var files: Array[String] = []
	_collect(folder, files)
	return files


func _collect(folder: String, files: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		_collect(folder + sub + "/", files)
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			files.append(folder + file)
