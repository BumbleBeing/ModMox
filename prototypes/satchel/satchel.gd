extends Control
## PROTOTYPE (milestone 24, step 3 of 3): the Satchel window's layout and its clicks (steps
## 1 and 2, signed off), and opening and closing it over the Stage Map of a debug run. Throwaway: deleted after sign-off, once the real window is ported
## test-first. Nothing here changes a run: the Items are samples made in this file.
##
## godot --path . res://prototypes/satchel/satchel.tscn -- --run-seed=7 --stage=white
## Keys or the bar at the bottom: 1, 2, 3 (or a click on a tab) open the Armor, Mods and
## Potions pages; F steps through a full, a sparse and an empty Satchel; B bars the Greaves
## and Boots Armor Slots, as a Status of Urza's might; I steps through the grounds an icon
## can be drawn on, and W shows them all on one sheet. --page=mods, --fill=sparse, --barred,
## --ground=c and --sheet start it that way, --scroll=200 starts the page scrolled that many pixels, and
## --screenshot=/absolute/path.png saves a picture and quits.
##
## Step 2, the clicks: a click on an Armor's entry puts it on, in place of whatever was Worn
## in its Armor Slot, and a click on a Worn Armor's entry, or on it in its Armor Slot, takes
## it off. A right-click on a Worn Armor in its Armor Slot opens the Armor page, scrolls to
## its entry and lights it for a moment. Entries on the other pages, and an Armor's whose
## Armor Slot is Barred, take no clicks.
##
## Step 3, opening and closing: the Satchel starts closed (--open starts it open). The Run
## Bar's Satchel button opens it, always on the Armor page, and Close or a click on the
## dimmed ground closes it; what is Worn is kept. It eases in and out as the encounter's
## windows do (Pacing.EASE_SECONDS, at the Game Speed in the settings). The Stage Map under
## it is the real one, but arriving at a Node opens nothing here.
##
## To drive it for a picture: --click-entry="Seer's Helm", --click-slot=helm and
## --right-slot=boots make that click with a real mouse event before the picture is saved,
## as --click-satchel, --click-close and --click-ground do.

enum Page { ARMOR, MODS, POTIONS }
enum Fill { FULL, SPARSE, EMPTY }
enum Slot { HELM, GREAVES, BOOTS }
## PROTOTYPE: what an Armor Icon or a Potion Icon is drawn on, to choose between.
enum Ground { BEIGE_CIRCLE, BARE, DARK_WELL, LEATHER_PLATE, MEDALLION, PAPER_WELL, RARITY_WELL, RARITY_PLATE }

const Icons: GDScript = preload("res://prototypes/satchel/satchel_icons.gd")
const STAGE_MAP: String = "res://ui/stage_map/stage_map_screen.tscn"
const SCREEN: Vector2 = Vector2(1920, 1080)
const DIM: Color = Color(0, 0, 0, 0.6)
const WINDOW_SIZE: Vector2 = Vector2(1200, 800)
const WINDOW_RADIUS: int = 24
const MARGIN: float = 24.0
## The window's leather, its near-black edge, and the darker leather of what is set into it:
## the Worn column and the page.
const LEATHER: Color = Color("#6b4a30")
const EDGE: Color = Color("#1c120b")
const SET_IN: Color = Color("#3f2a1b")
const SLOT_GROUND: Color = Color("#2c1d12")
const STITCH: Color = Color("#d9b98a")
const CREAM: Color = Color("#f0e6d2")
const CREAM_MUTED: Color = Color("#c9b89a")
## The flap across the top: as tall as FLAP_SIDE at its ends and FLAP_DROP more in the middle.
const FLAP: Color = Color("#7d5636")
const FLAP_SIDE: float = 58.0
const FLAP_DROP: float = 22.0
const FLAP_HEIGHT: int = 84
## The Spoils screen's parchment, for each entry.
const PAPER: Color = Color("#e9dcbc")
const PAPER_EDGE: Color = Color("#7a6243")
const PAPER_LIGHTEN: float = 0.08
const PAPER_DARKEN: float = 0.15
const PAPER_RADIUS: int = 14
const PAPER_EDGE_WIDTH: int = 2
const PAPER_PADDING: Vector2 = Vector2(16, 12)
const INK: Color = Color8(46, 40, 36)
const INK_MUTED: Color = Color8(108, 96, 84)
## The square an Armor Icon or a Potion Icon is drawn on, and the circle behind it (ADR 0033).
const BEIGE: Color = Color("#e6dcbd")
const CIRCLE: Color = Color("#a8926f")
## A 32 × 32 icon is drawn at three times its size, in an entry and in an Armor Slot.
const ICON_SCALE: int = 3
const PORTRAIT_SCALE: int = 5
const STAR_SCALE: int = 3
const SET_IN_RADIUS: int = 14
const WORN_RECT: Rect2 = Rect2(24, 104, 248, 672)
## The tabs share the page's whole top. The open one stands TAB_HEIGHT above the page, is
## the page's own color, and widens by TAB_FLARE at each foot where it runs into the page;
## the others are TAB_LOW shorter.
const TAB_HEIGHT: int = 48
const TAB_LOW: int = 6
const TAB_FLARE: int = 10
const TAB_RADIUS: int = 12
const PAGE_RECT: Rect2 = Rect2(296, 156, 880, 544)
const PAGE_PADDING: float = 12.0
const ENTRY_GAP: int = 12
const CLOSE_RECT: Rect2 = Rect2(1016, 716, 160, 60)
const CLOSE_FILL: Color = Color("#8a6238")
const BUTTON_RADIUS: int = 12
const HERO_NAME: String = "Urza"
const PAGE_NAMES: Dictionary[Page, String] = { Page.ARMOR: "Armor", Page.MODS: "Mods", Page.POTIONS: "Potions" }
const EMPTY_WORDS: Dictionary[Page, String] = {
	Page.ARMOR: "No Armor held.", Page.MODS: "No Mods held.", Page.POTIONS: "No Potions held.",
}
const GROUND_NAMES: Dictionary[Ground, String] = {
	Ground.BEIGE_CIRCLE: "A, beige square and circle (as it was)", Ground.BARE: "B, bare on the parchment",
	Ground.DARK_WELL: "C, dark well", Ground.LEATHER_PLATE: "D, leather",
	Ground.MEDALLION: "E, dark medallion", Ground.PAPER_WELL: "F, paper well",
	Ground.RARITY_WELL: "G, well, Rarity edge", Ground.RARITY_PLATE: "H, Rarity plate",
}
## The color an icon's plate takes from its Item. A Potion's is its Rarity's: the
## Inspector's gray, silver and gold, and sienna for Mythic (the Inspector's Mythic glow is
## honey, #e89a2b). A Unique Item's is light purple. An Armor Icon has no plate at all
## (ARMOR_TINT is only what the sheet's other grounds show an Armor on).
const ARMOR_TINT: Color = Color("#a0522d")
const UNIQUE_TINT: Color = Color("#c8a8e6")
const RARITY_TINTS: Dictionary[MmCardDefinition.Rarity, Color] = {
	MmCardDefinition.Rarity.COMMON: Color("#8a8f98"), MmCardDefinition.Rarity.UNCOMMON: Color("#d5dbe3"),
	MmCardDefinition.Rarity.RARE: Color("#f2c744"), MmCardDefinition.Rarity.MYTHIC: Color("#a0522d"),
}
## The Rarity edge is one of the icon's own pixels wide.
const RARITY_EDGE: int = 3
const FILL_NAMES: Dictionary[Fill, String] = { Fill.FULL: "full", Fill.SPARSE: "sparse", Fill.EMPTY: "empty" }
const SLOT_NAMES: Dictionary[Slot, String] = { Slot.HELM: "Helm", Slot.GREAVES: "Greaves", Slot.BOOTS: "Boots" }
const MOD_RARITY_NAMES: Dictionary[Mod.Rarity, String] = {
	Mod.Rarity.COMMON: "Common", Mod.Rarity.UNCOMMON: "Uncommon", Mod.Rarity.RARE: "Rare",
	Mod.Rarity.MYTHIC: "Mythic", Mod.Rarity.UNIQUE: "Unique",
}
const LIFE_WORDS: String = "You start each encounter with %d more life."
const EMBLEM_WORDS: String = "You start each encounter with this Emblem:"
const DIVINERS_BOON: String = "res://content/emblems/diviners_boon.tres"
const ELECTROMANCERS_BOON: String = "res://content/emblems/electromancers_boon.tres"
const BIG_GULP: String = "res://content/potions/big_gulp.tres"


## One entry of a page: a kind of Item held, and how many.
class Item extends RefCounted:
	var name: String = ""
	var count: int = 1
	var type_line: String = ""
	## What it does, a sentence to a line.
	var words: Array[String] = []
	## The Emblem an Armor brings, written under its words, or null.
	var emblem: MmCardDefinition = null
	## Its Armor Icon or Potion Icon; null for a Mod, which has no picture.
	var icon: Texture2D = null
	## An Armor's Armor Slot.
	var slot: Slot = Slot.HELM
	## A Mod's or a Potion's Rarity, as a number that sorts.
	var rarity: int = 0
	var is_worn: bool = false
	## An Armor Icon has no ground of its own; a Potion Icon stands on its Rarity's plate.
	var is_armor: bool = false
	## The color its icon's ground takes: brown for an Armor, its Rarity's for a Potion.
	var tint: Color = Color("#a0522d")


var _page: Page = Page.ARMOR
var _fill: Fill = Fill.FULL
var _is_barred: bool = false
## The plate in the Item's color was chosen; I still steps through the others.
var _ground: Ground = Ground.RARITY_PLATE
var _is_sheet: bool = false
var _start_scroll: int = 0
var _screen: Control = null
var _scroll: ScrollContainer = null
var _is_open: bool = false
## How long the Satchel takes to ease in or out; none while a picture is being made.
var _ease_seconds: float = 0.0
var _map: StageMapScreen = null
var _bar_layer: Control = null
var _close_node: Button = null
## The name of the Armor Worn in each Armor Slot; a slot with none is not in it.
var _worn: Dictionary[Slot, String] = { Slot.HELM: "Lionguard Helm", Slot.BOOTS: "Thornwalker Boots" }
var _armor: Array[Item] = []
var _window: Control = null
var _worn_node: Control = null
## What a click changes without the window being built again: each Armor entry and its
## star, by the Armor's name, and each Armor Slot.
var _entries: Dictionary[String, Control] = {}
var _stars: Dictionary[String, Control] = {}
var _slot_nodes: Dictionary[Slot, Control] = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument.begins_with("--page="):
			for page: Page in PAGE_NAMES:
				if PAGE_NAMES[page].to_lower() == argument.trim_prefix("--page=").to_lower():
					_page = page
		elif argument.begins_with("--fill="):
			for fill: Fill in FILL_NAMES:
				if FILL_NAMES[fill] == argument.trim_prefix("--fill=").to_lower():
					_fill = fill
		elif argument.begins_with("--scroll="):
			_start_scroll = int(argument.trim_prefix("--scroll="))
		elif argument.begins_with("--ground="):
			_ground = clampi("abcdefgh".find(argument.trim_prefix("--ground=").to_lower()), 0, Ground.size() - 1) as Ground
		elif argument == "--sheet":
			_is_sheet = true
		elif argument == "--barred":
			_is_barred = true
		elif argument == "--open":
			_is_open = true
	var picture: String = EncounterScreen.screenshot_path(arguments)
	if picture == "":
		_ease_seconds = GameSpeed.seconds(Pacing.EASE_SECONDS, GameSettings.load_from(GameSettings.PATH).game_speed)
	_is_open = _is_open or _is_sheet
	_map = (load(STAGE_MAP) as PackedScene).instantiate() as StageMapScreen
	_map.starts_itself = false
	# Arriving at a Node opens nothing here, and neither does the Deckbox button.
	_map.navigate = func(_scene: String) -> void: pass
	add_child(_map)
	_map.begin(StageMapScreen.debug_run_from(arguments))
	_map.run_bar().button(RunBar.SATCHEL).pressed.connect(_open)
	_rebuild()
	for argument: String in arguments:
		for frame: int in 3:
			await get_tree().process_frame
		if argument.begins_with("--click-entry=") and _entries.has(argument.trim_prefix("--click-entry=")):
			_click_at(_entries[argument.trim_prefix("--click-entry=")].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		for slot: Slot in SLOT_NAMES:
			if argument == "--click-slot=" + SLOT_NAMES[slot].to_lower():
				_click_at(_slot_nodes[slot].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
			elif argument == "--right-slot=" + SLOT_NAMES[slot].to_lower():
				_click_at(_slot_nodes[slot].get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
				await get_tree().create_timer(0.5).timeout
		if argument == "--click-satchel":
			_click_at(_map.run_bar().button(RunBar.SATCHEL).get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		elif argument == "--click-close" and _close_node != null:
			_click_at(_close_node.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		elif argument == "--click-ground":
			_click_at(Vector2(120, 620), MOUSE_BUTTON_LEFT)
	if picture != "":
		for frame: int in 6:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_page = Page.ARMOR
		KEY_2:
			_page = Page.MODS
		KEY_3:
			_page = Page.POTIONS
		KEY_F:
			_fill = ((_fill + 1) % Fill.size()) as Fill
		KEY_B:
			_is_barred = not _is_barred
		KEY_I:
			_ground = ((_ground + 1) % Ground.size()) as Ground
		KEY_W:
			_is_sheet = not _is_sheet
			_is_open = _is_open or _is_sheet
		_:
			return
	_rebuild()


## Opens the Satchel, always on the Armor page, easing in.
func _open() -> void:
	if _is_open:
		return
	_is_open = true
	_page = Page.ARMOR
	_rebuild()
	Easing.fade_in(_screen, _ease_seconds)


## Closes the Satchel, easing out. What is Worn is kept.
func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	_is_sheet = false
	var leaving: Control = _screen
	_screen = null
	_close_node = null
	Easing.fade_out_and_free(leaving, _ease_seconds)
	_rebuild()


func _rebuild() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null
	if _bar_layer != null:
		_bar_layer.queue_free()
	if _is_open:
		_screen = Control.new()
		_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_screen)
		# The dimmed ground: it keeps clicks from the Stage Map, and a click on it closes.
		var dim: ColorRect = ColorRect.new()
		dim.color = DIM
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		dim.gui_input.connect(func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				_close())
		_screen.add_child(dim)
		if _is_sheet:
			_add_icon_sheet()
		else:
			_armor = _sample_armor()
			_add_window(_armor)
	_bar_layer = Control.new()
	_bar_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_layer)
	_add_prototype_bar()
	if _start_scroll > 0 and _is_open and _scroll != null:
		await get_tree().process_frame
		await get_tree().process_frame
		_scroll.scroll_vertical = _start_scroll


func _add_window(armor: Array[Item]) -> void:
	var at: Vector2 = ((SCREEN - WINDOW_SIZE) / 2.0).floor()
	var shadow: Panel = Panel.new()
	shadow.position = at
	shadow.size = WINDOW_SIZE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cast: StyleBoxFlat = StyleBoxFlat.new()
	cast.bg_color = Color(0, 0, 0, 0)
	cast.set_corner_radius_all(WINDOW_RADIUS)
	cast.shadow_color = Color(0, 0, 0, 0.55)
	cast.shadow_size = 24
	cast.shadow_offset = Vector2(0, 10)
	shadow.add_theme_stylebox_override("panel", cast)
	_screen.add_child(shadow)

	var window: Panel = Panel.new()
	window.position = at
	window.size = WINDOW_SIZE
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.add_theme_stylebox_override("panel", DitherShading.plate(LEATHER.lightened(0.06), LEATHER.darkened(0.3),
			EDGE, WINDOW_RADIUS, 2, 0, int(WINDOW_SIZE.y)))
	_screen.add_child(window)
	_window = window

	var stitches: Control = Control.new()
	stitches.size = WINDOW_SIZE
	stitches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stitches.draw.connect(func() -> void: _draw_stitches(stitches))
	window.add_child(stitches)

	var flap: TextureRect = TextureRect.new()
	flap.texture = _flap_texture()
	flap.position = Vector2(2, 2)
	flap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(flap)
	var title: Label = _text("Satchel", 34, CREAM, true)
	title.position = Vector2(0, 8)
	title.size = Vector2(WINDOW_SIZE.x, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 2)
	window.add_child(title)

	_worn_node = _worn_column(armor)
	window.add_child(_worn_node)
	window.add_child(_page_panel(armor))
	_add_tabs(window)
	window.add_child(_close_button())


## The Worn column: the Hero's Portrait and name, then the three Armor Slots, head to foot.
func _worn_column(armor: Array[Item]) -> Control:
	var column: Panel = Panel.new()
	column.position = WORN_RECT.position
	column.size = WORN_RECT.size
	column.add_theme_stylebox_override("panel", _set_in_style(SET_IN, SET_IN_RADIUS))
	var rows: VBoxContainer = VBoxContainer.new()
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 14)
	column.add_child(rows)

	var portrait_side: float = 32.0 * PORTRAIT_SCALE
	var frame: Panel = Panel.new()
	frame.custom_minimum_size = Vector2(portrait_side + 8, portrait_side + 8)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _set_in_style(SLOT_GROUND, 6))
	var portrait: TextureRect = _picture(PlayerPortraits.texture_of(MmEncounterSetup.HERO_PLAYER_ID))
	portrait.position = Vector2(4, 4)
	portrait.size = Vector2(portrait_side, portrait_side)
	frame.add_child(portrait)
	rows.add_child(frame)
	var hero_name: Label = _text(HERO_NAME, 28, CREAM, true)
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(hero_name)

	for slot: Slot in [Slot.HELM, Slot.GREAVES, Slot.BOOTS]:
		var worn: Item = null
		for item: Item in armor:
			if item.is_worn and item.slot == slot:
				worn = item
		var made: Control = _armor_slot(slot, worn)
		made.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_slot_nodes[slot] = made
		rows.add_child(made)
	return column


## An Armor Slot: the Armor Worn there on its tile, or the faint outline of its kind on a
## dark ground, under a red X when the slot is Barred.
func _armor_slot(slot: Slot, worn: Item) -> Control:
	if worn != null:
		# An Armor Icon has no ground: in its Armor Slot it is on the slot's own dark square.
		var tile: Control = _icon_tile(worn.icon, Ground.BARE, true, worn.tint)
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.gui_input.connect(func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			if click == null or not click.pressed:
				return
			if click.button_index == MOUSE_BUTTON_LEFT:
				_worn.erase(slot)
				_refresh_worn()
			elif click.button_index == MOUSE_BUTTON_RIGHT:
				_show_entry(worn.name))
		return tile
	var side: float = float(Icons.SIZE * ICON_SCALE)
	var frame: Panel = Panel.new()
	frame.custom_minimum_size = Vector2(side + 4, side + 4)
	frame.add_theme_stylebox_override("panel", _set_in_style(SLOT_GROUND, 0))
	var plain: Texture2D
	match slot:
		Slot.HELM:
			plain = Icons.helm(Icons.IRON, Icons.IRON)
		Slot.GREAVES:
			plain = Icons.greaves(Icons.IRON, Icons.IRON)
		_:
			plain = Icons.boots(Icons.IRON, Icons.IRON)
	var outline: TextureRect = _picture(Icons.ghost(plain, STITCH))
	outline.position = Vector2(2, 2)
	outline.size = Vector2(side, side)
	frame.add_child(outline)
	if _is_slot_barred(slot):
		var cross: TextureRect = _picture(Icons.barred())
		cross.position = Vector2(2, 2)
		cross.size = Vector2(side, side)
		frame.add_child(cross)
	return frame


func _add_tabs(window: Control) -> void:
	var pages: Array[Page] = [Page.ARMOR, Page.MODS, Page.POTIONS]
	var across: float = PAGE_RECT.size.x - 2.0
	# The open tab is added last, so that its feet lie over its neighbors'.
	var order: Array[int] = [0, 1, 2]
	order.erase(pages.find(_page))
	order.append(pages.find(_page))
	for index: int in order:
		var page: Page = pages[index]
		var is_open: bool = page == _page
		# Each tab shares its 2-pixel edge with the next.
		var left: int = roundi(index * across / pages.size())
		var width: int = roundi((index + 1) * across / pages.size()) + 2 - left
		var height: int = TAB_HEIGHT if is_open else TAB_HEIGHT - TAB_LOW
		var face: TextureRect = TextureRect.new()
		face.texture = _tab_texture(width, height, is_open, index > 0, index < pages.size() - 1)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The open tab's last two rows lie over the page's top edge; another tab's own edge does.
		face.position = PAGE_RECT.position + Vector2(left - TAB_FLARE, -height if is_open else 2 - height)
		window.add_child(face)
		var tab: Button = Button.new()
		tab.text = PAGE_NAMES[page]
		tab.position = PAGE_RECT.position + Vector2(left, -height)
		tab.size = Vector2(width, height)
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_override("font", UiText.bold())
		tab.add_theme_font_size_override("font_size", 24)
		for state: String in ["normal", "pressed", "hover", "hover_pressed"]:
			tab.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for state: String in ["font_color", "font_pressed_color"]:
			tab.add_theme_color_override(state, CREAM if is_open else CREAM_MUTED)
		for state: String in ["font_hover_color", "font_hover_pressed_color"]:
			tab.add_theme_color_override(state, CREAM)
		if not is_open:
			tab.mouse_entered.connect(func() -> void: face.modulate = Color(1.2, 1.2, 1.2))
			tab.mouse_exited.connect(func() -> void: face.modulate = Color.WHITE)
		tab.pressed.connect(func() -> void:
			_page = page
			_rebuild())
		window.add_child(tab)


## A tab's face, TAB_FLARE wider than the tab at each side. The open one is the page's own
## flat color with no edge along its foot, and widens there in a curve on each side that
## [param flares_left] and [param flares_right] allow (an end tab runs straight down into
## the page's side). Another tab is darker leather in Dither Shading, edged all round.
func _tab_texture(width: int, height: int, is_open: bool, flares_left: bool, flares_right: bool) -> Texture2D:
	var image: Image = Image.create(width + TAB_FLARE * 2, height + 2, false, Image.FORMAT_RGBA8)
	var top: Color = LEATHER.darkened(0.1)
	var bottom: Color = LEATHER.darkened(0.42)
	var near: Array[Vector2i] = [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-1, -1),
			Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for y: int in image.get_height():
		for x: int in image.get_width():
			if not _is_in_tab(x, y, width, height, is_open, flares_left, flares_right):
				continue
			var color: Color = SET_IN if is_open else DitherShading.band_color(x, y, height, top, bottom)
			for step: Vector2i in near:
				if not _is_in_tab(x + step.x, y + step.y, width, height, is_open, flares_left, flares_right):
					color = EDGE
					break
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## Whether the pixel at [param x], [param y] of a tab's face is part of the tab.
func _is_in_tab(x: int, y: int, width: int, height: int, is_open: bool, flares_left: bool, flares_right: bool) -> bool:
	var left: int = TAB_FLARE
	var right: int = TAB_FLARE + width
	if y < 0:
		return false
	if y >= height:
		# Below its foot the open tab is the page, as wide as its feet.
		return is_open and x >= (0 if flares_left else left) and x < (right + TAB_FLARE if flares_right else right)
	if x >= left and x < right:
		if y < TAB_RADIUS and x < left + TAB_RADIUS:
			return Vector2(x + 0.5 - (left + TAB_RADIUS), y + 0.5 - TAB_RADIUS).length() <= TAB_RADIUS
		if y < TAB_RADIUS and x >= right - TAB_RADIUS:
			return Vector2(x + 0.5 - (right - TAB_RADIUS), y + 0.5 - TAB_RADIUS).length() <= TAB_RADIUS
		return true
	if not is_open or y < height - TAB_FLARE:
		return false
	# A foot: what is left of a square when a circle is cut from its outer top corner.
	if x < left:
		return flares_left and x >= 0 and Vector2(x + 0.5, y + 0.5 - (height - TAB_FLARE)).length() >= TAB_FLARE
	return flares_right and x < right + TAB_FLARE \
			and Vector2(x + 0.5 - (right + TAB_FLARE), y + 0.5 - (height - TAB_FLARE)).length() >= TAB_FLARE


## The open page: its entries in a scrolling list, or its "No ... held." line.
func _page_panel(armor: Array[Item]) -> Control:
	var panel: Panel = Panel.new()
	panel.position = PAGE_RECT.position
	panel.size = PAGE_RECT.size
	# The tabs cover its whole top, so its top corners are square.
	var ground: StyleBoxFlat = _set_in_style(SET_IN, SET_IN_RADIUS)
	ground.corner_radius_top_left = 0
	ground.corner_radius_top_right = 0
	panel.add_theme_stylebox_override("panel", ground)
	var items: Array[Item]
	match _page:
		Page.ARMOR:
			items = armor
		Page.MODS:
			items = _sample_mods()
		_:
			items = _sample_potions()
	_scroll = null
	_entries.clear()
	_stars.clear()
	if items.is_empty():
		var none: Label = _text(EMPTY_WORDS[_page], 26, CREAM_MUTED, false)
		none.set_anchors_preset(Control.PRESET_FULL_RECT)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(none)
		return panel
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(PAGE_PADDING, PAGE_PADDING)
	_scroll.size = PAGE_RECT.size - Vector2(PAGE_PADDING, PAGE_PADDING) * 2.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(14, 0)
	bar.add_theme_stylebox_override("scroll", _flat(SLOT_GROUND, 7))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, _flat(STITCH.darkened(0.25 if state == "grabber" else 0.1), 7))
	panel.add_child(_scroll)
	var room: MarginContainer = MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Room for the scroll bar, kept whether or not the page overflows, so entries are one width.
	room.add_theme_constant_override("margin_right", 24)
	_scroll.add_child(room)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", ENTRY_GAP)
	room.add_child(list)
	for item: Item in items:
		var is_gray: bool = _page == Page.ARMOR and _is_slot_barred(item.slot)
		var entry: Control = _entry(item, is_gray)
		list.add_child(entry)
		if _page == Page.ARMOR:
			_entries[item.name] = entry
			if not is_gray:
				_make_clickable(entry as PanelContainer, item)
	return panel


## An entry: its picture if it has one, its name and count with the Worn star, its type
## line, and what it does, on parchment as tall as its words need.
func _entry(item: Item, is_gray: bool) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.resized.connect(func() -> void: _style_paper(panel))
	_style_paper(panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	if item.icon != null:
		var tile: Control = _icon_tile(item.icon, Ground.BARE if item.is_armor else _ground, false, item.tint)
		tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(tile)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	var heading: HBoxContainer = HBoxContainer.new()
	column.add_child(heading)
	var title: String = item.name if item.count == 1 else "%s ×%d" % [item.name, item.count]
	var name_label: Label = _text(title, 26, INK, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)
	if _page == Page.ARMOR:
		var star: TextureRect = _picture(Icons.star())
		star.custom_minimum_size = Vector2(11, 11) * STAR_SCALE
		star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		star.visible = item.is_worn
		heading.add_child(star)
		_stars[item.name] = star
	column.add_child(_text(item.type_line, 20, INK_MUTED, false))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	for line: String in item.words:
		column.add_child(_words(line))
	if item.emblem != null:
		var look: CardLook = CardLook.of_definition(item.emblem)
		column.add_child(_words(EMBLEM_WORDS))
		var inset: MarginContainer = MarginContainer.new()
		inset.add_theme_constant_override("margin_left", 20)
		var emblem: VBoxContainer = VBoxContainer.new()
		emblem.add_theme_constant_override("separation", 0)
		emblem.add_child(_text(look.name, 20, INK, true))
		emblem.add_child(_words(look.rules_text))
		inset.add_child(emblem)
		column.add_child(inset)
	if is_gray:
		panel.modulate = Color(0.6, 0.6, 0.6, 0.7)
	return panel


## An Armor Icon or a Potion Icon on [param ground], one of the grounds being chosen
## between. [param is_on_dark] says it stands in an Armor Slot, on the Worn column's dark
## leather, not on an entry's parchment. [param tint] is its Item's color, for the grounds
## that show the Rarity.
func _icon_tile(icon: Texture2D, ground: Ground, is_on_dark: bool, tint: Color) -> Control:
	var side: float = float(Icons.SIZE * ICON_SCALE)
	var frame: Panel = Panel.new()
	frame.custom_minimum_size = Vector2(side + 4, side + 4)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var behind: Texture2D = null
	var style: StyleBox = StyleBoxEmpty.new()
	match ground:
		Ground.BEIGE_CIRCLE:
			var beige: StyleBoxFlat = _flat(BEIGE, 0)
			beige.set_border_width_all(2)
			beige.border_color = PAPER_EDGE
			style = beige
			behind = _disc_texture(CIRCLE, CIRCLE, CIRCLE)
		Ground.BARE:
			# An Armor Slot keeps its dark square, so that a filled one is still a slot.
			if is_on_dark:
				style = _set_in_style(SLOT_GROUND, 0)
		Ground.DARK_WELL:
			style = _set_in_style(SLOT_GROUND, 8)
		Ground.LEATHER_PLATE:
			style = DitherShading.plate(LEATHER.lightened(0.18), LEATHER.darkened(0.2), EDGE, 8, 2, 0, int(side) + 4)
		Ground.MEDALLION:
			behind = _disc_texture(SLOT_GROUND, STITCH.darkened(0.2), EDGE)
		Ground.PAPER_WELL:
			var well: StyleBoxFlat = _flat(PAPER.darkened(0.2), 8)
			well.set_border_width_all(2)
			well.border_color = PAPER_EDGE
			style = well
		Ground.RARITY_WELL:
			var edged: StyleBoxFlat = _flat(PAPER.darkened(0.2), 8)
			edged.set_border_width_all(RARITY_EDGE)
			edged.border_color = tint
			style = edged
		Ground.RARITY_PLATE:
			style = DitherShading.plate(tint.lightened(0.18), tint.darkened(0.2), EDGE, 8, 2, 0, int(side) + 4)
	frame.add_theme_stylebox_override("panel", style)
	for texture: Texture2D in [behind, icon]:
		if texture == null:
			continue
		var picture: TextureRect = _picture(texture)
		picture.position = Vector2(2, 2)
		picture.size = Vector2(side, side)
		frame.add_child(picture)
	return frame


## A disc as wide as an icon's grid, in the icon's own pixels so that its edge steps as the
## icon's does: [param fill] inside a ring of [param ring] inside a rim of [param rim].
func _disc_texture(fill: Color, ring: Color, rim: Color) -> Texture2D:
	var disc: Image = Image.create(Icons.SIZE, Icons.SIZE, false, Image.FORMAT_RGBA8)
	var middle: float = (Icons.SIZE - 1) / 2.0
	for y: int in Icons.SIZE:
		for x: int in Icons.SIZE:
			var out: float = Vector2(x - middle, y - middle).length()
			if out <= Icons.SIZE / 2.0 - 2.0:
				disc.set_pixel(x, y, fill)
			elif out <= Icons.SIZE / 2.0 - 1.0:
				disc.set_pixel(x, y, ring)
			elif out <= Icons.SIZE / 2.0:
				disc.set_pixel(x, y, rim)
	return ImageTexture.create_from_image(disc)


## PROTOTYPE: every icon ground on one sheet, each on parchment as an entry has it and, at
## the right, on the Worn column's dark leather as an Armor Slot has it.
func _add_icon_sheet() -> void:
	var board: Panel = Panel.new()
	board.position = ((SCREEN - WINDOW_SIZE) / 2.0).floor()
	board.size = WINDOW_SIZE
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	board.add_theme_stylebox_override("panel", DitherShading.plate(LEATHER.lightened(0.06), LEATHER.darkened(0.3),
			EDGE, WINDOW_RADIUS, 2, 0, int(WINDOW_SIZE.y)))
	_screen.add_child(board)
	# An Armor, then a Potion of each Rarity from Common to Mythic.
	var icons: Array[Texture2D] = [
		Icons.helm(Icons.GOLD, Icons.RED), Icons.boots(Icons.EARTH, Icons.GREEN),
		Icons.potion(Icons.Flask.ROUND, Icons.GOLD), Icons.potion(Icons.Flask.CONE, Icons.VIOLET),
		Icons.potion(Icons.Flask.TALL, Icons.BLUE), Icons.potion(Icons.Flask.CONE, Icons.RUST),
		Icons.potion(Icons.Flask.ROUND, Icons.TEAL),
	]
	var tints: Array[Color] = [
		ARMOR_TINT, ARMOR_TINT, RARITY_TINTS[MmCardDefinition.Rarity.COMMON], RARITY_TINTS[MmCardDefinition.Rarity.UNCOMMON],
		RARITY_TINTS[MmCardDefinition.Rarity.RARE], RARITY_TINTS[MmCardDefinition.Rarity.MYTHIC], UNIQUE_TINT,
	]
	var captions: Array[String] = ["Armor", "Armor", "Common", "Uncommon", "Rare", "Mythic", "Unique"]
	var paper_width: float = 930.0
	var top: float = MARGIN
	for ground: Ground in [Ground.PAPER_WELL, Ground.RARITY_WELL, Ground.LEATHER_PLATE, Ground.RARITY_PLATE]:
		var paper: PanelContainer = PanelContainer.new()
		paper.position = Vector2(MARGIN, top)
		paper.size = Vector2(paper_width, 150)
		_style_paper(paper)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		paper.add_child(row)
		var label: Label = _text(GROUND_NAMES[ground], 22, INK, true)
		label.custom_minimum_size = Vector2(110, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		for index: int in icons.size():
			var stack: VBoxContainer = VBoxContainer.new()
			stack.alignment = BoxContainer.ALIGNMENT_CENTER
			stack.add_child(_icon_tile(icons[index], ground, false, tints[index]))
			var caption: Label = _text(captions[index], 16, INK_MUTED, false)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stack.add_child(caption)
			row.add_child(stack)
		board.add_child(paper)
		var dark: Panel = Panel.new()
		dark.position = Vector2(MARGIN + paper_width + 12, top)
		dark.size = Vector2(WINDOW_SIZE.x - MARGIN * 2 - paper_width - 12, 150)
		dark.add_theme_stylebox_override("panel", _set_in_style(SET_IN, SET_IN_RADIUS))
		var slots: HBoxContainer = HBoxContainer.new()
		slots.set_anchors_preset(Control.PRESET_FULL_RECT)
		slots.alignment = BoxContainer.ALIGNMENT_CENTER
		slots.add_theme_constant_override("separation", 10)
		for index: int in 2:
			var tile: Control = _icon_tile(icons[index], ground, true, tints[index])
			tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slots.add_child(tile)
		dark.add_child(slots)
		board.add_child(dark)
		top += 150 + 12


## Lets a click on [param entry] put [param item] on, or take it off if it is Worn. The
## parchment lightens under the cursor.
func _make_clickable(entry: PanelContainer, item: Item) -> void:
	entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	entry.mouse_entered.connect(func() -> void: entry.self_modulate = Color(1.12, 1.12, 1.12))
	entry.mouse_exited.connect(func() -> void: entry.self_modulate = Color.WHITE)
	entry.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if _worn.get(item.slot, "") == item.name:
			_worn.erase(item.slot)
		else:
			_worn[item.slot] = item.name
		_refresh_worn())


## Shows what is Worn now without building the window again, so the page stays scrolled
## where it was: each entry's star, and the Worn column.
func _refresh_worn() -> void:
	for item: Item in _armor:
		item.is_worn = _worn.get(item.slot, "") == item.name and not _is_slot_barred(item.slot)
		if _stars.has(item.name):
			_stars[item.name].visible = item.is_worn
	_worn_node.queue_free()
	_worn_node = _worn_column(_armor)
	_window.add_child(_worn_node)


## Opens the Armor page if another is open, scrolls it to the entry of the Armor named
## [param armor_name] and lights that entry for a moment.
func _show_entry(armor_name: String) -> void:
	if _page != Page.ARMOR:
		_page = Page.ARMOR
		_rebuild()
	# The list is laid out a frame after it is built.
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll == null or not _entries.has(armor_name):
		return
	var entry: Control = _entries[armor_name]
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	var to: float = clampf(entry.position.y, 0.0, maxf(0.0, bar.max_value - bar.page))
	var glide: Tween = create_tween()
	glide.tween_property(_scroll, "scroll_vertical", int(to), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	entry.modulate = Color(1.3, 1.25, 1.05)
	glide.tween_property(entry, "modulate", Color.WHITE, 0.6)


## PROTOTYPE: a real click of [param button] at [param point], for a picture.
func _click_at(point: Vector2, button: MouseButton) -> void:
	for is_pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = button
		click.pressed = is_pressed
		click.position = point
		click.global_position = point
		get_viewport().push_input(click, true)


func _close_button() -> Button:
	var button: Button = Button.new()
	button.text = "Close"
	button.position = CLOSE_RECT.position
	button.size = CLOSE_RECT.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UiText.bold())
	button.add_theme_font_size_override("font_size", 26)
	var height: int = int(CLOSE_RECT.size.y)
	button.add_theme_stylebox_override("normal", DitherShading.button_plate(CLOSE_FILL, false, height, BUTTON_RADIUS))
	button.add_theme_stylebox_override("hover", DitherShading.button_plate(CLOSE_FILL.lightened(0.1), false, height, BUTTON_RADIUS))
	for state: String in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, DitherShading.button_plate(CLOSE_FILL, true, height, BUTTON_RADIUS))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, CREAM)
	button.pressed.connect(_close)
	_close_node = button
	return button


## The sample Armor, sorted by Armor Slot and then by name. One Helm and one pair of Boots
## are Worn, unless the Boots' slot is Barred.
func _sample_armor() -> Array[Item]:
	var items: Array[Item] = []
	if _fill == Fill.EMPTY:
		return items
	var diviner: MmCardDefinition = load(DIVINERS_BOON) as MmCardDefinition
	var electromancer: MmCardDefinition = load(ELECTROMANCERS_BOON) as MmCardDefinition
	items.append(_an_armor("Lionguard Helm", Slot.HELM, Icons.helm(Icons.GOLD, Icons.RED), 3, null, 1, true))
	items.append(_an_armor("Thornwalker Boots", Slot.BOOTS, Icons.boots(Icons.EARTH, Icons.GREEN), 1, null, 1, true))
	if _fill == Fill.FULL:
		items.append(_an_armor("Seer's Helm", Slot.HELM, Icons.helm(Icons.IRON, Icons.BLUE), 0, diviner, 1, false))
		items.append(_an_armor("Marcher's Greaves", Slot.GREAVES, Icons.greaves(Icons.IRON, Icons.EARTH), 2, null, 2, false))
		items.append(_an_armor("Stormcaller's Greaves", Slot.GREAVES, Icons.greaves(Icons.TEAL, Icons.GOLD), 1, electromancer, 1, false))
		items.append(_an_armor("Gilded Boots", Slot.BOOTS, Icons.boots(Icons.RUST, Icons.GOLD), 4, null, 1, false))
	items.sort_custom(func(a: Item, b: Item) -> bool:
		return a.slot < b.slot if a.slot != b.slot else a.name.naturalnocasecmp_to(b.name) < 0)
	return items


func _an_armor(armor_name: String, slot: Slot, icon: Texture2D, life: int, emblem: MmCardDefinition, count: int,
		_starts_worn: bool) -> Item:
	var item: Item = Item.new()
	item.name = armor_name
	item.slot = slot
	item.icon = icon
	item.type_line = SLOT_NAMES[slot]
	if life > 0:
		item.words.append(LIFE_WORDS % life)
	item.emblem = emblem
	item.count = count
	item.is_armor = true
	item.is_worn = _worn.get(slot, "") == armor_name and not _is_slot_barred(slot)
	return item


## The sample Mods, sorted rarest first and then by name. Their words are ModText's, but
## for Ancient, whose ability is only written here.
func _sample_mods() -> Array[Item]:
	var items: Array[Item] = []
	if _fill == Fill.EMPTY:
		return items
	var creature: Array[MmCardTypes.CardType] = [MmCardTypes.CardType.CREATURE]
	var land: Array[MmCardTypes.CardType] = [MmCardTypes.CardType.LAND]
	items.append(_a_mod(_stat_mod("Violent", 1, 1, [TrampleAbility.new()], 1, [], Mod.Rarity.UNCOMMON, creature), 1))
	if _fill == Fill.FULL:
		items.append(_a_mod(DeckbuilderSample.cycling_mod("Ember", MmMana.Type.RED), 2))
		items.append(_a_mod(DeckbuilderSample.cycling_mod("Moss", MmMana.Type.GREEN), 1))
		items.append(_a_mod(DeckbuilderSample.cycling_mod("Tide", MmMana.Type.BLUE), 1))
		items.append(_a_mod(_stat_mod("Sturdy", 0, 2, [], 1, [], Mod.Rarity.COMMON, creature), 3))
		items.append(_a_mod(_stat_mod("Soaring", 0, 0, [FlyingAbility.new()], 1, [MmMana.Type.BLUE], Mod.Rarity.RARE, creature), 1))
		items.append(_a_mod(_stat_mod("Savage", 2, 2, [TrampleAbility.new(), HasteAbility.new()], 2, [], Mod.Rarity.MYTHIC, creature), 1))
		items.append(_a_mod(_stat_mod("Worldbreaker", 3, 3, [], 3, [], Mod.Rarity.UNIQUE, creature), 1))
		var ancient: Item = _a_mod(_stat_mod("Ancient", 0, 0, [], 0, [], Mod.Rarity.RARE, land), 1)
		ancient.words = ["Modified card gains \"When this land enters, you gain 1 life.\""]
		items.append(ancient)
	_sort_by_rarity(items)
	return items


func _a_mod(mod: Mod, count: int) -> Item:
	var item: Item = Item.new()
	item.name = mod.name
	item.count = count
	item.rarity = mod.rarity
	item.type_line = "%s Mod for %s" % [MOD_RARITY_NAMES[mod.rarity], _accepted_by(mod)]
	item.words = [ModText.of(mod)]
	return item


func _stat_mod(mod_name: String, power: int, toughness: int, abilities: Array, generic: int, symbols: Array,
		rarity: Mod.Rarity, card_types: Array[MmCardTypes.CardType]) -> Mod:
	var mod: Mod = Mod.new()
	mod.name = mod_name
	mod.rarity = rarity
	mod.card_types = card_types
	if power != 0 or toughness != 0:
		var stats: AddPowerToughnessModification = AddPowerToughnessModification.new()
		stats.power = power
		stats.toughness = toughness
		mod.augmentation.append(stats)
	for ability: MmAbility in abilities:
		var gains: AddAbilityModification = AddAbilityModification.new()
		gains.ability = ability
		mod.augmentation.append(gains)
	if generic > 0 or not symbols.is_empty():
		var cost: MmManaCost = MmManaCost.new()
		cost.generic = generic
		var typed: Array[MmMana.Type] = []
		typed.assign(symbols)
		cost.symbols = typed
		mod.mod_cost = AddManaCostModification.new()
		mod.mod_cost.cost = cost
	return mod


## The card types [param mod] accepts, for its type line: "creatures", "lands", "creatures
## or artifacts", or "nonland cards" for one that takes every type but Land.
func _accepted_by(mod: Mod) -> String:
	if mod.card_types.size() >= 5 and not mod.card_types.has(MmCardTypes.CardType.LAND):
		return "nonland cards"
	var plurals: Dictionary[MmCardTypes.CardType, String] = {
		MmCardTypes.CardType.ARTIFACT: "artifacts", MmCardTypes.CardType.CREATURE: "creatures",
		MmCardTypes.CardType.ENCHANTMENT: "enchantments", MmCardTypes.CardType.INSTANT: "instants",
		MmCardTypes.CardType.LAND: "lands", MmCardTypes.CardType.SORCERY: "sorceries",
	}
	var named: Array[String] = []
	for card_type: MmCardTypes.CardType in mod.card_types:
		named.append(plurals[card_type])
	if named.size() <= 1:
		return "".join(named)
	return ", ".join(named.slice(0, named.size() - 1)) + " or " + named[named.size() - 1]


## The sample Potions, sorted rarest first and then by name. Big Gulp is the game's mock;
## the rest are made up here.
func _sample_potions() -> Array[Item]:
	var items: Array[Item] = []
	if _fill == Fill.EMPTY:
		return items
	var big_gulp: MmCardDefinition = load(BIG_GULP) as MmCardDefinition
	var gulp_words: String = CardLook.of_definition(big_gulp).rules_text
	if gulp_words == "":
		gulp_words = "Target creature gets +2/+2 until end of turn."
	items.append(_a_potion(big_gulp.name, big_gulp.rarity, Icons.potion(Icons.Flask.ROUND, Icons.GOLD), gulp_words, 2))
	if _fill == Fill.FULL:
		items.append(_a_potion("Mending Draught", MmCardDefinition.Rarity.COMMON, Icons.potion(Icons.Flask.TALL, Icons.RED),
				"You gain 4 life.", 3))
		items.append(_a_potion("Fogbrew", MmCardDefinition.Rarity.UNCOMMON, Icons.potion(Icons.Flask.CONE, Icons.VIOLET),
				"Each opponent discards a card.", 1))
		items.append(_a_potion("Seer's Tonic", MmCardDefinition.Rarity.RARE, Icons.potion(Icons.Flask.TALL, Icons.BLUE),
				"Draw two cards.", 1))
		items.append(_a_potion("Dragon's Breath", MmCardDefinition.Rarity.MYTHIC, Icons.potion(Icons.Flask.CONE, Icons.RUST),
				"Dragon's Breath deals 3 damage to any target.", 1))
	_sort_by_rarity(items)
	return items


func _a_potion(potion_name: String, rarity: MmCardDefinition.Rarity, icon: Texture2D, words: String, count: int) -> Item:
	var item: Item = Item.new()
	item.name = potion_name
	item.count = count
	item.rarity = rarity
	item.icon = icon
	item.tint = RARITY_TINTS[rarity]
	item.type_line = "%s Potion" % Inspector.RARITY_NAMES[rarity]
	item.words = [words]
	return item


func _sort_by_rarity(items: Array[Item]) -> void:
	items.sort_custom(func(a: Item, b: Item) -> bool:
		return a.rarity > b.rarity if a.rarity != b.rarity else a.name.naturalnocasecmp_to(b.name) < 0)


func _is_slot_barred(slot: Slot) -> bool:
	return _is_barred and slot != Slot.HELM


## The flap: leather in Dither Shading, straight at its ends and bellying down in the
## middle, with a dark lower edge and a line of stitches just inside it.
func _flap_texture() -> Texture2D:
	var width: int = int(WINDOW_SIZE.x) - 4
	var corner: int = WINDOW_RADIUS - 2
	var image: Image = Image.create(width, FLAP_HEIGHT, false, Image.FORMAT_RGBA8)
	var top: Color = FLAP.lightened(0.12)
	var bottom: Color = FLAP.darkened(0.22)
	for x: int in width:
		var across: float = (x - width / 2.0) / (width / 2.0)
		var foot: float = FLAP_SIDE + FLAP_DROP * (1.0 - across * across)
		for y: int in FLAP_HEIGHT:
			if y > foot:
				continue
			# The window's own top corners.
			var from_side: int = mini(x, width - 1 - x)
			if from_side < corner and y < corner and Vector2(corner - from_side, corner - y).length() > corner:
				continue
			var color: Color = DitherShading.band_color(x, y, FLAP_HEIGHT, top, bottom)
			if y > foot - 2.0:
				color = EDGE
			elif absf(y - (foot - 10.0)) <= 1.0 and x % 16 < 9 and from_side > 12:
				color = STITCH
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## The stitches down the window's sides and along its foot, a little inside its edge.
func _draw_stitches(on: Control) -> void:
	var inset: float = 10.0
	var corner: float = WINDOW_RADIUS - inset
	var left: float = inset
	var right: float = WINDOW_SIZE.x - inset
	var foot: float = WINDOW_SIZE.y - inset
	var path: PackedVector2Array = PackedVector2Array([Vector2(left, FLAP_SIDE + 12.0), Vector2(left, foot - corner)])
	for step: int in range(1, 9):
		var angle: float = PI - step * (PI / 2.0) / 8.0
		path.append(Vector2(left + corner + cos(angle) * corner, foot - corner + sin(angle) * corner))
	path.append(Vector2(right - corner, foot))
	for step: int in range(1, 9):
		var angle: float = PI / 2.0 - step * (PI / 2.0) / 8.0
		path.append(Vector2(right - corner + cos(angle) * corner, foot - corner + sin(angle) * corner))
	path.append(Vector2(right, FLAP_SIDE + 12.0))
	var walked: float = 0.0
	for index: int in path.size() - 1:
		var length: float = path[index].distance_to(path[index + 1])
		var along: float = 0.0
		while along < length:
			if fmod(walked + along, 16.0) < 9.0:
				on.draw_rect(Rect2((path[index].lerp(path[index + 1], along / length)).floor() - Vector2(1, 1), Vector2(2, 2)), STITCH)
			along += 1.0
		walked += length


func _add_prototype_bar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.position = Vector2(16, SCREEN.y - 52)
	bar.add_theme_constant_override("separation", 8)
	_bar_layer.add_child(bar)
	var fill: Button = Button.new()
	fill.text = "Satchel (F): %s" % FILL_NAMES[_fill]
	fill.pressed.connect(func() -> void:
		_fill = ((_fill + 1) % Fill.size()) as Fill
		_rebuild())
	bar.add_child(fill)
	var barred: Button = Button.new()
	barred.text = "Barred Greaves and Boots (B): %s" % ("on" if _is_barred else "off")
	barred.pressed.connect(func() -> void:
		_is_barred = not _is_barred
		_rebuild())
	bar.add_child(barred)
	var ground: Button = Button.new()
	ground.text = "Icon ground (I): %s" % GROUND_NAMES[_ground]
	ground.pressed.connect(func() -> void:
		_ground = ((_ground + 1) % Ground.size()) as Ground
		_rebuild())
	bar.add_child(ground)
	var sheet: Button = Button.new()
	sheet.text = "All grounds (W): %s" % ("on" if _is_sheet else "off")
	sheet.pressed.connect(func() -> void:
		_is_sheet = not _is_sheet
		_rebuild())
	bar.add_child(sheet)
	var state: Label = Label.new()
	state.text = "  PROTOTYPE · step 3 · the Run Bar's Satchel button opens it; Close or a click outside closes it"
	state.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	bar.add_child(state)


## A parchment panel, shaded with Dither Shading over its own height.
func _style_paper(panel: PanelContainer) -> void:
	var made: StyleBoxTexture = DitherShading.plate(PAPER.lightened(PAPER_LIGHTEN), PAPER.darkened(PAPER_DARKEN),
			PAPER_EDGE, PAPER_RADIUS - PAPER_EDGE_WIDTH, PAPER_EDGE_WIDTH, 0,
			maxi(int(panel.size.y), PAPER_RADIUS * 2 + 1))
	made.content_margin_left = PAPER_PADDING.x
	made.content_margin_right = PAPER_PADDING.x
	made.content_margin_top = PAPER_PADDING.y
	made.content_margin_bottom = PAPER_PADDING.y
	panel.add_theme_stylebox_override("panel", made)


## The flat, dark-edged ground of something set into the leather.
func _set_in_style(fill: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = _flat(fill, radius)
	style.set_border_width_all(2)
	style.border_color = EDGE
	return style


func _flat(fill: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	return style


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
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	return made


## A line of what an Item does, its mana symbols drawn as a card's are.
func _words(text: String) -> SymbolLabel:
	var made: SymbolLabel = SymbolLabel.new()
	made.set_font_size(20)
	made.write_in(text, INK)
	return made
