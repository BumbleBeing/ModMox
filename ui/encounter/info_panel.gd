class_name InfoPanel
extends Control
## The Info Panel (game glossary, game ADR 0066): the Dither Shaded box at the left end of
## the hand's strip. Centered in it, it says what the Hero is being asked and what is still
## owed while paying; in red above its Answer Row, why their last answer was refused. The
## Answer Row (game glossary) is its bottom row: the two answers of a "you may", a ward cost
## or an X, or one action across its whole width, Cancel or "Declare All", which acts at
## once. A press of an answer is reported and the screen says what it does: it answers at
## once, or only selects while an X is asked. While how much X to pay is asked, the
## affirmative half is the X stepper. Its border flashes white once when a question other than priority
## arrives. While the cursor is over a row of the Option Menu, it shows that option in full
## in place of everything else.

signal cancel_pressed
signal all_attack_pressed
## "Undeclare All" was pressed: the same button, while an attacker is declared (A496).
signal undeclare_all_pressed
## An answer was pressed, AFFIRMATIVE or NO_ANSWER. The panel does nothing with it.
signal answer_pressed(index: int)
## An end of the X stepper was pressed (game ADR 0063).
signal x_lowered
signal x_raised

## Which answer is the Selected Answer: neither, the one on the left or "No".
const NOTHING: int = -1
const AFFIRMATIVE: int = 0
const NO_ANSWER: int = 1

const FILL: Color = Color("#2c323c")
const BORDER: Color = Color("#8a93a6")
const DIM: float = 0.45
## An answer or action, and the brighter face of the Selected Answer.
const BUTTON: Color = Color("#4b4e55")
const SELECTED: Color = Color("#6f7682")
const MUTED: Color = Color(1, 1, 1, 0.65)
const REFUSED: Color = Color(1, 0.45, 0.4)

const CANCEL_FORMAT: String = "Cancel [%s]"
const ALL_ATTACK: String = "Declare All"
const UNDECLARE_ALL: String = "Undeclare All"
const YES: String = "Yes"
const NO: String = "No"
const PAY_FORMAT: String = "Pay %s"

## The room kept at the panel's sides and under its Answer Row.
const INSET: float = 12.0
const TOP: float = 8.0
const ROW_HEIGHT: float = 44.0
const ROW_GAP: float = 8.0
const PROMPT_FONT: int = 22
## A prompt that would need a third line is drawn this size instead.
const SMALL_PROMPT_FONT: int = 18
const PROMPT_LINES: int = 2
const SMALL_FONT: int = 16
const BUTTON_FONT: int = 20
## A refusal takes one line, or two when it must, growing upward from the Answer Row.
const REFUSAL_HEIGHT: float = 48.0
const FLASH_TIME: float = 0.3

var _back: Panel = null
var _flash: Panel = null
var _flash_count: int = 0
## What was asked when the border last flashed, so that the same question redrawn does not.
var _flashed_for: String = ""
var _prompt: SymbolLabel = null
var _prompt_text: String = ""
## What is still owed, written after the prompt: " {2}" on its line or under it.
var _owed_text: String = ""
var _error: Label = null
var _option: SymbolLabel = null
var _hint: Label = null
var _pip_names: Array[String] = []
var _asked: InfoPrompt = null
var _cancel: Button = null
## The key that cancels, as the Cancel button names it.
var _cancel_key: String = "X"
var _all_attack: Button = null
var _is_undeclaring: bool = false
var _affirmative: Button = null
var _no: Button = null
var _x_stepper: XStepper = null
var _x: int = 0
var _selected: int = NOTHING


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fills [param box] from [param snapshot], with [param error] if the last answer was
## refused and [param hint], a smaller line under the prompt saying how the input is used.
## The panel is dim and empty while nothing is asked of the Hero.
func show_snapshot(snapshot: EncounterSnapshot, error: String, box: Rect2, hint: String = "") -> void:
	for child: Node in get_children():
		if child != _flash:
			remove_child(child)
			child.queue_free()
	_cancel = null
	_all_attack = null
	_affirmative = null
	_no = null
	_x_stepper = null
	_option = null
	position = box.position
	size = box.size
	# A payment Auto-tap is making asks nothing, but says what is owed and can be canceled.
	var is_asked: bool = (snapshot.decision != null or snapshot.paying != null) and not snapshot.is_over()
	_asked = InfoPrompt.of(snapshot.decision if is_asked else null, snapshot.view,
			snapshot.paying if is_asked else null, snapshot.names)
	_back = Panel.new()
	_back.size = box.size
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back.add_theme_stylebox_override("panel",
		DitherShading.plate(FILL.lightened(0.06), FILL.darkened(0.3), BORDER, 8, 2, 0, maxi(1, int(box.size.y))))
	_back.modulate.a = 1.0 if is_asked else DIM
	add_child(_back)
	var inside: float = box.size.x - INSET * 2.0
	_pip_names = ManaSymbols.pip_names(_asked.owed)
	_owed_text = ""
	if not _pip_names.is_empty():
		var symbols: String = ""
		for pip: String in _pip_names:
			symbols += "{%s}" % pip.to_upper()
		_owed_text = (" " if _asked.is_owed_inline else "\n") + symbols
	_prompt = _words(Rect2(INSET, TOP, inside, 0))
	add_child(_prompt)
	_hint = _label(hint if is_asked else "", Rect2(INSET, TOP, inside, 44), SMALL_FONT, MUTED)
	add_child(_hint)
	_write_prompt(_asked.text)
	var row_top: float = box.size.y - INSET - ROW_HEIGHT
	_error = _label(error, Rect2(INSET, row_top - REFUSAL_HEIGHT - 4.0, inside, REFUSAL_HEIGHT), SMALL_FONT, REFUSED)
	_error.add_theme_constant_override("line_spacing", -2)
	_error.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_error)
	_build_row()
	_option = _words(Rect2(INSET, TOP, inside, 0))
	add_child(_option)
	_show_flash(box.size, snapshot.decision if is_asked else null)
	_arrange()


## Lights answer [param index] of the Answer Row as the Selected Answer, or none of them
## for NOTHING. It does nothing to a row with no answers.
func show_selected(index: int) -> void:
	if _selected == index:
		return
	_selected = index
	if _asked != null and (_asked.offers_no or _asked.chooses_x):
		_build_row()
		_arrange()


## The Selected Answer as the row shows it: NOTHING, AFFIRMATIVE or NO_ANSWER.
func selected() -> int:
	return _selected


## Shows [param x] on the X stepper, which can go from 0 to the most the Hero can pay. It
## does nothing while how much X to pay is not asked.
func show_x(x: int) -> void:
	if _x == x and _x_stepper != null:
		return
	_x = x
	if _asked != null and _asked.chooses_x:
		_build_row()
		_arrange()


## The X stepper, or null while how much X to pay is not asked.
func x_stepper() -> XStepper:
	return _x_stepper


## Shows [param text], an Option Menu row in full, in place of everything else. "" puts
## the panel back.
func show_option(text: String) -> void:
	if _option != null:
		if _option.written() != text:
			_option.write(text)
		_arrange()


## Changes what the prompt says without building the panel again, for a choice that is
## counted as it is made ("Discard 2 cards (1 chosen)").
func show_prompt(text: String) -> void:
	if _prompt != null and _prompt_text != text:
		_write_prompt(text)


func prompt_text() -> String:
	return _prompt_text


## The size the prompt is drawn at, before it is raised: PROMPT_FONT, or SMALL_PROMPT_FONT
## when it would need a third line.
func prompt_font_size() -> int:
	return _prompt.get_meta("font", PROMPT_FONT)


## The reason the last answer was refused, as shown, or "".
func error_text() -> String:
	return _error.text


## The option shown in place of the prompt, or "".
func option_text() -> String:
	return _option.written()


## Whether the prompt, and not an option, is what shows.
func shows_prompt() -> bool:
	return _prompt.visible


## Whether the panel is dimmed because nothing is asked of the Hero.
func is_dim() -> bool:
	return _back.modulate.a < 1.0


func has_border() -> bool:
	return _back != null and _back.get_parent() == self


## The pips of what is still owed while paying, such as ["1", "r"].
func owed_pip_names() -> Array[String]:
	return _pip_names


## What the prompt's line reads with what is owed written after it: "Pay for Hill Giant\n{3}{R}".
func prompt_written() -> String:
	return _prompt.written()


## The line under the prompt saying how the input is used, or "".
func hint_text() -> String:
	return _hint.text


## While [param is_on], which is while any attacker is declared, the "Declare All" button
## reads "Undeclare All" and puts them all back instead (A496).
func show_undeclare(is_on: bool) -> void:
	_is_undeclaring = is_on
	if _all_attack != null:
		_all_attack.text = UNDECLARE_ALL if is_on else ALL_ATTACK


## The "Declare All" button, or null when attackers are not being declared.
func all_attack_button() -> Button:
	return _all_attack


## The answer on the left of the Answer Row, "Yes" or "Pay {2}", or null while no question
## with answers is asked or the X stepper is there instead.
func affirmative_button() -> Button:
	return _affirmative


## What the answer on the left reads, "Yes" or "Pay {2}", or "" when there is none.
func affirmative_text() -> String:
	return _affirmative.get_meta("words", "") if _affirmative != null else ""


## The "No" answer, or null while no question with answers is asked.
func no_button() -> Button:
	return _no


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


## Where the Answer Row is, in the panel.
func row_rect() -> Rect2:
	return Rect2(INSET, size.y - INSET - ROW_HEIGHT, size.x - INSET * 2.0, ROW_HEIGHT)


## Where the prompt's lines are, in the panel.
func prompt_rect() -> Rect2:
	return Rect2(_prompt.position, Vector2(_prompt.size.x, _line_count(_prompt.written(), prompt_font_size()) * _line_height(prompt_font_size())))


## How many times the border has flashed for a new question.
func flash_count() -> int:
	return _flash_count


## Builds the Answer Row from what is asked: two answers, one action, or nothing.
func _build_row() -> void:
	for old: Button in [_cancel, _all_attack, _affirmative, _no, _x_stepper]:
		if old != null:
			remove_child(old)
			old.queue_free()
	_cancel = null
	_all_attack = null
	_affirmative = null
	_no = null
	_x_stepper = null
	var row: Rect2 = row_rect()
	var half: float = (row.size.x - ROW_GAP) / 2.0
	var left: Rect2 = Rect2(row.position, Vector2(half, row.size.y))
	var right: Rect2 = Rect2(row.position + Vector2(half + ROW_GAP, 0), Vector2(half, row.size.y))
	if _asked.can_cancel:
		# Engine ADR 0076: X chosen as a spell is cast has its stepper on the left and Cancel
		# where No would be.
		_cancel = _button(CANCEL_FORMAT % _cancel_key, right if _asked.chooses_x else row, false)
		_cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	if _asked.offers_all_attack:
		_all_attack = _button(UNDECLARE_ALL if _is_undeclaring else ALL_ATTACK, row, false)
		_all_attack.pressed.connect(func() -> void:
			if _all_attack.text == UNDECLARE_ALL:
				undeclare_all_pressed.emit()
			else:
				all_attack_pressed.emit())
	if not _asked.offers_no and not _asked.chooses_x:
		return
	var is_yes: bool = _selected == AFFIRMATIVE
	if _asked.chooses_x:
		_x_stepper = XStepper.new(left, _x, _x > 0, _x < _asked.most_x, SELECTED if is_yes else BUTTON, is_yes)
		_x_stepper.pressed.connect(func() -> void: answer_pressed.emit(AFFIRMATIVE))
		_x_stepper.lowered.connect(func() -> void: x_lowered.emit())
		_x_stepper.raised.connect(func() -> void: x_raised.emit())
		add_child(_x_stepper)
	else:
		var words: String = YES if _owed_text == "" else PAY_FORMAT % _owed_text.strip_edges()
		_affirmative = _button(_asked.affirmative if _asked.affirmative != "" else words, left, is_yes)
		_affirmative.pressed.connect(func() -> void: answer_pressed.emit(AFFIRMATIVE))
	if _asked.offers_no:
		_no = _button(NO, right, _selected == NO_ANSWER)
		_no.pressed.connect(func() -> void: answer_pressed.emit(NO_ANSWER))
	if _option != null:
		move_child(_option, -1)
	if _flash != null:
		move_child(_flash, -1)


## A button of the Answer Row in [param box], framed, its ring white when [param is_lit].
## Words with a mana symbol, as "Pay {2}", are drawn with it.
func _button(words: String, box: Rect2, is_lit: bool) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.position = box.position
	button.size = box.size
	button.add_theme_font_size_override("font_size", BUTTON_FONT + UiText.RAISE)
	button.set_meta("words", words)
	button.set_meta("is_lit", is_lit)
	SteelFrame.apply(button, SELECTED if is_lit else BUTTON, is_lit)
	if words.contains("{"):
		var line: SymbolLabel = SymbolLabel.new()
		line.set_font_size(BUTTON_FONT + UiText.RAISE)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		line.size = Vector2(box.size.x, 0)
		line.position = Vector2(0, (SteelFrame.face_height(box.size.y) - _line_height(BUTTON_FONT)) / 2.0)
		line.write(words)
		button.add_child(line)
	else:
		button.text = words
	add_child(button)
	return button


## Whether [param button] of the Answer Row is lit as the Selected Answer.
static func is_lit(button: Button) -> bool:
	return button != null and button.get_meta("is_lit", false)


## Writes [param text] as the prompt, what is owed after it, at the size that keeps it to
## PROMPT_LINES lines, and puts the hint under it.
func _write_prompt(text: String) -> void:
	_prompt_text = text
	var written: String = text + _owed_text if text != "" else ""
	var font_size: int = PROMPT_FONT if _line_count(written, PROMPT_FONT) <= PROMPT_LINES else SMALL_PROMPT_FONT
	_prompt.set_meta("font", font_size)
	_prompt.set_font_size(font_size + UiText.RAISE)
	_prompt.write(written)
	_hint.position.y = TOP + _line_count(written, font_size) * _line_height(font_size) + 2.0


## Flashes the border white once when what is asked is new and is not priority.
func _show_flash(box: Vector2, decision: MmPendingDecision) -> void:
	if _flash == null or _flash.size != box:
		if _flash != null:
			remove_child(_flash)
			_flash.queue_free()
		_flash = CardShapes.outline(box, 8, 3, Color.WHITE)
		_flash.modulate.a = 0.0
		add_child(_flash)
	move_child(_flash, -1)
	var asked: String = _asked.text
	if asked == _flashed_for:
		return
	_flashed_for = asked
	if asked == "" or decision is PriorityDecision:
		return
	_flash_count += 1
	_flash.modulate.a = 1.0
	if is_inside_tree():
		create_tween().tween_property(_flash, "modulate:a", 0.0, FLASH_TIME)
	else:
		_flash.modulate.a = 0.0


func _arrange() -> void:
	if _option == null:
		return
	var is_option: bool = _option.written() != ""
	_option.visible = is_option
	_prompt.visible = not is_option
	_error.visible = not is_option and _error.text != ""
	_hint.visible = not is_option and _hint.text != ""
	for button: Button in [_cancel, _all_attack, _affirmative, _no, _x_stepper]:
		if button != null:
			button.visible = not is_option


## How many lines [param text] takes in the panel at [param font_size].
func _line_count(text: String, font_size: int) -> int:
	if text == "":
		return 0
	var font: Font = get_theme_default_font()
	var raised: int = font_size + UiText.RAISE
	# A mana symbol is about as wide as two letters of its line.
	var plain: String = text.replace("{", "").replace("}", "0")
	return roundi(font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, size.x - INSET * 2.0, raised).y
		/ font.get_height(raised))


func _line_height(font_size: int) -> float:
	return get_theme_default_font().get_height(font_size + UiText.RAISE)


## A centered line of words that draws its mana symbols.
func _words(box: Rect2) -> SymbolLabel:
	var line: SymbolLabel = SymbolLabel.new()
	line.set_font_size(PROMPT_FONT + UiText.RAISE)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.position = box.position
	line.size = box.size
	return line


func _label(text: String, box: Rect2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	# Wrapping is set before the text, or the label grows as wide as its longest line.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	label.add_theme_color_override("font_color", color)
	label.text = text
	label.position = box.position
	label.size = box.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
