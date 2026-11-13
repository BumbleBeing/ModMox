extends GutTest
## Key Bindings: which key does each of the four actions that have one (13g, ADR 0034).

const PATH: String = "user://test_key_bindings.cfg"
const PASS: KeyBindings.Action = KeyBindings.Action.PASS
const UNDO: KeyBindings.Action = KeyBindings.Action.UNDO
const CANCEL: KeyBindings.Action = KeyBindings.Action.CANCEL
const HOLD: KeyBindings.Action = KeyBindings.Action.HOLD


func before_each() -> void:
	_remove()


func after_each() -> void:
	_remove()


func test_the_defaults_are_space_z_x_and_control() -> void:
	var keys: KeyBindings = KeyBindings.new()

	assert_eq(keys.key_of(PASS), KEY_SPACE)
	assert_eq(keys.key_of(UNDO), KEY_Z)
	assert_eq(keys.key_of(CANCEL), KEY_X)
	assert_eq(keys.key_of(HOLD), KEY_CTRL)
	assert_eq(KeyBindings.ACTIONS.size(), 4)


func test_a_key_does_the_action_it_is_bound_to() -> void:
	var keys: KeyBindings = KeyBindings.new()

	assert_eq(keys.pressed_action(KEY_SPACE), PASS)
	assert_eq(keys.pressed_action(KEY_Z), UNDO)
	assert_eq(keys.pressed_action(KEY_X), CANCEL)
	assert_eq(keys.pressed_action(KEY_Q), KeyBindings.NOTHING)
	assert_eq(keys.pressed_action(KEY_CTRL), KeyBindings.NOTHING, "Holding priority is a key held down, not a press.")


func test_a_rebound_action_answers_to_its_new_key_only() -> void:
	var keys: KeyBindings = KeyBindings.new()

	assert_true(keys.bind(PASS, KEY_ENTER))

	assert_eq(keys.pressed_action(KEY_ENTER), PASS)
	assert_eq(keys.pressed_action(KEY_SPACE), KeyBindings.NOTHING)
	assert_eq(keys.label_of(PASS), "ENTER")


func test_a_modifier_or_an_ordinary_key_can_do_any_action() -> void:
	var keys: KeyBindings = KeyBindings.new()

	assert_true(keys.bind(PASS, KEY_SHIFT))
	assert_true(keys.bind(HOLD, KEY_H))

	assert_eq(keys.pressed_action(KEY_SHIFT), PASS)
	assert_eq(keys.key_of(HOLD), KEY_H)


func test_escape_and_no_key_are_never_bound() -> void:
	var keys: KeyBindings = KeyBindings.new()

	assert_false(keys.bind(PASS, KEY_ESCAPE))
	assert_false(keys.bind(UNDO, KEY_NONE))

	assert_eq(keys.key_of(PASS), KEY_SPACE)
	assert_eq(keys.key_of(UNDO), KEY_Z)


func test_two_actions_may_share_a_key_and_the_first_of_pass_undo_and_cancel_acts() -> void:
	var keys: KeyBindings = KeyBindings.new()
	assert_false(keys.is_shared(PASS))

	keys.bind(UNDO, KEY_SPACE)

	assert_true(keys.is_shared(PASS))
	assert_true(keys.is_shared(UNDO))
	assert_false(keys.is_shared(CANCEL))
	assert_eq(keys.pressed_action(KEY_SPACE), PASS, "Pass comes before Undo.")
	keys.bind(CANCEL, KEY_Z)
	keys.bind(UNDO, KEY_Z)
	assert_eq(keys.pressed_action(KEY_Z), UNDO, "Undo comes before Cancel.")


func test_hold_priority_can_share_a_key_with_a_press() -> void:
	var keys: KeyBindings = KeyBindings.new()

	keys.bind(HOLD, KEY_SPACE)

	assert_true(keys.is_shared(HOLD))
	assert_eq(keys.pressed_action(KEY_SPACE), PASS)
	assert_eq(keys.key_of(HOLD), KEY_SPACE)


func test_reset_puts_every_default_back() -> void:
	var keys: KeyBindings = KeyBindings.new()
	keys.bind(PASS, KEY_ENTER)
	keys.bind(UNDO, KEY_ENTER)

	keys.reset()

	assert_eq(keys.key_of(PASS), KEY_SPACE)
	assert_eq(keys.key_of(UNDO), KEY_Z)
	assert_false(keys.is_shared(PASS))


func test_a_label_is_the_keys_name_in_capitals() -> void:
	var keys: KeyBindings = KeyBindings.new()

	assert_eq(keys.label_of(PASS), "SPACE")
	assert_eq(keys.label_of(UNDO), "Z")
	assert_eq(keys.label_of(HOLD), "CTRL")
	assert_eq(KeyBindings.name_of(PASS), "Pass priority")
	assert_eq(KeyBindings.name_of(HOLD), "Hold priority")


func test_saved_bindings_are_read_back_with_the_other_settings() -> void:
	var settings: GameSettings = GameSettings.new()
	settings.game_speed = GameSpeed.Speed.FAST
	settings.key_bindings.bind(PASS, KEY_ENTER)
	settings.key_bindings.bind(HOLD, KEY_SHIFT)

	assert_true(settings.save_to(PATH))
	var read: GameSettings = GameSettings.load_from(PATH)

	assert_eq(read.key_bindings.key_of(PASS), KEY_ENTER)
	assert_eq(read.key_bindings.key_of(HOLD), KEY_SHIFT)
	assert_eq(read.key_bindings.key_of(UNDO), KEY_Z)
	assert_eq(read.game_speed, GameSpeed.Speed.FAST)


func test_a_key_the_game_does_not_know_or_a_missing_line_gives_the_default() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[game]\nkey_pass=\"Flibber\"\nkey_undo=\"Escape\"\nkey_cancel=\"C\"\n")
	file.close()

	var keys: KeyBindings = GameSettings.load_from(PATH).key_bindings

	assert_eq(keys.key_of(PASS), KEY_SPACE, "No such key.")
	assert_eq(keys.key_of(UNDO), KEY_Z, "Escape is never bound.")
	assert_eq(keys.key_of(CANCEL), KEY_C)
	assert_eq(keys.key_of(HOLD), KEY_CTRL, "No line for it.")


func test_with_no_file_the_keys_are_the_defaults() -> void:
	assert_eq(GameSettings.load_from(PATH).key_bindings.key_of(PASS), KEY_SPACE)
	assert_eq(GameSettings.load_from("").key_bindings.key_of(UNDO), KEY_Z)


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
