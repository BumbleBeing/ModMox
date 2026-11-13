extends GutTest
## Game Speed on the Encounter Screen: chosen in the Pause Menu's settings, applied at once
## to the running encounter, and kept for the next one (13d-2).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const PATH: String = "user://test_screen_speed.cfg"

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()
	await wait_process_frames(2)


func test_a_speed_scales_every_wait_move_flight_and_fade_of_a_paced_screen() -> void:
	_make()
	_screen.use_game_pace(_presenter)
	assert_eq(_screen.game_speed(), GameSpeed.Speed.NORMAL)

	assert_eq(_presenter.action_wait_msec, 750, "Normal is one and a half times Pacing's numbers.")

	_screen.set_game_speed(GameSpeed.Speed.BLAZING)

	assert_eq(_screen.game_speed(), GameSpeed.Speed.BLAZING)
	assert_eq(_presenter.action_wait_msec, Pacing.ACTION_MSEC / 2)
	assert_eq(_presenter.mana_wait_msec, Pacing.MANA_MSEC / 2)
	assert_eq(_presenter.step_wait_msec, Pacing.STEP_MSEC / 2)
	assert_almost_eq(_screen.face_motion().seconds, Pacing.MOVE_SECONDS / 2.0, 0.0001)
	assert_almost_eq(_screen.card_flights().seconds, Pacing.FLIGHT_SECONDS / 2.0, 0.0001)
	assert_almost_eq(_screen.pause_menu().ease_seconds, Pacing.EASE_SECONDS / 2.0, 0.0001)
	assert_almost_eq(_screen.opening_overlay().motion().seconds, Pacing.DEAL_SECONDS / 2.0, 0.0001)
	assert_almost_eq(_screen.opening_overlay().motion().gap_seconds, Pacing.DEAL_GAP_SECONDS / 2.0, 0.0001)

	_screen.set_game_speed(GameSpeed.Speed.SLOW)
	assert_eq(_presenter.action_wait_msec, 1000)
	assert_almost_eq(_screen.face_motion().seconds, Pacing.MOVE_SECONDS * 2.0, 0.0001)

	_screen.set_game_speed(GameSpeed.Speed.FAST)
	assert_eq(_presenter.action_wait_msec, Pacing.ACTION_MSEC, "Fast plays at Pacing's own numbers.")
	assert_eq(_presenter.mana_wait_msec, Pacing.MANA_MSEC)
	assert_eq(_presenter.step_wait_msec, Pacing.STEP_MSEC)
	assert_almost_eq(_screen.face_motion().seconds, Pacing.MOVE_SECONDS, 0.0001)
	assert_almost_eq(_screen.card_flights().seconds, Pacing.FLIGHT_SECONDS, 0.0001)
	assert_almost_eq(_screen.pause_menu().ease_seconds, Pacing.EASE_SECONDS, 0.0001)


func test_a_screen_that_is_not_paced_waits_for_nothing_at_any_speed() -> void:
	_make()

	_screen.set_game_speed(GameSpeed.Speed.SLOW)

	assert_eq(_presenter.action_wait_msec, 0)
	assert_eq(_screen.face_motion().seconds, 0.0)
	assert_eq(_screen.card_flights().seconds, 0.0)
	assert_eq(_screen.opening_overlay().motion().seconds, 0.0, "No card of the opening hand is dealt: each is at its place.")


func test_a_speed_chosen_in_the_pause_menu_is_applied_to_the_running_encounter_at_once() -> void:
	_make()
	_screen.use_game_pace(_presenter)
	_begin()
	_screen.set_paused(true)

	_screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	assert_true(_screen.pause_menu().is_speed_chosen(GameSpeed.Speed.NORMAL), "It opens on the speed in use.")
	_screen.pause_menu().speed_button(GameSpeed.Speed.FAST).pressed.emit()

	assert_eq(_screen.game_speed(), GameSpeed.Speed.FAST)
	assert_eq(_presenter.action_wait_msec, Pacing.ACTION_MSEC)
	assert_true(_screen.is_paused(), "The menu stays open.")
	assert_true(_screen.pause_menu().is_speed_chosen(GameSpeed.Speed.FAST))


func test_the_speed_chosen_is_saved_and_the_next_screen_starts_with_it() -> void:
	_make()
	_screen.settings_path = PATH
	_screen.use_game_pace(_presenter)

	_screen.set_game_speed(GameSpeed.Speed.SLOW)

	assert_eq(GameSettings.load_from(PATH).game_speed, GameSpeed.Speed.SLOW)
	var next: EncounterScreen = EncounterScreen.new()
	next.starts_itself = false
	add_child_autofree(next)
	next.settings_path = PATH
	next.load_settings()
	var presenter: EncounterPresenter = EncounterPresenter.new(_setup(), DefaultAnswerAgent.new())
	next.use_game_pace(presenter)
	assert_eq(next.game_speed(), GameSpeed.Speed.SLOW)
	assert_eq(presenter.action_wait_msec, 1000)


func test_auto_pass_turned_off_in_the_pause_menu_applies_once_the_game_resumes_and_is_saved() -> void:
	_make()
	_screen.settings_path = PATH
	_begin()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	assert_eq(_presenter.snapshot().view.step, MmTurn.Step.PRECOMBAT_MAIN, "Auto-pass went by the upkeep.")
	_presenter.answer(_land_index())
	_presenter.wait_until_idle()
	var turn: int = _presenter.snapshot().view.game_turn
	_screen.set_paused(true)
	_screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	assert_eq(_screen.pause_menu().auto_pass_button().text, "☑  Auto-pass")

	_screen.pause_menu().auto_pass_button().pressed.emit()

	assert_false(_presenter.is_auto_passing())
	assert_false(GameSettings.load_from(PATH).is_auto_passing)
	_screen.set_paused(false)
	_presenter.pass_priority()
	_presenter.wait_until_idle()
	assert_eq(_presenter.snapshot().view.game_turn, turn, "The Hero is asked at the very next step.")


func test_turning_auto_pass_on_in_the_pause_menu_passes_nothing_until_the_game_resumes() -> void:
	_make()
	_presenter.set_auto_passing(false)
	_begin()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	assert_eq(_presenter.snapshot().view.step, MmTurn.Step.UPKEEP)
	_screen.set_paused(true)
	_screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	assert_eq(_screen.pause_menu().auto_pass_button().text, "☐  Auto-pass", "It shows the presenter's own.")

	_screen.pause_menu().auto_pass_button().pressed.emit()

	assert_true(_presenter.is_auto_passing())
	assert_eq(_presenter.snapshot().view.step, MmTurn.Step.UPKEEP, "Nothing moves under the Pause Menu.")
	_screen.set_paused(false)
	_presenter.wait_until_idle()
	assert_eq(_presenter.snapshot().view.step, MmTurn.Step.PRECOMBAT_MAIN)


func test_auto_tapping_is_turned_off_and_on_in_the_pause_menu_and_saved() -> void:
	_make()
	_screen.settings_path = PATH
	_screen.load_settings()
	_screen.use_settings(_presenter)
	_begin()
	assert_true(_presenter.is_auto_tapping(), "On unless the player turned it off.")
	_screen.set_paused(true)
	_screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	assert_eq(_screen.pause_menu().auto_tap_button().text, "☑  Auto-tapping")

	_screen.pause_menu().auto_tap_button().pressed.emit()

	assert_false(_presenter.is_auto_tapping())
	assert_false(GameSettings.load_from(PATH).is_auto_tapping)
	assert_true(GameSettings.load_from(PATH).is_auto_passing, "Saving one setting keeps the others.")
	_screen.pause_menu().auto_tap_button().pressed.emit()
	assert_true(_presenter.is_auto_tapping())
	assert_true(GameSettings.load_from(PATH).is_auto_tapping)
	_screen.set_paused(false)


func test_the_pause_menu_shows_the_presenters_own_auto_tap_and_a_saved_one_reaches_the_presenter() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.is_auto_tapping = false
	settings.save_to(PATH)
	_make()
	assert_false(_presenter.is_auto_tapping(), "A presenter pays nothing until it is told to.")
	_presenter.set_auto_tapping(true)
	_screen.settings_path = PATH
	_screen.load_settings()
	_screen.use_settings(_presenter)
	_begin()

	assert_false(_presenter.is_auto_tapping(), "The saved choice reached it.")
	_screen.set_paused(true)
	_screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	assert_eq(_screen.pause_menu().auto_tap_button().text, "☐  Auto-tapping")
	_screen.set_paused(false)


func test_saving_one_setting_keeps_the_other() -> void:
	_make()
	_screen.settings_path = PATH
	_begin()

	_screen.set_auto_passing(false)
	_screen.set_game_speed(GameSpeed.Speed.FAST)

	assert_false(GameSettings.load_from(PATH).is_auto_passing)
	assert_eq(GameSettings.load_from(PATH).game_speed, GameSpeed.Speed.FAST)


func test_a_screen_that_starts_itself_gives_its_presenter_the_saved_auto_pass() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.is_auto_passing = false
	settings.save_to(PATH)
	_make()
	_screen.settings_path = PATH

	_screen.load_settings()
	_screen.use_settings(_presenter)

	assert_false(_presenter.is_auto_passing())


func test_a_screen_made_in_a_test_reads_and_saves_no_settings() -> void:
	_make()

	assert_eq(_screen.settings_path, "", "Only a screen that starts itself uses the player's file.")
	_screen.set_game_speed(GameSpeed.Speed.FAST)
	assert_false(FileAccess.file_exists(PATH))


func _make() -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.set_process(false)
	_screen.size = Vector2(1920, 1080)
	_presenter = EncounterPresenter.new(_setup(), DefaultAnswerAgent.new())


func _begin() -> void:
	_screen.begin(_presenter)
	_presenter.wait_until_idle()


func _land_index() -> int:
	var actions: Array[MmAction] = (_presenter.snapshot().decision as PriorityDecision).actions
	for index: int in actions.size():
		if actions[index] is PlayLandAction:
			return index
	return -1


func _setup() -> MmEncounterSetup:
	return Scenario.setup_with(Scenario.copies(Scenario.basic_land("Forest"), 40), Scenario.copies(Scenario.basic_land("Forest"), 40))


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
