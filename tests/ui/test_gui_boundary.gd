extends GutTest
## ADR 0021: the Encounter Presenter is the only GUI code that may touch the engine or the
## game state. Everything else draws from snapshots, so it cannot read a game the Villain's
## worker thread is changing, or show the Hero something they may not see.

const FOLDERS: Array[String] = ["res://ui/", "res://tools/"]
const PRESENTER: String = "res://ui/encounter/encounter_presenter.gd"
const FORBIDDEN: Array[String] = ["MmEngine", "MmGameState", "MmEncounterDriver", "game_state(", "simulation_source_for("]


func test_only_the_presenter_mentions_the_engine_or_the_game_state() -> void:
	var files: Array[String] = []
	for folder: String in FOLDERS:
		_collect(folder, files)
	assert_gt(files.size(), 20, "The scan found the GUI's scripts.")
	assert_true(files.has(PRESENTER))
	for file: String in files:
		if file == PRESENTER:
			continue
		var source: String = FileAccess.get_file_as_string(file)
		for word: String in FORBIDDEN:
			assert_false(source.contains(word), "%s mentions %s." % [file, word])


func test_the_presenter_is_where_the_engine_lives() -> void:
	assert_string_contains(FileAccess.get_file_as_string(PRESENTER), "MmEngine.start(")


func _collect(folder: String, files: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		_collect(folder + sub + "/", files)
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			files.append(folder + file)
