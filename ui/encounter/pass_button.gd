class_name PassButton
extends Button
## The Pass Button (game glossary): at the right end of the hand's strip, opposite the Info
## Panel and as wide, always there, in the Inspector's gray inside a steel frame (game ADR
## 0066). It reads what it does in large type with the key that presses it under it,
## smaller and dimmer: "Pass Priority" over "SPACE". With priority it passes; while a combat
## decision, an order of triggers or a choice of cards is being made it confirms that
## instead; while a question's answer is selected in the Info Panel it reads and gives that
## answer; at any other time it cannot be pressed, and is gray and blank. A choice still
## being made keeps its words, dimmed ("Confirm discard"). Whenever it goes from one that
## cannot be pressed to one that can, its border flashes white once, as the Info Panel's
## does. Words with a mana symbol, as "Pay {2}", are drawn with it. Its own text is left
## empty: its two lines are drawn over it.

const PASS: String = "Pass Priority"
const WORDS_FONT: int = 26
const KEY_FONT: int = 16
## How far the key's line is dimmed against the words.
const KEY_DIM: float = 0.6
const WORDS_HEIGHT: float = 40.0
const KEY_HEIGHT: float = 24.0
const FLASH_TIME: float = InfoPanel.FLASH_TIME

var _key_label: String = "SPACE"
var _is_confirming: bool = false
var _confirm_text: String = ""
## Whether the key presses it while it confirms.
var _has_key: bool = true
var _framed_for: Vector2 = Vector2.ZERO
## What it reads, as written, braces and all.
var _shown: String = ""
var _words: SymbolLabel
var _key: Label
var _flash: Panel = null
var _flash_count: int = 0
## Whether it could be pressed when last looked at, a frame ago: a redraw may turn it off
## and on again, and only what it settles on counts.
var _was_pressable: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	disabled = true
	_words = SymbolLabel.new()
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.set_font_size(WORDS_FONT + UiText.RAISE)
	_words.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_words)
	_key = Label.new()
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.add_theme_font_size_override("font_size", KEY_FONT + UiText.RAISE)
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_key)
	_show(PASS)


## Puts the button in [param box]. It is framed once, and again only for another size.
func place(box: Rect2) -> void:
	position = box.position
	size = box.size
	if box.size != _framed_for:
		_framed_for = box.size
		SteelFrame.apply(self, Inspector.palette().button)
		if _flash != null:
			remove_child(_flash)
			_flash.queue_free()
		_flash = CardShapes.outline(Vector2(box.size.x, SteelFrame.face_height(box.size.y)), 4, SteelFrame.RING, Color.WHITE)
		_flash.modulate.a = 0.0
		add_child(_flash)
	_place_lines()


## Names [param key_label] as the key that passes.
func show_key(key_label: String) -> void:
	_key_label = key_label
	_show(_shown)


## It passes priority, and can be pressed only when [param can_pass]. When it cannot, it is
## blank.
func show_pass(can_pass: bool) -> void:
	_is_confirming = false
	_has_key = can_pass
	disabled = not can_pass
	_show(PASS if can_pass else "")


## Flashes the border once when it has become one that can be pressed.
func _process(_delta: float) -> void:
	var is_pressable: bool = not disabled
	if is_pressable and not _was_pressable and _flash != null:
		_flash_count += 1
		_flash.modulate.a = 1.0
		create_tween().tween_property(_flash, "modulate:a", 0.0, FLASH_TIME)
	_was_pressable = is_pressable


## How many times the border has flashed for becoming one that can be pressed.
func flash_count() -> int:
	return _flash_count


## It confirms a choice instead: it reads [param confirm_text] with its key under it, or the
## text alone when no key presses it ([param has_key] off), and can be pressed only when
## [param is_complete].
func show_confirm(confirm_text: String, is_complete: bool, has_key: bool = true) -> void:
	_is_confirming = true
	_confirm_text = confirm_text
	_has_key = has_key
	disabled = not is_complete
	_show(confirm_text)


## What it reads, as written: "Attack with 2", or "Pay {2}" with its symbol in braces.
func shown_text() -> String:
	return _shown


## The key named under its words, or "" when no key presses it.
func key_text() -> String:
	return _key.text if _key.visible else ""


## The line that draws its words.
func symbol_line() -> SymbolLabel:
	return _words


## The line that names its key.
func key_line() -> Label:
	return _key


func _show(shown: String) -> void:
	var color: Color = ButtonShading.DISABLED_TEXT if disabled else Color.WHITE
	var is_new: bool = shown != _shown or _words.get_meta("color", Color.TRANSPARENT) != color
	_shown = shown
	if is_new:
		_words.set_meta("color", color)
		_words.write_in(shown, color)
	_key.text = _key_label
	_key.visible = _has_key
	_key.add_theme_color_override("font_color", Color(color, color.a * KEY_DIM))
	_place_lines()


## Centers the two lines on the button's face, above its lip, or the words alone.
func _place_lines() -> void:
	var middle: float = SteelFrame.face_height(size.y) / 2.0
	_words.size = Vector2(size.x, WORDS_HEIGHT)
	_words.position = Vector2(0, middle - (32.0 if _has_key else 20.0))
	_key.size = Vector2(size.x, KEY_HEIGHT)
	_key.position = Vector2(0, middle + 10.0)
