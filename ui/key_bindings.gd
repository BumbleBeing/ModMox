class_name KeyBindings
extends RefCounted
## The Key Bindings (game glossary): which key does each action that has one. Any single
## key can be bound to any action, a modifier included, but never Escape, which is the
## Pause Menu's. Two actions may share a key (ADR 0034): a press of a shared key does only
## the first of Pass, Undo and Cancel bound to it, while holding priority is a key held
## down and so goes with any of them.

enum Action { PASS, UNDO, CANCEL, HOLD }

## No action: what a key bound to nothing does.
const NOTHING: int = -1
## Every action, in the order the Controls Page lists them and a shared key chooses by.
const ACTIONS: Array[Action] = [Action.PASS, Action.UNDO, Action.CANCEL, Action.HOLD]
const DEFAULTS: Dictionary[Action, Key] = {
	Action.PASS: KEY_SPACE, Action.UNDO: KEY_Z, Action.CANCEL: KEY_X, Action.HOLD: KEY_CTRL,
}
const NAMES: Dictionary[Action, String] = {
	Action.PASS: "Pass priority", Action.UNDO: "Undo", Action.CANCEL: "Cancel", Action.HOLD: "Hold priority",
}
## What each action's line in the settings file is called.
const FILE_KEYS: Dictionary[Action, String] = {
	Action.PASS: "key_pass", Action.UNDO: "key_undo", Action.CANCEL: "key_cancel", Action.HOLD: "key_hold",
}

var _keys: Dictionary[Action, Key] = DEFAULTS.duplicate()


static func name_of(action: Action) -> String:
	return NAMES[action]


func key_of(action: Action) -> Key:
	return _keys[action]


## Binds [param keycode] to [param action]. Returns false, changing nothing, for Escape or
## no key at all.
func bind(action: Action, keycode: Key) -> bool:
	if keycode == KEY_NONE or keycode == KEY_ESCAPE:
		return false
	_keys[action] = keycode
	return true


## Binds the key named [param key_name], as save_name_of() names it. A name that is no
## key's leaves the binding as it was.
func bind_named(action: Action, key_name: String) -> bool:
	return bind(action, OS.find_keycode_from_string(key_name))


func reset() -> void:
	_keys = DEFAULTS.duplicate()


## What a press of [param keycode] does: the first of Pass, Undo and Cancel bound to it, or
## NOTHING. Holding priority is never a press.
func pressed_action(keycode: Key) -> int:
	for action: Action in ACTIONS:
		if action != Action.HOLD and _keys[action] == keycode:
			return action
	return NOTHING


## Whether another action has the key of [param action].
func is_shared(action: Action) -> bool:
	return _keys.values().count(_keys[action]) > 1


## The key of [param action] as a button names it: "SPACE", "CTRL".
func label_of(action: Action) -> String:
	return save_name_of(action).to_upper()


## The key of [param action] as the settings file keeps it.
func save_name_of(action: Action) -> String:
	return OS.get_keycode_string(_keys[action])
