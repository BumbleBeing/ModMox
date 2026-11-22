extends GutTest
## Milestone 21: the main menu and a saved run. Continue heads the menu while a run of this
## build's format is saved and takes it up where it was saved; starting a new run asks before
## replacing it; a saved run of another format is refused with a notice and deleted. A
## playtest build asks once, on its first launch, whether to share Run Logs.

const FOLDER: String = "user://test_main_menu_saved_run/"
const SAVE: String = FOLDER + "run.json"
const SETTINGS: String = FOLDER + "settings.cfg"
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"
const OPT_IN_BODY: String = "When a run ends, ModMox can send its Run Log, a record of every choice made in the run, to the developer's Discord to help improve the game. Nothing else is sent, and a copy is always kept on your computer. You can change this in Settings."

var _went_to: Array[String] = []


func before_each() -> void:
	_went_to.clear()
	DirAccess.make_dir_recursive_absolute(FOLDER)
	RunFlow.clear()


func after_each() -> void:
	RunFlow.clear()
	RunFlow.use_storage("", "")
	RunFlow.run_ended = Callable()
	# Start new run writes a Run Log into the folder's logs/.
	for folder: String in [FOLDER + "logs/", FOLDER]:
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder + file)
		DirAccess.remove_absolute(folder)
	await wait_process_frames(2)


## The game's own menu keeps its runs, logs and settings in the game's own files.
func test_the_games_menu_keeps_its_runs_in_the_games_files() -> void:
	var menu: MainMenu = (load(Screens.MENU) as PackedScene).instantiate() as MainMenu

	assert_eq(menu.save_path, SavedRun.PATH)
	assert_eq(menu.log_folder, RunLog.FOLDER)
	assert_eq(menu.settings_path, GameSettings.PATH)
	menu.free()


## The menu hands RunFlow where runs are saved and logged, and what shares a log at a run's
## end.
func test_the_menu_tells_runflow_where_runs_are_kept() -> void:
	_menu()

	assert_eq(RunFlow.save_path, SAVE)
	assert_eq(RunFlow.log_folder, FOLDER + "logs/")
	assert_true(RunFlow.run_ended.is_valid())


## S6: with no saved run there is no Continue.
func test_with_no_saved_run_there_is_no_continue() -> void:
	var menu: MainMenu = _menu()

	assert_null(menu.button(MainMenu.CONTINUE))


## S6: with a saved run Continue heads the menu, and takes the run up on the Screen it was
## saved on.
func test_continue_heads_the_menu_and_takes_the_run_up() -> void:
	_save_a_run()

	var menu: MainMenu = _menu()
	var continuing: Button = menu.button(MainMenu.CONTINUE)

	assert_not_null(continuing)
	assert_eq(continuing.get_parent().get_index(), 1, "First under the title.")
	continuing.pressed.emit()
	assert_eq(_went_to, [Screens.STAGE_MAP] as Array[String])
	assert_eq(RunFlow.run.run_seed, 12)


## S6: Start Run (debug) asks before replacing a saved run, and Back keeps it.
func test_starting_a_run_asks_before_replacing_the_saved_one() -> void:
	_save_a_run()
	var menu: MainMenu = _menu()

	menu.button("Start Run (debug)").pressed.emit()

	var dialog: MenuDialog = menu.dialog()
	assert_not_null(dialog)
	assert_eq(dialog.title_text(), "Start a new run?")
	assert_eq(dialog.body_text(), "Your saved run will be lost.")
	assert_eq(_went_to, [] as Array[String])
	dialog.button("Back").pressed.emit()
	assert_null(menu.dialog())
	assert_eq(_went_to, [] as Array[String])
	assert_eq(int(SavedRun.read(SAVE)["run"]["run_seed"]), 12, "The saved run is kept.")


## S6: Start new run replaces the saved run.
func test_start_new_run_replaces_the_saved_one() -> void:
	_save_a_run()
	var menu: MainMenu = _menu()
	menu.button("Start Run (debug)").pressed.emit()

	menu.dialog().button("Start new run").pressed.emit()

	assert_eq(_went_to, [Screens.DECKBOX] as Array[String])
	assert_ne(int(SavedRun.read(SAVE)["run"]["run_seed"]), 12)


## S6: with no saved run, Start Run (debug) starts at once.
func test_with_no_saved_run_start_run_starts_at_once() -> void:
	var menu: MainMenu = _menu()

	menu.button("Start Run (debug)").pressed.emit()

	assert_null(menu.dialog())
	assert_eq(_went_to, [Screens.DECKBOX] as Array[String])


## S4: a saved run of another format is refused with a notice naming both builds, and
## deleted; there is no Continue.
func test_a_saved_run_of_another_format_is_refused_and_deleted() -> void:
	_save_a_run()
	var data: Dictionary = SavedRun.read(SAVE)
	data["format"] = SavedRun.FORMAT - 1
	data["build"] = "0.0.0"
	SavedRun.write(data, SAVE)

	var menu: MainMenu = _menu()

	assert_null(menu.button(MainMenu.CONTINUE))
	assert_false(SavedRun.exists(SAVE))
	var dialog: MenuDialog = menu.dialog()
	assert_eq(dialog.title_text(), "Your saved run can't be continued")
	assert_eq(dialog.body_text(), "It was saved by Demo 0.0.0, and this is Demo %s." % SavedRun.build())
	dialog.button("OK").pressed.emit()
	assert_null(menu.dialog())


## S10: a playtest build asks once, on its first launch, whether to share Run Logs, and
## keeps the answer.
func test_a_playtest_build_asks_once_to_share_run_logs() -> void:
	var menu: MainMenu = _menu(true)

	var dialog: MenuDialog = menu.dialog()
	assert_eq(dialog.title_text(), "Share your Run Logs?")
	assert_eq(dialog.body_text(), OPT_IN_BODY)
	assert_not_null(dialog.button("Don't share"))
	dialog.button("Share").pressed.emit()

	var kept: GameSettings = GameSettings.load_from(SETTINGS)
	assert_true(kept.has_answered_sharing)
	assert_true(kept.is_sharing_run_logs)
	assert_null(_menu(true).dialog(), "It is asked once.")


func test_not_sharing_is_kept_too() -> void:
	var menu: MainMenu = _menu(true)

	menu.dialog().button("Don't share").pressed.emit()

	var kept: GameSettings = GameSettings.load_from(SETTINGS)
	assert_true(kept.has_answered_sharing)
	assert_false(kept.is_sharing_run_logs)


## S10: a developer build never asks.
func test_a_developer_build_never_asks() -> void:
	assert_null(_menu(false).dialog())


## S6: a playtest build offers Continue too.
func test_a_playtest_build_offers_continue() -> void:
	_save_a_run()
	var settings: GameSettings = GameSettings.new()
	settings.has_answered_sharing = true
	settings.save_to(SETTINGS)

	var menu: MainMenu = _menu(true)

	assert_not_null(menu.button(MainMenu.CONTINUE))
	assert_not_null(menu.button("Quit Game"))


## A run saved on the Stage Map with Run Seed 12.
func _save_a_run() -> void:
	RunFlow.use_storage(SAVE, "")
	RunFlow.start(Run.debug(12, load(KITTY_KEEP) as StageDefinition))
	RunFlow.finish_intro()
	RunFlow.quit()
	RunFlow.use_storage("", "")


func _menu(is_playtest: bool = false) -> MainMenu:
	var menu: MainMenu = MainMenu.new()
	menu.navigate = func(scene: String) -> void: _went_to.append(scene)
	menu.quit = func() -> void: pass
	menu.arguments = PackedStringArray()
	menu.is_playtest = is_playtest
	menu.save_path = SAVE
	menu.log_folder = FOLDER + "logs/"
	menu.settings_path = SETTINGS
	add_child_autofree(menu)
	return menu
