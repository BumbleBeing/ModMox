class_name PassButton
extends Button
## The Pass Button (game glossary): over the Info Panel and as wide, always there, gray and
## shaded (A489). With priority it passes and names the key that does; while a combat
## decision, an order of triggers or a choice of cards is being made it confirms that
## instead; at any other time it cannot be pressed. Whatever it reads, it ends with the key
## that presses it (A495).

const PASS_FORMAT: String = "Pass Priority [%s]"
const CONFIRM_FORMAT: String = "%s [%s]"
const COLOR: Color = Color("#737b8a")
const PASS_FONT: int = 21
const CONFIRM_FONT: int = 19

var _key_label: String = "SPACE"
var _is_confirming: bool = false
var _confirm_text: String = ""
var _shaded_for: Vector2 = Vector2.ZERO


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	text = PASS_FORMAT % _key_label
	disabled = true
	add_theme_font_size_override("font_size", PASS_FONT)


## Puts the button in [param box]. It is shaded once, and again only for another size.
func place(box: Rect2) -> void:
	position = box.position
	size = box.size
	if box.size != _shaded_for:
		_shaded_for = box.size
		ButtonShading.apply(self, COLOR)


## Names [param key_label] as the key that passes.
func show_key(key_label: String) -> void:
	_key_label = key_label
	if _is_confirming:
		_set_text(CONFIRM_FORMAT % [_confirm_text, _key_label])
	else:
		_set_text(PASS_FORMAT % _key_label)


## It passes priority, and can be pressed only when [param can_pass].
func show_pass(can_pass: bool) -> void:
	if _is_confirming:
		_is_confirming = false
		add_theme_font_size_override("font_size", PASS_FONT)
	_set_text(PASS_FORMAT % _key_label)
	disabled = not can_pass


## It confirms a choice instead: it reads [param confirm_text] and its key, and can be
## pressed only when [param is_complete].
func show_confirm(confirm_text: String, is_complete: bool) -> void:
	if not _is_confirming:
		_is_confirming = true
		add_theme_font_size_override("font_size", CONFIRM_FONT)
	_confirm_text = confirm_text
	_set_text(CONFIRM_FORMAT % [confirm_text, _key_label])
	disabled = not is_complete


## Setting a button's text lays it out again, so it is set only when it changes.
func _set_text(shown: String) -> void:
	if text != shown:
		text = shown
