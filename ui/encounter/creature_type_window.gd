class_name CreatureTypeWindow
extends ZoneWindow
## The Creature Type Window (game ADR 0053): where the Hero chooses a creature type, titled
## "Rally the Ranks: choose a creature type". A search box at its top has the keyboard as it
## opens. Under it the Hero's own types are pinned, each just its name, then every other type
## as a compact row. What is typed narrows both, its letters picked out, names starting with
## it first; the first match is lit, Up and Down move the light, and Enter chooses the lit
## type. A type brightens under the cursor and a click chooses it. Nothing glows green: every
## type can be chosen.
##
## Its rows are built once for each decision and only shown, hidden and put in order as
## the search changes, so a redraw rebuilds nothing and keeps what is typed (CreatureTypeChoice
## says what is shown).

## A type was chosen: [param answer] answers the decision.
signal chosen(answer: int)
## The cursor or the keyboard came to [param creature_type], or left every type ("").
signal pointed(creature_type: String)
## Escape was pressed in the search box: it is the screen's, as everywhere else.
signal escaped

const WIDTH: float = 760.0
const BOX_HEIGHT: float = 38.0
const PAD: float = 10.0
const PINNED_COLUMNS: int = 3
const PINNED_HEIGHT: float = 40.0
const ROW_HEIGHT: float = 30.0
const PICKED: Color = Color("#f1dc9a")
const MUTED: Color = Color("#9aa3af")
const ROW_FILL: Color = Color("#2c323c")
const ROW_EDGE: Color = Color("#4a515d")

var _choice: CreatureTypeChoice = null
var _filter: LineEdit
var _pinned_heading: Label
var _pinned_grid: GridContainer
var _others_heading: Label
var _others_list: VBoxContainer
## Each type's row or pinned entry, and its words.
var _rows: Dictionary[String, PanelContainer] = {}
var _words: Dictionary[String, RichTextLabel] = {}
## The types shown, in order: what Up and Down step through.
var _shown: Array[String] = []
## The type the keyboard has lit, or "".
var _lit: String = ""
## Whether the light was moved by Up or Down rather than following the search.
var _is_lit_by_keys: bool = false
## The type under the cursor, or "".
var _hovered: String = ""
var _is_clearing: bool = false
## What the search showed matches for last.
var _followed: String = ""


func _init() -> void:
	super("Choice", false, StackColors.PLAIN)
	size = Vector2(WIDTH, 600)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Find a creature type"
	_filter.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_filter.offset_left = PAD
	_filter.offset_right = -PAD
	_filter.offset_top = ZoneWindow.BAR_HEIGHT + PAD
	_filter.offset_bottom = ZoneWindow.BAR_HEIGHT + PAD + BOX_HEIGHT
	_filter.add_theme_font_size_override("font_size", 18)
	_filter.clear_button_enabled = true
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#14171c")
	style.border_color = Color("#575a60")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 34
	style.content_margin_right = 8
	_filter.add_theme_stylebox_override("normal", style)
	var focused: StyleBoxFlat = style.duplicate()
	focused.border_color = PICKED
	_filter.add_theme_stylebox_override("focus", focused)
	_filter.add_child(_magnifier())
	_filter.text_changed.connect(func(_text: String) -> void: _follow_search())
	_filter.text_submitted.connect(func(_text: String) -> void: choose_lit())
	add_child(_filter)
	scroll().offset_top = ZoneWindow.BAR_HEIGHT + PAD + BOX_HEIGHT + PAD
	_pinned_heading = _heading("Your creatures' types")
	body().add_child(_pinned_heading)
	_pinned_grid = GridContainer.new()
	_pinned_grid.columns = PINNED_COLUMNS
	_pinned_grid.add_theme_constant_override("h_separation", 6)
	_pinned_grid.add_theme_constant_override("v_separation", 6)
	body().add_child(_pinned_grid)
	_others_heading = _heading("")
	body().add_child(_others_heading)
	_others_list = VBoxContainer.new()
	_others_list.add_theme_constant_override("separation", 3)
	body().add_child(_others_list)


## Shows [param choice]. The rows are built only for a new decision; the same one again
## changes nothing, so what is typed and where the list is scrolled stay.
func show_choice(choice: CreatureTypeChoice) -> void:
	if _choice != null and _choice.is_for(choice.decision):
		return
	_choice = choice
	_build_rows()
	show_title("%s: choose a creature type" % choice.spell_name() if choice.spell_name() != "" else "Choose a creature type")
	_filter.text = ""
	_follow_search()
	scroll().scroll_vertical = 0


## Opens the window with the keyboard in its search box.
func open_for_typing() -> void:
	open()
	_filter.grab_focus.call_deferred()


## The choice shown, or null.
func choice() -> CreatureTypeChoice:
	return _choice


## Forgets the choice, once it has been answered, and gives the keyboard back to the screen.
func forget() -> void:
	_choice = null
	if _filter.has_focus():
		_filter.release_focus()


func filter_box() -> LineEdit:
	return _filter


func query() -> String:
	return _filter.text


## Types [param text] into the search box, as the keyboard would.
func type_text(text: String) -> void:
	_filter.text = text
	_filter.caret_column = text.length()
	_follow_search()


## The types shown, in order: pinned first, then the others.
func shown_types() -> Array[String]:
	return _shown.duplicate()


## The type Enter would choose, or "".
func lit() -> String:
	return _lit


## The type the cursor is on, or else the lit one, or "".
func pointing() -> String:
	return _hovered if _hovered != "" else _lit


## The row or pinned entry of [param creature_type], or null.
func row_of(creature_type: String) -> PanelContainer:
	return _rows.get(creature_type, null)


## What takes a click on [param creature_type]'s row.
func catcher_of(creature_type: String) -> ClickCatcher:
	var row: PanelContainer = row_of(creature_type)
	return ClickCatcher.of(row) if row != null else null


## The words drawn for [param creature_type], with the typed letters picked out.
func words_of(creature_type: String) -> String:
	var words: RichTextLabel = _words.get(creature_type, null)
	return words.text if words != null else ""


## Moves the light [param steps] through the types shown (Up is -1, Down 1).
func step_light(steps: int) -> void:
	if _choice == null:
		return
	_light(_choice.stepped(_lit, query(), steps), true)


## Chooses the lit type, if one is: the top match of what is typed, or where Up and Down
## moved the light.
func choose_lit() -> void:
	_catch_up()
	if _choice != null and _lit != "":
		chosen.emit(_choice.answer_of(_lit))


## Up, Down and Escape are taken before the search box sees them, which would move its caret
## or stop editing with them.
func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and _filter.has_focus() and take_key(event):
		get_viewport().set_input_as_handled()


## Does what [param event] does while the search box has the keyboard: Up and Down move the
## light, Escape is the screen's. Whether it was one of them.
func take_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return false
	_catch_up()
	match key.keycode:
		KEY_UP:
			step_light(-1)
			return true
		KEY_DOWN:
			step_light(1)
			return true
		KEY_ESCAPE:
			if not key.echo:
				escaped.emit()
			return true
	return false


## The search box says it changed a frame late, so a key pressed in the same frame as a
## letter first follows what is typed now.
func _catch_up() -> void:
	if _choice != null and _followed != query():
		_follow_search()


## The search changed: the matches are shown in order, their typed letters picked out, and
## the top match is lit.
func _follow_search() -> void:
	if _choice == null:
		return
	var typed: String = query()
	_followed = typed
	var pinned: Array[String] = _choice.pinned(typed)
	var others: Array[String] = _choice.others(typed)
	_shown = pinned.duplicate()
	_shown.append_array(others)
	var showing: Dictionary[String, bool] = {}
	for creature_type: String in _shown:
		showing[creature_type] = true
	for creature_type: String in _rows:
		var row: PanelContainer = _rows[creature_type]
		row.visible = showing.has(creature_type)
		if row.visible:
			var words: String = _picked_out(creature_type, typed)
			if _words[creature_type].text != words:
				_words[creature_type].text = words
	for index: int in pinned.size():
		_pinned_grid.move_child(_rows[pinned[index]], index)
	for index: int in others.size():
		_others_list.move_child(_rows[others[index]], index)
	_pinned_heading.visible = not pinned.is_empty()
	_pinned_grid.visible = not pinned.is_empty()
	if typed == "":
		_others_heading.text = "Every other creature type (%d)" % others.size()
	elif pinned.is_empty() and others.is_empty():
		_others_heading.text = "No creature type matches \"%s\"." % typed
	else:
		_others_heading.text = "Other creature types matching \"%s\" (%d)" % [typed, others.size()]
	_is_lit_by_keys = false
	_light(_choice.top_match(typed), false)


## Lights [param creature_type] ("" for none) as the one Enter chooses, and says so as if the
## cursor were on it, unless the cursor is on another.
func _light(creature_type: String, by_keys: bool) -> void:
	if _lit != "" and _rows.has(_lit):
		_rows[_lit].add_theme_stylebox_override("panel", _row_style(false, _is_pinned(_lit)))
	_lit = creature_type
	_is_lit_by_keys = by_keys
	if _lit != "":
		var row: PanelContainer = _rows[_lit]
		row.add_theme_stylebox_override("panel", _row_style(true, _is_pinned(_lit)))
		if by_keys:
			_scroll_to(row)
	if _hovered == "":
		pointed.emit(_lit)


func _is_pinned(creature_type: String) -> bool:
	return _choice != null and _choice.yours().has(creature_type)


func _scroll_to(row: Control) -> void:
	if row.is_inside_tree():
		scroll().ensure_control_visible(row)


func _build_rows() -> void:
	_is_clearing = true
	for list: Container in [_pinned_grid, _others_list]:
		for child: Node in list.get_children():
			list.remove_child(child)
			child.queue_free()
	_is_clearing = false
	_rows.clear()
	_words.clear()
	_lit = ""
	_hovered = ""
	var yours: Array[String] = _choice.yours()
	for creature_type: String in yours:
		_pinned_grid.add_child(_row(creature_type, true))
	for creature_type: String in _choice.others(""):
		_others_list.add_child(_row(creature_type, false))


## A row with only the type's name, or a pinned entry, a little larger; under the cursor it
## brightens (ClickCatcher) and a click chooses its type.
func _row(creature_type: String, is_pinned: bool) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override("panel", _row_style(false, is_pinned))
	row.custom_minimum_size = Vector2(0, PINNED_HEIGHT if is_pinned else ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words: RichTextLabel = RichTextLabel.new()
	words.bbcode_enabled = true
	words.fit_content = true
	words.scroll_active = false
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_font_size_override("normal_font_size", 19 if is_pinned else 17)
	words.text = creature_type
	row.add_child(words)
	var catcher: ClickCatcher = ClickCatcher.add(row, row.size)
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.clicked.connect(func() -> void:
		if _choice != null:
			chosen.emit(_choice.answer_of(creature_type)))
	catcher.mouse_entered.connect(_on_hovered.bind(creature_type, true))
	catcher.mouse_exited.connect(_on_hovered.bind(creature_type, false))
	_rows[creature_type] = row
	_words[creature_type] = words
	return row


func _on_hovered(creature_type: String, is_over: bool) -> void:
	if _is_clearing or not is_inside_tree():
		return
	if is_over:
		_hovered = creature_type
		pointed.emit(creature_type)
	elif _hovered == creature_type:
		_hovered = ""
		pointed.emit(_lit)


func _row_style(is_lit: bool, is_pinned: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = ROW_FILL.lightened(0.08) if is_lit else ROW_FILL
	style.border_color = PICKED if is_lit else ROW_EDGE
	style.set_border_width_all(2 if is_lit else 1)
	style.set_corner_radius_all(5 if is_pinned else 4)
	style.content_margin_left = 12 if is_pinned else 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


## [param creature_type] with the letters of [param typed] picked out, as BBCode.
static func _picked_out(creature_type: String, typed: String) -> String:
	if typed == "":
		return creature_type
	var at: int = creature_type.to_lower().find(typed.to_lower())
	if at < 0:
		return creature_type
	return "%s[color=#%s]%s[/color]%s" % [creature_type.substr(0, at), PICKED.to_html(false),
		creature_type.substr(at, typed.length()), creature_type.substr(at + typed.length())]


func _heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", MUTED)
	return label


## A small magnifying glass drawn at the box's left: no font has to have one.
func _magnifier() -> Control:
	var glass: Magnifier = Magnifier.new()
	glass.position = Vector2(9, 9)
	glass.size = Vector2(20, 20)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glass


class Magnifier:
	extends Control

	const INK: Color = Color("#9aa3af")

	func _draw() -> void:
		draw_arc(Vector2(8, 8), 6.0, 0.0, TAU, 24, INK, 2.0, true)
		draw_line(Vector2(12.5, 12.5), Vector2(18, 18), INK, 2.5, true)
