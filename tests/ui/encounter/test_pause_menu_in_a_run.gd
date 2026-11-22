extends GutTest
## Milestone 21: the Pause Menu in a run. It adds Abandon Run under Quit to main menu, which
## asks once more, and shows the Run Seed at its foot. On a run's screens away from an
## encounter it has no Concede and Quit goes at once; in a run's encounter Quit says the
## encounter will start over. Its settings page has the Open Run Logs folder button, and the
## Share Run Logs box in a playtest build.

const FIELD: Rect2 = Rect2(0, 0, 1920, 1080)

var _events: Array[String] = []


func before_each() -> void:
	_events.clear()


func after_each() -> void:
	await wait_process_frames(2)


## S11: in a run, Abandon Run is under Quit to main menu, and the Run Seed is at the foot.
func test_in_a_run_abandon_run_is_under_quit_and_the_run_seed_at_the_foot() -> void:
	var menu: PauseMenu = _menu(true, true)

	menu.open(FIELD, true)

	var abandon: Button = menu.button(PauseMenu.ABANDON)
	assert_not_null(abandon)
	assert_gt(abandon.position.y, menu.button(PauseMenu.QUIT).position.y)
	assert_not_null(menu.button(PauseMenu.CONCEDE), "An encounter of a run can be conceded.")
	var seed_label: Label = menu.run_seed_label()
	assert_eq(seed_label.text, "Run Seed 2718281828")
	assert_eq(seed_label.get_theme_color("font_color"), CreditsScreen.MUTED)
	assert_gt(seed_label.position.y, abandon.position.y)
	assert_true(Rect2(Vector2.ZERO, menu.window_rect().size).encloses(Rect2(seed_label.position, seed_label.size)))


## S11: outside a run there is no Abandon Run and no Run Seed.
func test_outside_a_run_there_is_no_abandon_and_no_run_seed() -> void:
	var menu: PauseMenu = _menu(false, true)

	menu.open(FIELD, true)

	assert_null(menu.button(PauseMenu.ABANDON))
	assert_null(menu.run_seed_label())
	assert_eq(menu.window_rect(), EncounterLayout.pause_rect(4, FIELD))


## S11: Abandon Run asks once more, and Back returns to the first page.
func test_abandon_run_asks_once_more() -> void:
	var menu: PauseMenu = _menu(true, false)
	menu.open(FIELD, false)

	menu.button(PauseMenu.ABANDON).pressed.emit()

	assert_eq(menu.page(), PauseMenu.Page.ABANDON)
	assert_eq(menu.heading_text(), "Abandon this run?\nIt can't be continued.")
	assert_eq(_events, [] as Array[String])
	menu.button(PauseMenu.BACK).pressed.emit()
	assert_eq(menu.page(), PauseMenu.Page.MENU)
	menu.button(PauseMenu.ABANDON).pressed.emit()
	menu.button(PauseMenu.ABANDON_NOW).pressed.emit()
	assert_eq(_events, ["abandon"] as Array[String])


## S11: on a run's screens there is no Concede, and Quit goes at once: nothing is lost.
func test_on_a_runs_screens_there_is_no_concede_and_quit_goes_at_once() -> void:
	var menu: PauseMenu = _menu(true, false)
	menu.open(FIELD, false)

	assert_null(menu.button(PauseMenu.CONCEDE))
	assert_lt(menu.button(PauseMenu.RESUME).position.y, menu.button(PauseMenu.SETTINGS).position.y)
	menu.button(PauseMenu.QUIT).pressed.emit()

	assert_eq(_events, ["quit"] as Array[String])


## S11: in a run's encounter, Quit asks once more and says the encounter will start over.
func test_in_a_runs_encounter_quit_says_the_encounter_will_start_over() -> void:
	var menu: PauseMenu = _menu(true, true)
	menu.open(FIELD, true)

	menu.button(PauseMenu.QUIT).pressed.emit()

	assert_eq(menu.heading_text(), "Quit to the main menu?\nThis encounter will start over when you continue.")
	assert_eq(_events, [] as Array[String])
	menu.button(PauseMenu.QUIT_NOW).pressed.emit()
	assert_eq(_events, ["quit"] as Array[String])


## Outside a run, Quit keeps its words.
func test_outside_a_run_quit_keeps_its_words() -> void:
	var menu: PauseMenu = _menu(false, true)
	menu.open(FIELD, true)

	menu.button(PauseMenu.QUIT).pressed.emit()

	assert_eq(menu.heading_text(), "Quit to the main menu?\nThis encounter will be lost.")


## S10: the settings page has Open Run Logs folder above Back.
func test_the_settings_page_has_open_run_logs_folder() -> void:
	var menu: PauseMenu = _menu(true, false)
	menu.open(FIELD, false)

	menu.button(PauseMenu.SETTINGS).pressed.emit()
	var folder: Button = menu.button(PauseMenu.OPEN_LOGS)
	folder.pressed.emit()

	assert_eq(folder.text, "Open Run Logs folder")
	assert_lt(folder.position.y, menu.button(PauseMenu.BACK).position.y)
	assert_gt(folder.position.y, menu.button(PauseMenu.CONTROLS).position.y)
	assert_eq(_events, ["open logs"] as Array[String])
	assert_null(menu.share_box(), "Only a playtest build shares Run Logs.")


## S10: in a playtest build the settings page has the Share Run Logs box under Auto-tapping,
## which shows what it is told and says when it is pressed.
func test_a_playtest_settings_page_has_the_share_run_logs_box() -> void:
	var menu: PauseMenu = _menu(true, false)
	menu.has_share_box = true
	var chosen: Array[bool] = []
	menu.share_logs_chosen.connect(func(is_on: bool) -> void: chosen.append(is_on))
	menu.show_share_logs(true)
	menu.open(FIELD, false)

	menu.button(PauseMenu.SETTINGS).pressed.emit()
	var box: Button = menu.share_box()

	assert_eq(box.text, "☑  Share Run Logs")
	assert_gt(box.position.y, menu.auto_tap_button().position.y)
	assert_lt(box.position.y, menu.button(PauseMenu.CONTROLS).position.y)
	assert_true(Rect2(Vector2.ZERO, menu.window_rect().size).encloses(Rect2(box.position, box.size)))
	box.pressed.emit()
	assert_eq(chosen, [false] as Array[bool])
	assert_eq(menu.share_box().text, "☐  Share Run Logs")
	assert_true(Rect2(Vector2.ZERO, menu.window_rect().size).encloses(
		Rect2(menu.button(PauseMenu.BACK).position, menu.button(PauseMenu.BACK).size)))


func _menu(is_in_run: bool, is_in_encounter: bool) -> PauseMenu:
	var menu: PauseMenu = PauseMenu.new()
	if is_in_run:
		menu.show_run(2718281828)
	menu.has_concede = is_in_encounter
	menu.asks_before_quitting = is_in_encounter
	add_child_autofree(menu)
	menu.quit_confirmed.connect(func() -> void: _events.append("quit"))
	menu.abandon_confirmed.connect(func() -> void: _events.append("abandon"))
	menu.open_logs_pressed.connect(func() -> void: _events.append("open logs"))
	return menu
