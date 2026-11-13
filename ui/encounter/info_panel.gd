class_name InfoPanel
extends Control
## The Info Panel (game glossary): the bordered box by the Hero's hand that says what the
## Hero is being asked and why their last answer was refused, with the Cancel button for a
## cast in progress. While the cursor is over a row of
## the Option Menu, it shows that option in full in place of everything else.

signal cancel_pressed
signal all_attack_pressed
## "Undeclare All" was pressed: the same button, while an attacker is declared (A496).
signal undeclare_all_pressed

const BORDER: Color = Color("#8a93a6")
const DIM: float = 0.45

const CANCEL_FORMAT: String = "Cancel [%s]"
const ALL_ATTACK: String = "Declare All"
const UNDECLARE_ALL: String = "Undeclare All"
## The room the Cancel or "Declare All" button takes at the panel's bottom right.
const BUTTON_ROOM: float = 142.0

var _back: Panel = null
var _border: Panel = null
var _prompt: Label = null
var _error: Label = null
var _option: Label = null
var _cancel: Button = null
## The key that cancels, as the Cancel button names it.
var _cancel_key: String = "X"
var _all_attack: Button = null
var _hint: Label = null
var _pips: Array[TextureRect] = []
var _pip_names: Array[String] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fills [param box] from [param snapshot], with [param error] if the last answer was
## refused and [param hint], a smaller line under the prompt saying how the input is used.
## The panel is dim and empty while nothing is asked of the Hero.
func show_snapshot(snapshot: EncounterSnapshot, error: String, box: Rect2, hint: String = "") -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_pips.clear()
	_cancel = null
	_all_attack = null
	position = box.position
	size = box.size
	# A payment Auto-tap is making asks nothing, but says what is owed and can be canceled.
	var is_asked: bool = (snapshot.decision != null or snapshot.paying != null) and not snapshot.is_over()
	var prompt: InfoPrompt = InfoPrompt.of(snapshot.decision if is_asked else null, snapshot.view,
			snapshot.paying if is_asked else null, snapshot.names)
	_back = CardShapes.rounded(box.size, 8, Color("#2c323c"))
	_back.modulate.a = 1.0 if is_asked else DIM
	add_child(_back)
	_border = CardShapes.outline(box.size, 8, 2, BORDER)
	_border.modulate.a = _back.modulate.a
	add_child(_border)
	var inside: float = box.size.x - 24.0
	_prompt = _label(prompt.text, Rect2(12, 8, inside, 52), 18, Color.WHITE)
	add_child(_prompt)
	_pip_names = ManaSymbols.pip_names(prompt.owed)
	for index: int in _pip_names.size():
		var pip: TextureRect = CardShapes.image(ManaSymbols.texture(_pip_names[index]), Rect2(12 + index * 30, 62, 26, 26))
		add_child(pip)
		_pips.append(pip)
	_hint = _label(hint if is_asked else "", Rect2(12, 38, inside, 44), 13, Color(1, 1, 1, 0.65))
	add_child(_hint)
	# The reason sits along the bottom, beside the Cancel or "Declare All" button if there
	# is one: the panel is too short for a row of its own (A489).
	var beside: float = BUTTON_ROOM if prompt.can_cancel or prompt.offers_all_attack else 0.0
	_error = _label(error, Rect2(12, box.size.y - 50, inside - beside, 44), 13, Color(1, 0.45, 0.4))
	_error.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_error)
	if prompt.can_cancel:
		_cancel = Button.new()
		_cancel.text = CANCEL_FORMAT % _cancel_key
		_cancel.focus_mode = Control.FOCUS_NONE
		_cancel.position = Vector2(box.size.x - BUTTON_ROOM, box.size.y - 40)
		_cancel.size = Vector2(BUTTON_ROOM - 12, 32)
		_cancel.add_theme_font_size_override("font_size", 18)
		_cancel.pressed.connect(func() -> void: cancel_pressed.emit())
		add_child(_cancel)
	if prompt.offers_all_attack:
		_all_attack = Button.new()
		_all_attack.text = ALL_ATTACK
		_all_attack.focus_mode = Control.FOCUS_NONE
		_all_attack.position = Vector2(box.size.x - BUTTON_ROOM, box.size.y - 40)
		_all_attack.size = Vector2(BUTTON_ROOM - 12, 32)
		_all_attack.add_theme_font_size_override("font_size", 18)
		_all_attack.pressed.connect(func() -> void:
			if _all_attack.text == UNDECLARE_ALL:
				undeclare_all_pressed.emit()
			else:
				all_attack_pressed.emit())
		add_child(_all_attack)
	_option = _label("", Rect2(12, 8, inside, box.size.y - 16), 18, Color.WHITE)
	add_child(_option)
	_arrange()


## Shows [param text], an Option Menu row in full, in place of everything else. "" puts
## the panel back.
func show_option(text: String) -> void:
	if _option != null:
		_option.text = text
		_arrange()


## Changes what the prompt says without building the panel again, for a choice that is
## counted as it is made ("Discard 2 cards (1 chosen)").
func show_prompt(text: String) -> void:
	if _prompt != null and _prompt.text != text:
		_prompt.text = text


func prompt_text() -> String:
	return _prompt.text


## The reason the last answer was refused, as shown, or "".
func error_text() -> String:
	return _error.text


## The option shown in place of the prompt, or "".
func option_text() -> String:
	return _option.text


## Whether the prompt, and not an option, is what shows.
func shows_prompt() -> bool:
	return _prompt.visible


## Whether the panel is dimmed because nothing is asked of the Hero.
func is_dim() -> bool:
	return _back.modulate.a < 1.0


func has_border() -> bool:
	return _border != null and _border.get_parent() == self


## The pips of what is still owed while paying, such as ["1", "r"].
func owed_pip_names() -> Array[String]:
	return _pip_names


## The line under the prompt saying how the input is used, or "".
func hint_text() -> String:
	return _hint.text


## While [param is_on], which is while any attacker is declared, the "Declare All" button
## reads "Undeclare All" and puts them all back instead (A496).
func show_undeclare(is_on: bool) -> void:
	if _all_attack != null:
		_all_attack.text = UNDECLARE_ALL if is_on else ALL_ATTACK


## The "Declare All" button, or null when attackers are not being declared.
func all_attack_button() -> Button:
	return _all_attack


## The Cancel button, or null when the decision is not a step of a cast.
func cancel_button() -> Button:
	return _cancel


## Names [param key_label] on the Cancel button as the key that cancels: "Cancel [X]".
func show_cancel_key(key_label: String) -> void:
	_cancel_key = key_label
	if _cancel != null:
		_cancel.text = CANCEL_FORMAT % key_label


func error_rect() -> Rect2:
	return Rect2(_error.position, _error.size)


func _arrange() -> void:
	if _option == null:
		return
	var is_option: bool = _option.text != ""
	_option.visible = is_option
	_prompt.visible = not is_option
	_error.visible = not is_option and _error.text != ""
	for pip: TextureRect in _pips:
		pip.visible = not is_option
	_hint.visible = not is_option and _hint.text != ""
	if _cancel != null:
		_cancel.visible = not is_option
	if _all_attack != null:
		_all_attack.visible = not is_option


func _label(text: String, box: Rect2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	# Wrapping is set before the text, or the label grows as wide as its longest line.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	label.add_theme_color_override("font_color", color)
	label.text = text
	label.position = box.position
	label.size = box.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
