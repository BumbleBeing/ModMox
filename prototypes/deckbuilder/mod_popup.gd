class_name ModPopup
extends Control
## The window for applying a held Mod to the selected card. It covers the deckbuilder and
## has three bordered panels of one height, a card's and a little more, each with its title
## centered at the top. Valid Mods lists every kind of Mod the Hero holds, with how many:
## the ones not applicable to the card are gray and take no clicks. Current is the card as
## it is. The third is the card as it would become: "With selected Mod" until a Mod is
## hovered over or clicked, then "With" and that Mod's name; its place is empty until then. The faces here show no Mod
## Slots. Clicking a Mod makes Apply live and offers Cancel, and Apply asks once more
## before it says the Mod was applied, because applying is final.
##
## The window is as large as what is in it and no larger.
##
## It changes nothing itself: it reports [signal applied] and [signal closed].

signal applied(mod: Mod)
signal closed

enum State { CHOOSING, CHOSEN, CONFIRMING }

const PAD: float = 20.0
## The room between a panel's edge and what is in it.
const PANEL_PAD: float = 12.0
const NO_MOD_TITLE: String = "With selected Mod"
const TILES_WIDTH: float = 380.0
const FACE_HEIGHT: float = 380.0
const DIM: Color = Color(0, 0, 0, 0.6)
const FILL: Color = DeckbuilderLook.PANE
const BORDER: Color = DeckbuilderLook.PANE_BORDER
const MUTED: Color = DeckbuilderLook.MUTED
const CHOSEN_RING: Color = Color("#e8cf8a")
## A Mod's tile: darker than the other buttons.
const TILE: Color = Color("#33363c")

var _card: DeckbuilderCard = null
var _held_mods: HeldMods = null
var _state: State = State.CHOOSING
## The Mod the "after" face is showing, or null.
var _previewed: Mod = null
## The Mod that was clicked, or null.
var _chosen: Mod = null
var _tiles: Dictionary[Mod, Button] = {}
var _before: CardFace = null
var _after: CardFace = null
var _after_place: Control = null
var _after_caption: Label = null
var _window: PanelContainer = null
var _panels: Array[PanelContainer] = []
var _footer: HBoxContainer = null
var _buttons: Dictionary[String, Button] = {}
var _question: Label = null


## Shows the Mods of [param held_mods] for [param card].
func setup(card: DeckbuilderCard, held_mods: HeldMods) -> void:
	_card = card
	_held_mods = held_mods
	theme = DeckbuilderLook.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_window = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FILL
	style.border_color = DeckbuilderLook.PANEL_EDGE
	style.set_border_width_all(DeckbuilderLook.PANEL_EDGE_WIDTH)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	style.set_content_margin_all(PAD)
	_window.add_theme_stylebox_override("panel", style)
	center.add_child(_window)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	_window.add_child(rows)
	var heading: Label = _label("Modify %s" % card.look().name, 26)
	heading.name = "Heading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", DeckbuilderLook.bold())
	rows.add_child(heading)
	var middle: HBoxContainer = HBoxContainer.new()
	middle.add_theme_constant_override("separation", 16)
	rows.add_child(middle)
	_tile_list(_panel(middle, "Valid Mods"))
	_faces(middle)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	_footer.custom_minimum_size = Vector2(0, 40)
	rows.add_child(_footer)
	_show_state()


func state() -> State:
	return _state


## The tile for [param mod], or null if none of it is held.
func tile(mod: Mod) -> Button:
	return _tiles.get(mod, null) as Button


## The Mod the "as it would become" face is showing, or null.
func previewed() -> Mod:
	return _previewed


## The Mod that was clicked and is waiting for Apply, or null.
func chosen() -> Mod:
	return _chosen


## The window itself, which is no larger than what is in it.
func window() -> PanelContainer:
	return _window


## The three panels, left to right: Valid Mods, Current and the card with a Mod.
func panels() -> Array[PanelContainer]:
	return _panels


## The title at the top of each panel, left to right.
func panel_titles() -> Array[String]:
	var titles: Array[String] = []
	for panel: PanelContainer in _panels:
		titles.append((panel.find_child("Title", true, false) as Label).text)
	return titles


## The card as it is.
func before_face() -> CardFace:
	return _before


## The card as it would become with the previewed Mod, or null while none is previewed.
func after_face() -> CardFace:
	return _after


## The button named [param key] if it is offered now: "close", "apply", "cancel", "yes" or
## "no". Null otherwise.
func button(key: String) -> Button:
	return _buttons.get(key, null) as Button


## What Apply asks before it is final, or "" when it is not asking.
func question() -> String:
	return "" if _question == null else _question.text


## The cursor comes over [param mod]'s tile, or leaves the tiles when it is null. The card
## with that Mod is shown, unless a Mod has already been clicked.
func hover(mod: Mod) -> void:
	if _state != State.CHOOSING:
		return
	_preview(mod if mod != null and mod.is_applicable_to(_card) else null)


## [param mod]'s tile is clicked. Nothing happens for one that is not applicable.
func choose(mod: Mod) -> void:
	if _state == State.CONFIRMING or not _tiles.has(mod) or not mod.is_applicable_to(_card):
		return
	_chosen = mod
	_state = State.CHOSEN
	_preview(mod)
	_show_state()


func _on_apply() -> void:
	if _state != State.CHOSEN:
		return
	_state = State.CONFIRMING
	_show_state()


func _on_cancel() -> void:
	_chosen = null
	_state = State.CHOOSING
	_preview(null)
	_show_state()


func _on_yes() -> void:
	applied.emit(_chosen)


func _on_no() -> void:
	_state = State.CHOSEN
	_show_state()


func _on_close() -> void:
	closed.emit()


## A lighter panel with a gray border and [param title] centered at its top, added to
## [param row]. Returns the column to fill under the title, which is a card's height.
func _panel(row: HBoxContainer, title: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = DeckbuilderLook.COLUMN
	style.border_color = DeckbuilderLook.PANEL_EDGE
	style.set_border_width_all(DeckbuilderLook.PANEL_EDGE_WIDTH)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(PANEL_PAD)
	style.content_margin_top = PANEL_PAD - 4.0
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	_panels.append(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading: Label = _label(title, 18, MUTED)
	heading.name = "Title"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	return column


## The held Mods, one tile for each kind, in [param column].
func _tile_list(column: VBoxContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(TILES_WIDTH, FACE_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var tiles: VBoxContainer = VBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tiles)
	if _held_mods.kinds().is_empty():
		tiles.add_child(_label("You hold no Mods.", 18, MUTED))
	for mod: Mod in _held_mods.kinds():
		var button: Button = Button.new()
		button.text = "%s   ×%d\n%s" % [mod.name, _held_mods.count_of(mod), mod.description]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.custom_minimum_size = Vector2(0, 68)
		_style_tile(button, false)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not mod.is_applicable_to(_card)
		if button.disabled:
			button.tooltip_text = "This Mod cannot go on this card."
		button.pressed.connect(choose.bind(mod))
		button.mouse_entered.connect(hover.bind(mod))
		button.mouse_exited.connect(hover.bind(null))
		tiles.add_child(button)
		_tiles[mod] = button


## The card as it is, and beside it the place for the card as it would become, each in a
## panel of its own in [param row]. Neither face shows its Mod Slots.
func _faces(row: HBoxContainer) -> void:
	var card_size: Vector2 = Vector2(FACE_HEIGHT * CardGeometry.ASPECT, FACE_HEIGHT)
	_before = DeckbuilderFace.make(_card, FACE_HEIGHT, false)
	var before_place: Control = Control.new()
	before_place.custom_minimum_size = card_size
	before_place.add_child(_before)
	_panel(row, "Current").add_child(before_place)
	var right: VBoxContainer = _panel(row, NO_MOD_TITLE)
	_after_caption = right.get_node("Title") as Label
	_after_place = Panel.new()
	var empty: StyleBoxFlat = StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0.25)
	empty.border_color = BORDER
	empty.set_border_width_all(1)
	empty.set_corner_radius_all(roundi(card_size.x * CardGeometry.CORNER))
	_after_place.add_theme_stylebox_override("panel", empty)
	_after_place.custom_minimum_size = card_size
	right.add_child(_after_place)


## Shows the card as [param mod] would leave it, or the empty place for null.
func _preview(mod: Mod) -> void:
	if mod == _previewed:
		return
	_previewed = mod
	if _after != null:
		_after.queue_free()
		_after = null
	_after_caption.text = NO_MOD_TITLE if mod == null else "With %s" % mod.name
	if mod != null:
		_after = DeckbuilderFace.make(_card.with_mod(mod), FACE_HEIGHT, false)
		_after_place.add_child(_after)


## Draws the buttons the state offers and marks the chosen tile.
func _show_state() -> void:
	for child: Node in _footer.get_children():
		_footer.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_question = null
	for mod: Mod in _tiles:
		var button: Button = _tiles[mod]
		button.disabled = _state == State.CONFIRMING or not mod.is_applicable_to(_card)
		_style_tile(button, mod == _chosen)
	match _state:
		State.CHOOSING:
			_footer.add_child(_line(_label("Click a Mod to select it. Applying a Mod cannot be undone.", 18, MUTED)))
			# Apply keeps its place, gray, until a Mod is clicked.
			_add_button("apply", "Apply", _on_apply)
			_buttons["apply"].disabled = true
			_add_button("close", "Close", _on_close)
		State.CHOSEN:
			_footer.add_child(_line(_label("%s will fill one of this card's Mod Slots." % _chosen.name, 18, MUTED)))
			_add_button("apply", "Apply", _on_apply)
			_add_button("cancel", "Cancel", _on_cancel)
		State.CONFIRMING:
			_question = _label("Are you sure? Applying %s to %s cannot be undone." % [_chosen.name, _card.look().name], 18)
			_footer.add_child(_line(_question))
			_add_button("yes", "Yes, apply it", _on_yes)
			_add_button("no", "No, go back", _on_no)


## Paints a Mod's tile: a darker gray than the other buttons, shaded as they are, and
## ringed while it [param is_chosen].
func _style_tile(button: Button, is_chosen: bool) -> void:
	var fills: Dictionary[String, Color] = {
		"normal": TILE, "hover": TILE.lightened(0.1), "pressed": TILE.darkened(0.15), "disabled": TILE.darkened(0.3),
	}
	for look: String in fills:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = DeckbuilderLook.BUTTON_HOVER if is_chosen else fills[look]
		style.set_corner_radius_all(5)
		style.set_content_margin_all(8)
		DeckbuilderLook.shade(style)
		if is_chosen:
			style.border_color = CHOSEN_RING
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(look, style)


## [param label] made to take the footer's spare width and wrap in it, so that a long line
## never makes the window wider.
func _line(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _add_button(key: String, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 0)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	_footer.add_child(button)
	_buttons[key] = button


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
