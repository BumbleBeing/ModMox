extends GutTest
## Milestone 21: the Pause Menu on a run's screens away from an encounter: the Stage Map,
## the Deckbox and the Spoils screen. Escape opens and closes it; it has no Concede and shows
## the Run Seed; Quit goes at once, the run kept saved; Abandon Run asks once more and ends
## the run; its settings are the game's.

const FOLDER: String = "user://test_run_pause/"
const SAVE: String = FOLDER + "run.json"
const SETTINGS: String = FOLDER + "settings.cfg"
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"

var _went_to: Array[String] = []


func before_each() -> void:
	_went_to.clear()
	DirAccess.make_dir_recursive_absolute(FOLDER)
	RunFlow.clear()
	RunFlow.use_storage(SAVE, "")
	RunFlow.start(Run.debug(31, load(KITTY_KEEP) as StageDefinition))
	RunFlow.finish_intro()


func after_each() -> void:
	RunFlow.clear()
	RunFlow.use_storage("", "")
	for file: String in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER + file)
	DirAccess.remove_absolute(FOLDER)
	await wait_process_frames(2)


## S11: Escape opens the Pause Menu, with no Concede and the Run Seed at its foot, and closes
## it again.
func test_escape_opens_and_closes_it() -> void:
	var pause: RunPause = _pause()
	assert_false(pause.is_open())

	pause.press_key(KEY_ESCAPE)

	assert_true(pause.is_open())
	assert_null(pause.menu().button(PauseMenu.CONCEDE))
	assert_not_null(pause.menu().button(PauseMenu.ABANDON))
	assert_eq(pause.menu().run_seed_label().text, "Run Seed 31")
	pause.press_key(KEY_ESCAPE)
	assert_false(pause.is_open())


## S11: Quit goes at once to the main menu, and the run stays saved.
func test_quit_goes_to_the_main_menu_with_the_run_saved() -> void:
	var pause: RunPause = _pause()
	pause.press_key(KEY_ESCAPE)

	pause.menu().button(PauseMenu.QUIT).pressed.emit()

	assert_eq(_went_to, [Screens.MENU] as Array[String])
	assert_null(RunFlow.run)
	assert_true(SavedRun.exists(SAVE))
	assert_eq(SavedRun.read(SAVE)["screen"], "STAGE_MAP")


## S11: Abandon Run asks once more, then ends the run: its save is deleted and the main
## menu opens.
func test_abandon_run_asks_once_more_then_ends_the_run() -> void:
	var pause: RunPause = _pause()
	pause.press_key(KEY_ESCAPE)

	pause.menu().button(PauseMenu.ABANDON).pressed.emit()
	assert_eq(_went_to, [] as Array[String])
	pause.menu().button(PauseMenu.ABANDON_NOW).pressed.emit()

	assert_eq(_went_to, [Screens.MENU] as Array[String])
	assert_false(SavedRun.exists(SAVE))
	assert_null(RunFlow.run)


## S11: Resume closes it.
func test_resume_closes_it() -> void:
	var pause: RunPause = _pause()
	pause.press_key(KEY_ESCAPE)

	pause.menu().button(PauseMenu.RESUME).pressed.emit()

	assert_false(pause.is_open())


## Its settings are the game's: what is chosen is kept in the settings file.
func test_its_settings_are_kept() -> void:
	var pause: RunPause = _pause()
	pause.press_key(KEY_ESCAPE)
	pause.menu().button(PauseMenu.SETTINGS).pressed.emit()

	pause.menu().speed_button(GameSpeed.Speed.BLAZING).pressed.emit()
	pause.menu().auto_pass_button().pressed.emit()

	var kept: GameSettings = GameSettings.load_from(SETTINGS)
	assert_eq(kept.game_speed, GameSpeed.Speed.BLAZING)
	assert_false(kept.is_auto_passing)


## S10: in a playtest build its settings page has the Share Run Logs box, kept in the
## settings; Open Run Logs folder opens the folder.
func test_sharing_and_the_run_logs_folder() -> void:
	var opened: Array[bool] = []
	var pause: RunPause = _pause(true)
	pause.open_folder = func() -> void: opened.append(true)
	pause.press_key(KEY_ESCAPE)
	pause.menu().button(PauseMenu.SETTINGS).pressed.emit()

	pause.menu().share_box().pressed.emit()
	pause.menu().button(PauseMenu.OPEN_LOGS).pressed.emit()

	var kept: GameSettings = GameSettings.load_from(SETTINGS)
	assert_true(kept.has_answered_sharing)
	assert_true(kept.is_sharing_run_logs)
	assert_eq(opened, [true] as Array[bool])


## S11: the Stage Map, the Deckbox and the Spoils screen each have one.
func test_each_of_the_runs_screens_has_one() -> void:
	var map: StageMapScreen = StageMapScreen.new()
	map.starts_itself = false
	add_child_autofree(map)
	map.begin(RunFlow.run)
	var deckbox: DeckboxScreen = DeckboxScreen.new()
	deckbox.starts_itself = false
	add_child_autofree(deckbox)
	deckbox.begin(RunFlow.run, null)
	var spoils: SpoilsScreen = SpoilsScreen.new()
	spoils.starts_itself = false
	add_child_autofree(spoils)
	spoils.begin(RunFlow.run)

	for screen: Control in [map, deckbox, spoils]:
		var pause: RunPause = screen.get("run_pause") as RunPause
		assert_not_null(pause, screen.name)
		assert_eq(pause.get_index(), screen.get_child_count() - 1, "It is over everything.")


func _pause(is_playtest: bool = false) -> RunPause:
	var pause: RunPause = RunPause.new()
	pause.navigate = func(scene: String) -> void: _went_to.append(scene)
	pause.settings_path = SETTINGS
	pause.is_playtest = is_playtest
	add_child_autofree(pause)
	return pause
