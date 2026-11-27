class_name SatchelWindow
extends Control
## The Satchel (game glossary; milestone 24, signed off as prototypes/satchel/): where the Hero
## keeps the Items they hold between encounters, as a window over whatever opened it, which it
## dims. Everything under it, the Run Bar included, takes no clicks while it is open, and a
## click on the dimmed ground or on Close closes it; no key does. It always opens on the Armor
## page, and eases in and out as the encounter's windows do (Pacing.EASE_SECONDS, at the Game
## Speed), without rising into place.
##
## Its three pages, Armor, Mods and Potions, list one entry for each kind of Item held
## (SatchelEntries). Down the left stand the Hero's Portrait, their name and the three Armor
## Slots. A click on an Armor's entry puts it on, in place of whatever was Worn in its slot,
## and a click on a Worn Armor's entry, or on it in its Armor Slot, takes it off, the page
## staying scrolled where it was. A right-click on a Worn Armor in its Armor Slot opens the
## Armor page, glides the list to its entry and lights it for a moment. Entries on the other
## pages take no clicks. Nothing is dragged and nothing is confirmed, since nothing is final.
## The run is changed only through what it holds (HeldArmor), which logs each change.
##
## Barred Armor Slots wait for Statuses (milestone 33), and selling from the Satchel for the
## Store (milestone 24) and the Workshop (milestone 25).

## Closed, by Close or by a click on the dimmed ground.
signal closed

## Opens the Stage Map of a debug run with the Satchel open (S15), with --run-seed=N,
## --stage=red and --tier=N as --stage-map takes them, and --screenshot=.
const FLAG: String = "--satchel"
const Page := SatchelEntries.Page
const TITLE: String = "Satchel"
const CLOSE: String = "Close"

## How long it eases in and out, glides to an entry shown from its Armor Slot and keeps that
## entry lit: none until use_pace() gives the Game Speed's, so a test sees everything at once.
var ease_seconds: float = 0.0
var glide_seconds: float = 0.0
var light_seconds: float = 0.0

var _run: Run = null
var _page: Page = Page.ARMOR
## The dimmed ground and the window, while it is open; null while it is closed.
var _screen: Control = null
var _window: Panel = null
var _worn_column: Control = null
var _page_panel: Control = null
var _tab_nodes: Array[Control] = []
var _tabs: Dictionary[Page, Button] = {}
var _close: Button = null
var _scroll: ScrollContainer = null
var _empty: Label = null
var _hero_name: Label = null
var _hero_portrait: TextureRect = null
## What the open page lists, and the nodes drawn for each entry, by its name.
var _entries: Array[SatchelEntry] = []
var _entry_nodes: Dictionary[String, PanelContainer] = {}
var _pictures: Dictionary[String, Control] = {}
var _stars: Dictionary[String, Control] = {}
var _texts: Dictionary[String, Array] = {}
## Each Armor Slot as drawn, its picture, and the Armor Worn there, if any.
var _slot_nodes: Dictionary[Armor.Slot, Control] = {}
var _slot_pictures: Dictionary[Armor.Slot, TextureRect] = {}
var _slot_armor: Dictionary[Armor.Slot, Armor] = {}


## A closed Satchel of [param run]'s, laid over everything on [param host].
static func over(host: Control, run: Run) -> SatchelWindow:
	var made: SatchelWindow = SatchelWindow.new()
	made._run = run
	host.add_child(made)
	return made


func _init() -> void:
	name = "Satchel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Eases at [param speed]'s pace when [param is_paced], and at once when not.
func use_pace(is_paced: bool, speed: GameSpeed.Speed) -> void:
	ease_seconds = GameSpeed.seconds(Pacing.EASE_SECONDS, speed) if is_paced else 0.0
	glide_seconds = GameSpeed.seconds(SatchelLook.GLIDE_SECONDS, speed) if is_paced else 0.0
	light_seconds = GameSpeed.seconds(SatchelLook.LIGHT_SECONDS, speed) if is_paced else 0.0


## Opens the Satchel on the Armor page, easing in.
func open() -> void:
	if is_open():
		return
	_page = Page.ARMOR
	_build()
	Easing.fade_in(_screen, ease_seconds)


## Closes the Satchel, easing out. What is Worn is kept, as the run holds it.
func close() -> void:
	if not is_open():
		return
	var leaving: Control = _screen
	_forget()
	Easing.fade_out_and_free(leaving, ease_seconds)
	closed.emit()


func is_open() -> bool:
	return _screen != null


func page() -> Page:
	return _page


## Opens [param shown]'s page, as its tab does.
func show_page(shown: Page) -> void:
	_page = shown
	_build_page()


## The window itself, or null while closed.
func window() -> Control:
	return _window


func tab(of_page: Page) -> Button:
	return _tabs.get(of_page, null) as Button


func close_button() -> Button:
	return _close


## What the open page lists, in order.
func entries() -> Array[SatchelEntry]:
	return _entries.duplicate()


## The titles of the open page's entries, in order: "Big Gulp ×2".
func titles() -> Array[String]:
	var found: Array[String] = []
	for entry: SatchelEntry in _entries:
		found.append(entry.title())
	return found


## The entry of the open page named [param entry_name], or null.
func entry_of(entry_name: String) -> SatchelEntry:
	for entry: SatchelEntry in _entries:
		if entry.name == entry_name:
			return entry
	return null


## The panel drawn for the entry named [param entry_name], or null.
func entry_node(entry_name: String) -> Control:
	return _entry_nodes.get(entry_name, null) as Control


## The picture on the entry named [param entry_name]: a TextureRect of its Armor Icon, its
## ModIcon or its PotionArt.
func picture_of(entry_name: String) -> Control:
	return _pictures.get(entry_name, null) as Control


## Whether the picture on the entry named [param entry_name] stands on a plate of its own.
func has_plate(entry_name: String) -> bool:
	return picture_of(entry_name) is PotionArt


## The star marking the entry named [param entry_name] as Worn, shown only while it is.
func star_of(entry_name: String) -> Control:
	return _stars.get(entry_name, null) as Control


## The words of the entry named [param entry_name], top to bottom: its title, its type line
## and what it does.
func texts_of(entry_name: String) -> Array[String]:
	var found: Array[String] = []
	found.assign(_texts.get(entry_name, []))
	return found


## What an empty page reads, or "" while it lists something.
func empty_words() -> String:
	return _empty.text if _empty != null else ""


## The open page's scrolling list, or null while it is empty.
func scroll() -> ScrollContainer:
	return _scroll


func hero_name() -> String:
	return _hero_name.text if _hero_name != null else ""


func hero_portrait() -> Texture2D:
	return _hero_portrait.texture if _hero_portrait != null else null


## [param slot] as drawn in the Worn column.
func slot_node(slot: Armor.Slot) -> Control:
	return _slot_nodes.get(slot, null) as Control


## What [param slot] shows: the Armor Icon of what is Worn there, or its faint outline.
func slot_picture(slot: Armor.Slot) -> TextureRect:
	return _slot_pictures.get(slot, null) as TextureRect


## The Armor [param slot] shows as Worn, or null.
func slot_armor(slot: Armor.Slot) -> Armor:
	return _slot_armor.get(slot, null) as Armor


func _forget() -> void:
	_screen = null
	_window = null
	_worn_column = null
	_page_panel = null
	_tab_nodes.clear()
	_tabs.clear()
	_close = null
	_scroll = null
	_empty = null
	_hero_name = null
	_hero_portrait = null
	_entries.clear()
	_entry_nodes.clear()
	_pictures.clear()
	_stars.clear()
	_texts.clear()
	_slot_nodes.clear()
	_slot_pictures.clear()
	_slot_armor.clear()


func _build() -> void:
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	# The dimmed ground: it keeps clicks from whatever is under it, and a click on it closes.
	var dim: ColorRect = ColorRect.new()
	dim.color = SatchelLook.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		var press: InputEventMouseButton = event as InputEventMouseButton
		if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			# Not while the press is being handled: closing frees the dimmed ground.
			close.call_deferred())
	_screen.add_child(dim)
	var at: Vector2 = SatchelLook.window_position()
	var shadow: Panel = Panel.new()
	shadow.position = at
	shadow.size = SatchelLook.WINDOW_SIZE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", SatchelLook.shadow_style())
	_screen.add_child(shadow)
	_window = Panel.new()
	_window.position = at
	_window.size = SatchelLook.WINDOW_SIZE
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_window.add_theme_stylebox_override("panel", SatchelLook.window_style())
	_screen.add_child(_window)
	var stitches: Control = Control.new()
	stitches.size = SatchelLook.WINDOW_SIZE
	stitches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stitches.draw.connect(func() -> void:
		for dot: Vector2 in SatchelLook.stitches():
			stitches.draw_rect(Rect2(dot, Vector2(2, 2)), SatchelLook.STITCH))
	_window.add_child(stitches)
	var flap: TextureRect = _picture(SatchelLook.flap_texture())
	flap.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	flap.position = Vector2(2, 2)
	_window.add_child(flap)
	var title: Label = _text(TITLE, 34, SatchelLook.CREAM, true)
	title.position = Vector2(0, 8)
	title.size = Vector2(SatchelLook.WINDOW_SIZE.x, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 2)
	_window.add_child(title)
	_close = _close_button()
	_window.add_child(_close)
	_build_worn_column()
	_build_page()


## The Worn column: the Hero's Portrait and name, then the three Armor Slots, head to foot.
func _build_worn_column() -> void:
	if _worn_column != null:
		_worn_column.queue_free()
	_slot_nodes.clear()
	_slot_pictures.clear()
	_slot_armor.clear()
	var column: Panel = Panel.new()
	column.position = SatchelLook.WORN_RECT.position
	column.size = SatchelLook.WORN_RECT.size
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_stylebox_override("panel", SatchelLook.set_in_style(SatchelLook.SET_IN, SatchelLook.SET_IN_RADIUS))
	var rows: VBoxContainer = VBoxContainer.new()
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", SatchelLook.WORN_GAP)
	column.add_child(rows)
	var side: float = 32.0 * SatchelLook.PORTRAIT_SCALE
	var frame: Panel = Panel.new()
	frame.custom_minimum_size = Vector2(side + 8, side + 8)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", SatchelLook.set_in_style(SatchelLook.SLOT_GROUND, 6))
	_hero_portrait = _picture(PlayerPortraits.texture_of(MmEncounterSetup.HERO_PLAYER_ID))
	_hero_portrait.position = Vector2(4, 4)
	_hero_portrait.size = Vector2(side, side)
	frame.add_child(_hero_portrait)
	rows.add_child(frame)
	# Until the Hero has a name of their own (milestone 22), they go by their part.
	_hero_name = _text(PlayerNames.new().of(PlayerNames.HERO), 28, SatchelLook.CREAM, true)
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_hero_name)
	for slot: Armor.Slot in Armor.Slot.values():
		var made: Control = _armor_slot(slot, _run.held_armor.worn_in(slot))
		made.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rows.add_child(made)
	_worn_column = column
	_window.add_child(column)


## An Armor Slot: the Armor Worn there, its icon on the slot's dark square, or the faint
## outline of its kind.
func _armor_slot(slot: Armor.Slot, worn: Armor) -> Control:
	var tile: Panel = Panel.new()
	tile.custom_minimum_size = Vector2(SatchelLook.TILE_SIDE, SatchelLook.TILE_SIDE)
	tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile.add_theme_stylebox_override("panel", SatchelLook.set_in_style(SatchelLook.SLOT_GROUND, 0))
	var picture: TextureRect = _picture(worn.icon if worn != null else SatchelLook.slot_outline(slot))
	picture.position = Vector2(SatchelLook.ICON_SCALE, SatchelLook.ICON_SCALE)
	picture.size = Vector2(SatchelLook.ICON_SIDE, SatchelLook.ICON_SIDE)
	tile.add_child(picture)
	_slot_nodes[slot] = tile
	_slot_pictures[slot] = picture
	if worn == null:
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tile
	_slot_armor[slot] = worn
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.gui_input.connect(func(event: InputEvent) -> void:
		var press: InputEventMouseButton = event as InputEventMouseButton
		if press == null or not press.pressed:
			return
		if press.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_run.held_armor.take_off(slot)
			_show_worn.call_deferred()
		elif press.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			_show_entry(worn))
	return tile


## The open page, its tabs over it: its entries in a scrolling list, or its "No … held." line.
func _build_page() -> void:
	if _page_panel != null:
		_page_panel.queue_free()
	for node: Control in _tab_nodes:
		node.queue_free()
	_tab_nodes.clear()
	_tabs.clear()
	_scroll = null
	_empty = null
	_entry_nodes.clear()
	_pictures.clear()
	_stars.clear()
	_texts.clear()
	_entries = SatchelEntries.of(_run, _page)
	var panel: Panel = Panel.new()
	panel.position = SatchelLook.PAGE_RECT.position
	panel.size = SatchelLook.PAGE_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The tabs cover its whole top, so its top corners are square.
	var ground: StyleBoxFlat = SatchelLook.set_in_style(SatchelLook.SET_IN, SatchelLook.SET_IN_RADIUS)
	ground.corner_radius_top_left = 0
	ground.corner_radius_top_right = 0
	panel.add_theme_stylebox_override("panel", ground)
	_page_panel = panel
	_window.add_child(panel)
	_add_tabs()
	if _entries.is_empty():
		_empty = _text(SatchelEntries.EMPTY_WORDS[_page], 26, SatchelLook.CREAM_MUTED, false)
		_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
		_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(_empty)
		return
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(SatchelLook.PAGE_PADDING, SatchelLook.PAGE_PADDING)
	_scroll.size = SatchelLook.PAGE_RECT.size - Vector2(SatchelLook.PAGE_PADDING, SatchelLook.PAGE_PADDING) * 2.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(SatchelLook.SCROLL_WIDTH, 0)
	bar.add_theme_stylebox_override("scroll", SatchelLook.flat(SatchelLook.SLOT_GROUND, SatchelLook.SCROLL_WIDTH / 2))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, SatchelLook.flat(
			SatchelLook.STITCH.darkened(0.25 if state == "grabber" else 0.1), SatchelLook.SCROLL_WIDTH / 2))
	panel.add_child(_scroll)
	var room: MarginContainer = MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_theme_constant_override("margin_right", SatchelLook.SCROLL_ROOM)
	_scroll.add_child(room)
	var list: VBoxContainer = VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override("separation", SatchelLook.ENTRY_GAP)
	room.add_child(list)
	for entry: SatchelEntry in _entries:
		var made: PanelContainer = _entry_panel(entry)
		list.add_child(made)
		_ignore_mouse_below(made)
		if entry.takes_clicks():
			_make_clickable(made, entry)


func _add_tabs() -> void:
	var spans: Array[Vector2i] = SatchelLook.tab_spans(SatchelEntries.PAGES.size(), SatchelLook.PAGE_RECT.size.x - 2.0)
	# The open tab is added last, so that its feet lie over its neighbors'.
	var order: Array[int] = []
	for index: int in SatchelEntries.PAGES.size():
		if SatchelEntries.PAGES[index] != _page:
			order.append(index)
	order.append(SatchelEntries.PAGES.find(_page))
	for index: int in order:
		var shown: Page = SatchelEntries.PAGES[index]
		var is_open_tab: bool = shown == _page
		var left: int = spans[index].x
		var width: int = spans[index].y
		var height: int = SatchelLook.TAB_HEIGHT if is_open_tab else SatchelLook.TAB_HEIGHT - SatchelLook.TAB_LOW
		var button: Button = Button.new()
		button.text = SatchelEntries.PAGE_NAMES[shown]
		button.position = SatchelLook.PAGE_RECT.position + Vector2(left, -height)
		button.size = Vector2(width, height)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", UiText.bold())
		button.add_theme_font_size_override("font_size", 24)
		for state: String in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for state: String in ["font_color", "font_pressed_color"]:
			button.add_theme_color_override(state, SatchelLook.CREAM if is_open_tab else SatchelLook.CREAM_MUTED)
		for state: String in ["font_hover_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, SatchelLook.CREAM)
		# Its face is drawn behind its name, and goes with it. The open tab's last two rows lie
		# over the page's top edge; another tab's own edge does.
		var face: TextureRect = _picture(SatchelLook.tab_texture(width, height, is_open_tab, index > 0,
			index < SatchelEntries.PAGES.size() - 1))
		face.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		face.show_behind_parent = true
		face.position = Vector2(-SatchelLook.TAB_FLARE, 0.0 if is_open_tab else 2.0)
		button.add_child(face)
		if not is_open_tab:
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.mouse_entered.connect(button.set_modulate.bind(SatchelLook.HOVER))
			button.mouse_exited.connect(button.set_modulate.bind(Color.WHITE))
		button.pressed.connect(show_page.bind(shown))
		_window.add_child(button)
		_tab_nodes.append(button)
		_tabs[shown] = button
	# The window's other parts stay over the tabs' faces.
	_window.move_child(_close, -1)


## An entry: its picture, its name and count with the Worn star on the Armor page, its type
## line, and what it does, on parchment as tall as its words need.
func _entry_panel(entry: SatchelEntry) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", SatchelLook.paper_style(0))
	panel.resized.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", SatchelLook.paper_style(int(panel.size.y))))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var picture: Control = _picture_of(entry)
	var tile: Control = Control.new()
	tile.custom_minimum_size = Vector2(SatchelLook.TILE_SIDE, SatchelLook.TILE_SIDE)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.add_child(picture)
	row.add_child(tile)
	_pictures[entry.name] = picture
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	var heading: HBoxContainer = HBoxContainer.new()
	column.add_child(heading)
	var title: Label = _text(entry.title(), 26, SatchelLook.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var texts: Array[String] = [entry.title(), entry.type_line]
	if entry.armor != null:
		var star: TextureRect = _picture(load(SatchelLook.STAR) as Texture2D)
		star.custom_minimum_size = Vector2(11, 11) * SatchelLook.STAR_SCALE
		star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		star.visible = entry.is_worn
		heading.add_child(star)
		_stars[entry.name] = star
	column.add_child(_text(entry.type_line, 20, SatchelLook.INK_MUTED, false))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	column.add_child(gap)
	for line: String in entry.lines:
		var words: SymbolLabel = SymbolLabel.new()
		words.set_font_size(20)
		words.write_in(line, SatchelLook.INK)
		column.add_child(words)
		texts.append(line)
	_entry_nodes[entry.name] = panel
	_texts[entry.name] = texts
	return panel


## [param entry]'s picture: an Armor Icon bare on the parchment, a Mod Icon in its Rarity's
## color, still, or a Potion Icon on its Rarity's plate (ADR 0033).
func _picture_of(entry: SatchelEntry) -> Control:
	if entry.potion != null:
		return PotionArt.new(entry.potion.resource_path.get_file().get_basename(), SatchelLook.TILE_SIDE, false,
			entry.potion.rarity)
	var picture: TextureRect
	if entry.mod != null:
		picture = ModIcon.still(entry.mod.rarity)
	else:
		picture = _picture(entry.armor.icon)
	picture.position = Vector2(SatchelLook.ICON_SCALE, SatchelLook.ICON_SCALE)
	picture.size = Vector2(SatchelLook.ICON_SIDE, SatchelLook.ICON_SIDE)
	return picture


## Lets a click on [param panel] put [param entry]'s Armor on, or take it off if it is Worn.
## The parchment lightens under the cursor, which becomes a pointing hand.
func _make_clickable(panel: PanelContainer, entry: SatchelEntry) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.mouse_entered.connect(panel.set_self_modulate.bind(SatchelLook.HOVER))
	panel.mouse_exited.connect(panel.set_self_modulate.bind(Color.WHITE))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var press: InputEventMouseButton = event as InputEventMouseButton
		if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if _run.held_armor.is_worn(entry.armor):
			_run.held_armor.take_off(entry.armor.slot)
		else:
			_run.held_armor.put_on(entry.armor)
		_show_worn.call_deferred())


## Shows what is Worn now without building the page again, so it stays scrolled where it was:
## each entry's star, and the Worn column.
func _show_worn() -> void:
	if not is_open():
		return
	for entry: SatchelEntry in _entries:
		if entry.armor == null:
			continue
		entry.is_worn = _run.held_armor.is_worn(entry.armor)
		if _stars.has(entry.name):
			_stars[entry.name].visible = entry.is_worn
	_build_worn_column()


## Opens the Armor page if another is open, glides the list to [param armor]'s entry, at the
## top where the list is long enough, and lights that entry for a moment.
func _show_entry(armor: Armor) -> void:
	if _page != Page.ARMOR:
		show_page(Page.ARMOR)
	# The list is laid out a frame after it is built.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_open() or _scroll == null or not _entry_nodes.has(armor.name):
		return
	var entry: Control = _entry_nodes[armor.name]
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	var to: int = int(clampf(entry.position.y, 0.0, maxf(0.0, bar.max_value - bar.page)))
	if glide_seconds <= 0.0:
		_scroll.scroll_vertical = to
	else:
		_scroll.create_tween().tween_property(_scroll, "scroll_vertical", to, glide_seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if light_seconds > 0.0:
		entry.modulate = SatchelLook.LIGHT
		entry.create_tween().tween_property(entry, "modulate", Color.WHITE, light_seconds)


func _close_button() -> Button:
	var button: Button = Button.new()
	button.text = CLOSE
	button.position = SatchelLook.CLOSE_RECT.position
	button.size = SatchelLook.CLOSE_RECT.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UiText.bold())
	button.add_theme_font_size_override("font_size", 26)
	SteelFrame.frame_roomy(button, SatchelLook.CLOSE_FILL, int(SatchelLook.CLOSE_RECT.size.y))
	button.pressed.connect(close, CONNECT_DEFERRED)
	return button


## Makes everything inside [param node], but not [param node] itself, deaf to the mouse, so a
## click anywhere on an entry is the entry's. A wheel still scrolls the list.
func _ignore_mouse_below(node: Node) -> void:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_below(child)


func _picture(texture: Texture2D) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = texture
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _text(text: String, font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	return made
