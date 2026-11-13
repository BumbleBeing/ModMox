extends GutTest
## Game Settings: what the player has chosen, kept in a file between runs (13d-2).

const PATH: String = "user://test_game_settings.cfg"


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()


func test_the_games_own_file_is_in_the_players_folder() -> void:
	assert_eq(GameSettings.PATH, "user://settings.cfg")


func test_with_no_file_the_speed_is_normal() -> void:
	assert_eq(GameSettings.load_from(PATH).game_speed, GameSpeed.Speed.NORMAL)


func test_a_saved_speed_is_read_back() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.game_speed = GameSpeed.Speed.FAST

	assert_true(settings.save_to(PATH))

	assert_eq(GameSettings.load_from(PATH).game_speed, GameSpeed.Speed.FAST)


func test_a_file_that_cannot_be_read_gives_normal() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[game\nspeed = = =")
	file.close()

	assert_eq(GameSettings.load_from(PATH).game_speed, GameSpeed.Speed.NORMAL)


func test_a_speed_the_game_does_not_know_gives_normal() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[game]\nspeed=\"Ludicrous\"\n")
	file.close()

	assert_eq(GameSettings.load_from(PATH).game_speed, GameSpeed.Speed.NORMAL)


func test_with_no_file_auto_pass_is_on() -> void:
	assert_true(GameSettings.load_from(PATH).is_auto_passing)


func test_auto_pass_turned_off_is_read_back_with_the_speed() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.game_speed = GameSpeed.Speed.SLOW
	settings.is_auto_passing = false

	assert_true(settings.save_to(PATH))

	var read: GameSettings = GameSettings.load_from(PATH)
	assert_false(read.is_auto_passing)
	assert_eq(read.game_speed, GameSpeed.Speed.SLOW)


func test_auto_tap_is_on_with_no_file_and_is_read_back_when_turned_off() -> void:
	assert_true(GameSettings.load_from(PATH).is_auto_tapping)
	var settings: GameSettings = GameSettings.new()
	settings.is_auto_tapping = false

	assert_true(settings.save_to(PATH))
	var read: GameSettings = GameSettings.load_from(PATH)

	assert_false(read.is_auto_tapping)
	assert_true(read.is_auto_passing, "Each setting is kept on its own.")
	settings.is_auto_tapping = true
	settings.is_auto_passing = false
	settings.save_to(PATH)
	assert_true(GameSettings.load_from(PATH).is_auto_tapping)


func test_a_file_from_before_auto_tap_was_kept_gives_it_on() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[game]\nspeed=\"fast\"\nauto_pass=false\n")
	file.close()

	assert_true(GameSettings.load_from(PATH).is_auto_tapping)


func test_a_file_from_before_auto_pass_was_kept_gives_it_on() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[game]\nspeed=\"Fast\"\n")
	file.close()

	assert_true(GameSettings.load_from(PATH).is_auto_passing)
	assert_eq(GameSettings.load_from(PATH).game_speed, GameSpeed.Speed.FAST)


func test_auto_pass_the_game_cannot_read_is_on() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[game]\nauto_pass=perhaps\n")
	file.close()

	assert_true(GameSettings.load_from(PATH).is_auto_passing)


func test_with_nowhere_to_save_nothing_is_saved() -> void:
	assert_false(GameSettings.new().save_to(""))


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
