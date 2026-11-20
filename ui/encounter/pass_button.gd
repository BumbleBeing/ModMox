class_name PassButton
extends Button
## The Pass Button (game glossary): over the Info Panel and as wide, always there, and
## Dither Shaded in the Inspector's gray (A489). With priority it passes and names the key that does; while a combat
## decision, an order of triggers or a choice of cards is being made it confirms that
## instead; at any other time it cannot be pressed. Whatever it reads, it ends with the key
## that presses it (A495), except Pay for a ward cost or an X, which no key presses (ADR
## 0062, game ADR 0063). Words with a mana symbol, as "Pay {2}", are drawn by a SymbolLabel
## over it, the button's own text left empty.

const PASS_FORMAT: String = "Pass Priority [%s]"
const CONFIRM_FORMAT: String = "%s [%s]"
const PASS_FONT: int = 21
const CONFIRM_FONT: int = 19

var _key_label: String = "SPACE"
var _is_confirming: bool = false
var _confirm_text: String = ""
## Whether the key presses it while it confirms.
var _has_key: bool = true
var _shaded_for: Vector2 = Vector2.ZERO
## What it reads, as written, braces and all.
var _shown: String = ""
var _symbol_line: SymbolLabel


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	text = PASS_FORMAT % _key_label
	disabled = true
	add_theme_font_size_override("font_size", PASS_FONT)
	_shown = text
	_symbol_line = SymbolLabel.new()
	_symbol_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_symbol_line.set_font_size(CONFIRM_FONT)
	_symbol_line.hide()
	add_child(_symbol_line)


## Puts the button in [param box]. It is shaded once, and again only for another size.
func place(box: Rect2) -> void:
	position = box.position
	size = box.size
	_place_symbol_line()
	if box.size != _shaded_for:
		_shaded_for = box.size
		ButtonShading.apply(self, Inspector.palette().button)


## Names [param key_label] as the key that passes.
func show_key(key_label: String) -> void:
	_key_label = key_label
	if _is_confirming:
		_set_text(_confirming_text())
	else:
		_set_text(PASS_FORMAT % _key_label)


## It passes priority, and can be pressed only when [param can_pass].
func show_pass(can_pass: bool) -> void:
	if _is_confirming:
		_is_confirming = false
		add_theme_font_size_override("font_size", PASS_FONT)
	_set_text(PASS_FORMAT % _key_label)
	disabled = not can_pass


## It confirms a choice instead: it reads [param confirm_text] and its key, or the text
## alone when no key presses it ([param has_key] off), and can be pressed only when
## [param is_complete].
func show_confirm(confirm_text: String, is_complete: bool, has_key: bool = true) -> void:
	if not _is_confirming:
		_is_confirming = true
		add_theme_font_size_override("font_size", CONFIRM_FONT)
	_confirm_text = confirm_text
	_has_key = has_key
	_set_text(_confirming_text())
	disabled = not is_complete


func _confirming_text() -> String:
	return CONFIRM_FORMAT % [_confirm_text, _key_label] if _has_key else _confirm_text


## What it reads, as written: "Pay {2}" while its words are drawn with a symbol.
func shown_text() -> String:
	return _shown


## The line that draws words with a mana symbol in them.
func symbol_line() -> SymbolLabel:
	return _symbol_line


## Setting a button's text lays it out again, so it is set only when it changes.
func _set_text(shown: String) -> void:
	if _shown == shown:
		return
	_shown = shown
	var has_symbol: bool = shown.contains("{")
	text = "" if has_symbol else shown
	_symbol_line.visible = has_symbol
	if has_symbol:
		_symbol_line.write(shown)
		_place_symbol_line()


## Centers the symbol line on the button.
func _place_symbol_line() -> void:
	_symbol_line.size = Vector2(size.x, 0)
	var line: float = _symbol_line.get_theme_font("normal_font").get_height(CONFIRM_FONT)
	_symbol_line.position = Vector2(0, (size.y - line) / 2.0)
