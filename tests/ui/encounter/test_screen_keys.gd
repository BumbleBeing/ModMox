extends GutTest
## Key Bindings on the Encounter Screen are kept in the settings file with the rest (13g).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const PATH: String = "user://test_screen_keys.cfg"

var _screen: EncounterScreen


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()
	await wait_process_frames(2)


func test_a_key_bound_on_the_controls_page_is_saved_and_read_by_the_next_screen() -> void:
	_make()
	_screen.settings_path = PATH
	_screen.load_settings()
	_screen.begin(EncounterPresenter.new(_setup(), DefaultAnswerAgent.new()))
	_screen.press_key(KEY_ESCAPE)
	_screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	_screen.pause_menu().button(PauseMenu.CONTROLS).pressed.emit()
	_screen.pause_menu().key_button(KeyBindings.Action.PASS).pressed.emit()

	_screen.press_key(KEY_ENTER)

	assert_eq(GameSettings.load_from(PATH).key_bindings.key_of(KeyBindings.Action.PASS), KEY_ENTER)
	_make()
	_screen.settings_path = PATH
	_screen.load_settings()
	assert_eq(_screen.key_bindings().key_of(KeyBindings.Action.PASS), KEY_ENTER)
	assert_eq(_screen.pause_menu().key_bindings, _screen.key_bindings(), "The Controls Page shows the ones in use.")

	_screen.begin(EncounterPresenter.new(_setup(), DefaultAnswerAgent.new()))
	_screen.press_key(KEY_ESCAPE)
	_screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	_screen.pause_menu().button(PauseMenu.CONTROLS).pressed.emit()
	_screen.pause_menu().button(PauseMenu.RESET_KEYS).pressed.emit()

	assert_eq(GameSettings.load_from(PATH).key_bindings.key_of(KeyBindings.Action.PASS), KEY_SPACE, "A reset is saved too.")


func test_a_screen_with_no_settings_path_saves_no_keys() -> void:
	_make()
	_screen.begin(EncounterPresenter.new(_setup(), DefaultAnswerAgent.new()))
	_screen.key_bindings().bind(KeyBindings.Action.PASS, KEY_ENTER)

	_screen._on_keys_changed()

	assert_false(FileAccess.file_exists(PATH))
	assert_eq(_screen.settings_path, "")


func _make() -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.set_process(false)
	_screen.size = Vector2(1920, 1080)


func _setup() -> MmEncounterSetup:
	return Scenario.setup_with(Scenario.copies(Scenario.basic_land("Forest"), 40), Scenario.copies(Scenario.basic_land("Forest"), 40))


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
