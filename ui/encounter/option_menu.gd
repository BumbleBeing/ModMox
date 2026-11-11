class_name OptionMenu
extends Control
## The Option Menu (game glossary): the dropdown that opens where a card was clicked when
## the click could mean more than one thing, one row for each. It shows three rows and
## scrolls for more (A286), stays inside the battlefield, and closes without choosing when
## anything outside it is clicked. It covers the screen while open, to catch that click.

## The row answering [param answer] was pressed.
signal chosen(answer: int)
## The cursor is over the row that reads [param text] in full, or left it ("").
signal pointed(text: String)

var _box: PanelContainer = null
var _rows: Array[Button] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


## Opens with a row for each of [param options] where the card was clicked, [param at],
## kept inside [param field].
func open(options: Array[ClickOption], at: Vector2, field: Rect2) -> void:
	close()
	var box_rect: Rect2 = EncounterLayout.menu_rect(at, options.size(), field)
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
	_box.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", roundi(EncounterLayout.MENU_GAP))
	scroll.add_child(list)
	for option: ClickOption in options:
		var row: Button = _row(option)
		list.add_child(row)
		_rows.append(row)
	add_child(_box)
	show()


## Closes the menu without choosing.
func close() -> void:
	if _box == null:
		return
	remove_child(_box)
	_box.queue_free()
	_box = null
	_rows.clear()
	hide()
	pointed.emit("")


func is_open() -> bool:
	return _box != null


## One button for each option, in order.
func rows() -> Array[Button]:
	return _rows


## Where the menu's box is, or an empty rectangle while it is closed.
func box_rect() -> Rect2:
	return Rect2(_box.position, _box.size) if _box != null else Rect2()


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		accept_event()
		close()


func _row(option: ClickOption) -> Button:
	var row: Button = Button.new()
	row.text = option.text
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	row.custom_minimum_size = Vector2(0, EncounterLayout.MENU_ROW)
	row.add_theme_font_size_override("font_size", 16)
	for state: String in ["normal", "hover", "pressed"]:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = PlayerPanel.PLAIN_COLOR if state == "normal" else PlayerPanel.PLAIN_COLOR.lightened(0.22)
		flat.set_corner_radius_all(4)
		flat.content_margin_left = 10
		row.add_theme_stylebox_override(state, flat)
	row.mouse_entered.connect(func() -> void: pointed.emit(option.text))
	row.mouse_exited.connect(func() -> void: pointed.emit(""))
	row.pressed.connect(func() -> void:
		close()
		chosen.emit(option.answer))
	return row
