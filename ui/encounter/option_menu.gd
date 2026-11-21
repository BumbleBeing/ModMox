class_name OptionMenu
extends Control
## The Option Menu (game glossary): the dropdown that opens where a card was clicked when
## the click could mean more than one thing, one row for each. It shows three rows and
## scrolls for more (A286), stays inside the battlefield, and closes without choosing when
## anything outside it is clicked or the cancel key is pressed (ADR 0073). It covers the
## screen while open, to catch that click.
##
## A row's words draw their mana symbols as pips. A menu of the colors of mana of any color
## shows every color, and a row that has a Glow glows green (game ADR 0073).

## The row answering [param answer] was pressed.
signal chosen(answer: int)
## The cursor is over the row that reads [param text] in full, or left it ("").
signal pointed(text: String)
## The menu was open and has closed, whether or not a row was chosen.
signal closed

## What pointed_answer() gives with the cursor over no row.
const NO_ANSWER: int = -1
## The size of a row's words, and how far they stay from its sides.
const ROW_FONT: int = 18
const ROW_INSET: float = 10.0

## How long it takes to ease in or out; the Encounter Screen sets it.
var ease_seconds: float = 0.0
var _pointed_answer: int = NO_ANSWER
var _box: PanelContainer = null
var _rows: Array[Button] = []
var _words: Array[SymbolLabel] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


## Opens with a row for each of [param options] where the card was clicked, [param at],
## kept inside [param field].
func open(options: Array[ClickOption], at: Vector2, field: Rect2) -> void:
	close()
	var most_shown: int = most_rows_shown(options)
	var box_rect: Rect2 = EncounterLayout.menu_rect(at, options.size(), field, most_shown)
	_box = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 0.98)
	style.border_color = InfoPanel.BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(EncounterLayout.MENU_PAD)
	_box.add_theme_stylebox_override("panel", style)
	_box.position = box_rect.position
	_box.size = box_rect.size
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = box_rect.size - Vector2.ONE * EncounterLayout.MENU_PAD * 2.0
	# A row's Glow reaches past the row, so nothing is cut off at the menu's edge unless its
	# rows scroll.
	scroll.clip_contents = options.size() > most_shown
	_box.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", roundi(EncounterLayout.MENU_GAP))
	scroll.add_child(list)
	for option: ClickOption in options:
		var row: Button = _row(option, scroll.custom_minimum_size.x)
		list.add_child(row)
		_rows.append(row)
	add_child(_box)
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	show()
	Easing.fade_in(_box, ease_seconds)


## The most rows a menu of [param options] shows before it scrolls: three (A286), or as
## many as it has colors of mana of any color, so that all five colors are in sight at once
## (game ADR 0073).
static func most_rows_shown(options: Array[ClickOption]) -> int:
	var colors: Array[ClickOption] = options.filter(func(option: ClickOption) -> bool:
		return option.mana_type != MmMana.NO_TYPE)
	return maxi(EncounterLayout.MENU_ROWS_SHOWN, colors.size())


## The answer of the row the cursor is over, or NO_ANSWER: the Tap Preview shows what that
## row would tap.
func pointed_answer() -> int:
	return _pointed_answer if is_open() else NO_ANSWER


## Closes the menu without choosing.
func close() -> void:
	_pointed_answer = NO_ANSWER
	if _box == null:
		return
	var leaving: Control = _box
	_box = null
	_rows.clear()
	_words.clear()
	# Deaf to the mouse at once; hidden once its box has faded, unless opened again.
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	Easing.fade_out_and_free(leaving, ease_seconds, _hide_unless_open)
	pointed.emit("")
	closed.emit()


func _hide_unless_open() -> void:
	if not is_open():
		hide()
		mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED


func is_open() -> bool:
	return _box != null


## One button for each option, in order.
func rows() -> Array[Button]:
	return _rows


## The words of each row, in order, each drawing its mana symbols as pips.
func words() -> Array[SymbolLabel]:
	return _words


## Where the menu's box is, or an empty rectangle while it is closed.
func box_rect() -> Rect2:
	return Rect2(_box.position, _box.size) if _box != null else Rect2()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		accept_event()
		close()


## The row of [param option], [param width] wide.
func _row(option: ClickOption, width: float) -> Button:
	var row: Button = Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, EncounterLayout.MENU_ROW)
	for state: String in ["normal", "hover", "pressed"]:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = PlayerPanel.PLAIN_COLOR if state == "normal" else PlayerPanel.PLAIN_COLOR.lightened(0.22)
		flat.set_corner_radius_all(4)
		row.add_theme_stylebox_override(state, flat)
	_add_words(row, option.row_text)
	if option.has_glow:
		BorderEffects.add_glow(row, Vector2(width, EncounterLayout.MENU_ROW),
			DecisionClicks.color_of(DecisionClicks.Kind.PLAY))
	row.mouse_entered.connect(func() -> void:
		_pointed_answer = option.answer
		pointed.emit(option.text))
	row.mouse_exited.connect(func() -> void:
		if _pointed_answer == option.answer:
			_pointed_answer = NO_ANSWER
		pointed.emit(""))
	row.pressed.connect(func() -> void:
		close()
		chosen.emit(option.answer))
	return row


## Writes [param text] on [param row] on one line, its mana symbols drawn as pips (a
## SymbolLabel, never the button's own text, which shows the braces), cut off at the row's
## edge when it is too long: the Info Panel shows it in full.
func _add_words(row: Button, text: String) -> void:
	var room: Control = Control.new()
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.clip_contents = true
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.offset_left = ROW_INSET
	room.offset_right = -ROW_INSET
	row.add_child(room)
	var words: SymbolLabel = SymbolLabel.new()
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.set_font_size(ROW_FONT)
	words.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	words.position = Vector2(0, (EncounterLayout.MENU_ROW - get_theme_default_font().get_height(ROW_FONT)) / 2.0)
	words.write(text)
	room.add_child(words)
	_words.append(words)
