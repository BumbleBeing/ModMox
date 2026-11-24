extends Control
## PROTOTYPE (milestone 24, step 1 of 3): the Store's still layout, in three arrangements to
## choose between, each built from the words and the parts the roadmap already fixes.
## Throwaway: deleted after sign-off, once the real screen is ported test-first. Nothing
## here changes a run: the goods are samples made in this file, and no button does anything.
##
## godot --path . res://prototypes/store_screen/store_screen.tscn -- --run-seed=7 --stage=white
##
## The bar at the foot of the screen, or the keys:
##   Left, Right (or A, B, C)  the arrangement:
##       A, Bench: the deckbuilder's bones. A top bar, the Inspector, the cards five across
##          at 280 pixels, and the Items as Satchel entries in a column.
##       B, Window: the Spoils' bones. One window on the Stage's ground with "Store" on its
##          bar, the cards three across at 250 pixels, the Items, the gold and the buttons
##          down its side, and the Inspector outside it.
##       C, Showcase: the cards first, five across at 336 pixels. It bends one agreed thing
##          to get there: an Item is a tile, its picture and name, and its words are read
##          in the Inspector.
##   S  the stock: typical (6 cards, 2 Potions, 1 Armor), nine cards, or few cards (4 cards,
##      3 Potions, 2 Armor)
##   M  whether some cards carry Mods and Hexes
##   G  the gold held: enough for everything, or too little for most
##   X  whether three goods have been bought, leaving Sold spaces
##   H  hides the bar
## Hovering a good shows it in the Inspector. --layout=b, --stock=nine (or few), --plain,
## --poor, --sold, --no-bar and --inspect="Violent Shivan Dragon" start it that way,
## --hover="Big Gulp" puts the cursor over a good with a real mouse event, and
## --screenshot=/absolute/path.png saves a picture and quits.
##
## Steps 2 and 3 come after this one is signed off: selecting, Buy, Sold and the gold's
## count; then selling through the Collection Window and the Satchel.

enum Layout { BENCH, WINDOW, SHOWCASE }
enum Stock { TYPICAL, NINE_CARDS, FEW_CARDS }

const Parts = preload("res://prototypes/store_screen/shop_parts.gd")
const LAYOUT_NAMES: Dictionary[Layout, String] = {
	Layout.BENCH: "A · Bench", Layout.WINDOW: "B · Window", Layout.SHOWCASE: "C · Showcase",
}
const STOCK_NAMES: Dictionary[Stock, String] = {
	Stock.TYPICAL: "typical", Stock.NINE_CARDS: "nine", Stock.FEW_CARDS: "few",
}
const TITLE: String = "Store"
const RICH: int = 480
const POOR: int = 55
const INSPECTOR_WIDTH: float = 340.0
const INSPECTOR_PAD: float = 10.0
const CARDS: String = "res://content/cards/%s.tres"
const MODS: String = "res://content/mods/%s.tres"
const DIVINERS_BOON: String = "res://content/emblems/diviners_boon.tres"
const LIFE_WORDS: String = "You start each encounter with %d more life."

var _layout: Layout = Layout.BENCH
var _stock: Stock = Stock.TYPICAL
var _has_mods: bool = true
var _is_poor: bool = false
var _has_sold: bool = false
var _is_bar_shown: bool = true
var _run: Run = null
var _screen: Control = null
var _bar: Control = null
var _cards: Array[Parts.Good] = []
var _items: Array[Parts.Good] = []
var _inspector: DeckbuilderInspector = null
var _item_holder: Control = null
var _inspected: Parts.Good = null
## The name of the good --inspect= holds in the Inspector, whatever the cursor is over.
var _pinned: String = ""
var _next_id: int = 0
## Where each good stands, by its name, for --hover=.
var _spots: Dictionary[String, Control] = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument.begins_with("--layout="):
			_layout = clampi("abc".find(argument.trim_prefix("--layout=").to_lower()), 0, Layout.size() - 1) as Layout
		elif argument.begins_with("--stock="):
			for stock: Stock in STOCK_NAMES:
				if STOCK_NAMES[stock] == argument.trim_prefix("--stock=").to_lower():
					_stock = stock
		elif argument.begins_with("--inspect="):
			_pinned = argument.trim_prefix("--inspect=")
		elif argument == "--plain":
			_has_mods = false
		elif argument == "--poor":
			_is_poor = true
		elif argument == "--sold":
			_has_sold = true
		elif argument == "--no-bar":
			_is_bar_shown = false
	_run = StageMapScreen.debug_run_from(arguments)
	_rebuild()
	for argument: String in arguments:
		if argument.begins_with("--hover=") and _spots.has(argument.trim_prefix("--hover=")):
			for frame: int in 3:
				await get_tree().process_frame
			# A real mouse event, as the satchel prototype's clicks were.
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.position = _spots[argument.trim_prefix("--hover=")].get_global_rect().get_center()
			motion.global_position = motion.position
			get_viewport().push_input(motion, true)
	var picture: String = EncounterScreen.screenshot_path(arguments)
	if picture != "":
		for frame: int in 8:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_LEFT:
			_layout = ((_layout + Layout.size() - 1) % Layout.size()) as Layout
		KEY_RIGHT:
			_layout = ((_layout + 1) % Layout.size()) as Layout
		KEY_A:
			_layout = Layout.BENCH
		KEY_B:
			_layout = Layout.WINDOW
		KEY_C:
			_layout = Layout.SHOWCASE
		KEY_S:
			_stock = ((_stock + 1) % Stock.size()) as Stock
		KEY_M:
			_has_mods = not _has_mods
		KEY_G:
			_is_poor = not _is_poor
		KEY_X:
			_has_sold = not _has_sold
		KEY_H:
			_is_bar_shown = not _is_bar_shown
		_:
			return
	_rebuild()


func _rebuild() -> void:
	if _screen != null:
		_screen.queue_free()
	if _bar != null:
		_bar.queue_free()
		_bar = null
	_inspected = null
	_spots.clear()
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_screen.add_child(StageIntro.ground_panel(_run.stage_visit.stage))
	_make_goods()
	match _layout:
		Layout.BENCH:
			_lay_out_bench()
		Layout.WINDOW:
			_lay_out_window()
		_:
			_lay_out_showcase()
	for good: Parts.Good in _cards + _items:
		if good.name == _pinned and not good.is_sold:
			_inspected = good
	_show_inspected()
	if _is_bar_shown:
		_add_bar()


func _gold() -> int:
	return POOR if _is_poor else RICH


func _can_afford(good: Parts.Good) -> bool:
	return good.price <= _gold()


# ---------------------------------------------------------------------------------------
# A, Bench: the deckbuilder's bones. A top bar with the title, the gold and the buttons;
# the Inspector down the left; the cards five across; the Items in a column at the right.
# ---------------------------------------------------------------------------------------

func _lay_out_bench() -> void:
	var bar: Panel = Parts.pane(Rect2(12, 12, 1896, 72))
	_screen.add_child(bar)
	_fill_bar(bar, 24, 14)
	_add_inspector(Rect2(12, 96, INSPECTOR_WIDTH, 972))
	var items_width: float = 388.0
	var right: float = 1908.0 - (items_width + 12.0 if not _items.is_empty() else 0.0)
	var cards_pane: Panel = Parts.pane(Rect2(364, 96, right - 364.0, 972))
	_screen.add_child(cards_pane)
	var centered: CenterContainer = CenterContainer.new()
	Parts.inside(cards_pane, 24).add_child(centered)
	centered.add_child(_card_grid(5, 280.0, 20, 22))
	if not _items.is_empty():
		var items_pane: Panel = Parts.pane(Rect2(1908.0 - items_width, 96, items_width, 972))
		_screen.add_child(items_pane)
		Parts.inside(items_pane, 12).add_child(_item_list())


# ---------------------------------------------------------------------------------------
# B, Window: the Spoils' bones. One window on the Stage's ground, "Store" on its bar; the
# cards three across; the Items, the gold and the buttons down its side; the Inspector
# stands outside it.
# ---------------------------------------------------------------------------------------

func _lay_out_window() -> void:
	_add_inspector(Rect2(12, 12, INSPECTOR_WIDTH, 1056))
	var area: CenterContainer = CenterContainer.new()
	area.position = Vector2(364, 0)
	area.size = Vector2(1544, 1080)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(area)
	var window: PanelContainer = Parts.window()
	area.add_child(window)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	window.add_child(column)
	column.add_child(Parts.heading_bar(TITLE))
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)
	var card_height: float = 250.0
	var grid_holder: CenterContainer = CenterContainer.new()
	grid_holder.custom_minimum_size = Vector2(3.0 * roundf(card_height * CardGeometry.ASPECT) + 2.0 * 20.0,
			3.0 * (card_height + 8.0 + 32.0) + 2.0 * 14.0)
	grid_holder.add_child(_card_grid(3, card_height, 20, 14))
	body.add_child(grid_holder)
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(388, 0)
	side.add_theme_constant_override("separation", 16)
	body.add_child(side)
	if _items.is_empty():
		var room: Control = Control.new()
		room.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(room)
	else:
		side.add_child(_item_list())
	var gold: Control = Parts.gold_panel(_gold(), true)
	gold.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side.add_child(gold)
	var buttons: GridContainer = GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 8)
	for button: Button in _buttons():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	side.add_child(buttons)


# ---------------------------------------------------------------------------------------
# C, Showcase: the cards first, five across and large. A strip across the top, as the Run
# Bar lies across the Stage Map, holds the title, the gold and the buttons. It bends one
# agreed thing: an Item is a tile, its picture and its name over its price, and what it
# does is read in the Inspector, as a card's text is.
# ---------------------------------------------------------------------------------------

func _lay_out_showcase() -> void:
	var strip: Panel = Parts.pane(Rect2(-2, -2, 1924, 82), 0, Parts.STRIP_EDGE)
	_screen.add_child(strip)
	_fill_bar(strip, 34, 34)
	_add_inspector(Rect2(12, 92, INSPECTOR_WIDTH, 976))
	var tiles_width: float = 176.0
	var right: float = 1908.0 - (tiles_width + 12.0 if not _items.is_empty() else 0.0)
	var board: Panel = Parts.pane(Rect2(364, 92, right - 364.0, 976))
	_screen.add_child(board)
	var centered: CenterContainer = CenterContainer.new()
	Parts.inside(board, 24).add_child(centered)
	centered.add_child(_card_grid(5, 336.0, 24, 30))
	if _items.is_empty():
		return
	var tiles_pane: Panel = Parts.pane(Rect2(1908.0 - tiles_width, 92, tiles_width, 976))
	_screen.add_child(tiles_pane)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Parts.inside(tiles_pane, 14).add_child(scroll)
	var tiles: VBoxContainer = VBoxContainer.new()
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("separation", 20)
	scroll.add_child(tiles)
	for good: Parts.Good in _items:
		tiles.add_child(_tile(good))


## An Item as a tile: its picture and its name on parchment, and its price under it.
func _tile(good: Parts.Good) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	if good.is_sold:
		column.add_child(Parts.sold_space(Vector2(148, 156), Parts.PAPER_RADIUS))
		var gap: Control = Control.new()
		gap.custom_minimum_size = Vector2(0, 32)
		column.add_child(gap)
		return column
	var panel: PanelContainer = Parts.paper(Vector2(8, 10))
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Control = Parts.icon_tile(good)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(icon)
	var title: Label = Parts.wrapped(good.name, 18, Parts.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title)
	panel.add_child(inner)
	Parts._watch(panel, good, _inspect)
	_spots[good.name] = panel
	column.add_child(panel)
	column.add_child(Parts.price(good.price, _can_afford(good), false))
	return column


# ---------------------------------------------------------------------------------------
# What every arrangement is made of.
# ---------------------------------------------------------------------------------------

## The title at the left of [param bar], then the gold panel and the four buttons at its
## right, kept [param left] and [param right] pixels from its ends.
func _fill_bar(bar: Panel, left: int, right: int) -> void:
	var holder: MarginContainer = Parts.inside(bar, 0)
	holder.add_theme_constant_override("margin_left", left)
	holder.add_theme_constant_override("margin_right", right)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	holder.add_child(row)
	var title: Label = Parts.text(TITLE, 36, Parts.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	row.add_child(Parts.gold_panel(_gold(), false))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	row.add_child(gap)
	for button: Button in _buttons():
		row.add_child(button)


func _buttons() -> Array[Button]:
	return [Parts.button("Sell Cards"), Parts.button("Satchel", "satchel"), Parts.button("Deckbox", "deckbox"),
			Parts.button("Leave")]


## The cards for sale, at most [param columns] to a row, each [param height] pixels tall
## with its price under it.
func _card_grid(columns: int, height: float, across: int, down: int) -> VBoxContainer:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", down)
	var row: HBoxContainer = null
	# The rows are evened out: six cards stand three and three, not five and one.
	var row_count: int = ceili(_cards.size() / float(columns))
	var per_row: int = ceili(_cards.size() / float(maxi(row_count, 1)))
	for index: int in _cards.size():
		if index % per_row == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", across)
			rows.add_child(row)
		var made: Control = Parts.card_good(_cards[index], height, _can_afford(_cards[index]), _inspect)
		_spots[_cards[index].name] = made.get_child(0) as Control
		row.add_child(made)
	return rows


## The Items for sale as Satchel entries, Potions and then Armor, scrolling if they must.
func _item_list() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for good: Parts.Good in _items:
		var entry: Control = Parts.item_entry(good, _can_afford(good), _inspect)
		_spots[good.name] = entry
		list.add_child(entry)
	return scroll


## The Inspector on a pane at [param place]: the deckbuilder's own, without Apply a Mod and
## without the deckbuilder's hint, whose words are not the Store's.
func _add_inspector(place: Rect2) -> void:
	var pane: Panel = Parts.pane(place)
	pane.theme = DeckbuilderLook.theme()
	_screen.add_child(pane)
	var room: Vector2 = place.size - 2.0 * Vector2(INSPECTOR_PAD, INSPECTOR_PAD)
	_inspector = DeckbuilderInspector.new()
	_inspector.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	(_inspector.get_child(0) as Label).text = ""
	pane.add_child(_inspector)
	# The Inspector keeps room for Apply a Mod at its foot whether or not it is shown, so
	# it is made that much taller than its pane and the pane cuts the room off. Its size
	# is set once it is in the tree: set before, its wrapped hint makes it far too tall.
	var apply: Button = _inspector.apply_button()
	apply.visible = false
	pane.clip_contents = true
	_inspector.position = Vector2(INSPECTOR_PAD, INSPECTOR_PAD)
	_inspector.size = room + Vector2(0, apply.get_combined_minimum_size().y + DeckbuilderInspector.GAP)
	_item_holder = Control.new()
	_item_holder.position = Vector2(INSPECTOR_PAD, INSPECTOR_PAD)
	_item_holder.size = room
	_item_holder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_item_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.add_child(_item_holder)


## Shows [param good], the one under the cursor, in the Inspector, or nothing for null.
func _inspect(good: Parts.Good) -> void:
	if _pinned != "" or good == _inspected:
		return
	_inspected = good
	_show_inspected()


func _show_inspected() -> void:
	var is_card: bool = _inspected != null and _inspected.kind == Parts.Kind.CARD
	_inspector.show_card(_inspected.card if is_card else null, (INSPECTOR_WIDTH - 2.0 * INSPECTOR_PAD) / CardGeometry.ASPECT)
	InspectorParts.clear(_item_holder)
	if _inspected != null and not is_card:
		_item_holder.add_child(_item_readout(_inspected))


## An Item as the Inspector might show it, after the encounter's Potion Readout: its picture
## large, its name and its type line, and what it does in a Card Text panel.
func _item_readout(good: Parts.Good) -> Control:
	var palette: InspectorParts.Palette = DeckbuilderLook.inspector_palette()
	var width: float = INSPECTOR_WIDTH - 2.0 * INSPECTOR_PAD
	var side: float = 204.0
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	var art_holder: Control = Control.new()
	art_holder.custom_minimum_size = Vector2(width, side + 40.0)
	column.add_child(art_holder)
	var at: Vector2 = Vector2(roundf((width - side) / 2.0), 24)
	if good.kind == Parts.Kind.POTION:
		var art: PotionArt = PotionArt.new(good.potion_key, side, false, good.rarity)
		art.position = at
		art_holder.add_child(art)
		var ring: Control = Control.new()
		ring.position = at
		ring.size = Vector2(side, side)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_holder.add_child(ring)
		BorderEffects.add_glow(ring, ring.size, Inspector.glow_of(good.rarity))
	else:
		var slot: Panel = Panel.new()
		slot.position = at
		slot.size = Vector2(side, side)
		var ground: StyleBoxFlat = StyleBoxFlat.new()
		ground.bg_color = Parts.SLOT_GROUND
		ground.border_color = Color("#1c120b")
		ground.set_border_width_all(2)
		slot.add_child(Parts.picture(good.armor_icon, 6.0))
		(slot.get_child(0) as Control).position = Vector2(6, 6)
		slot.add_theme_stylebox_override("panel", ground)
		art_holder.add_child(slot)
	var title: Label = Parts.text(good.name, 30, Color.WHITE, false)
	title.add_theme_font_override("font", CardFonts.title())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var type_line: Label = Parts.text(good.type_line, 18, Color("#9aa3af"), false)
	type_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(type_line)
	var panel: PanelContainer = InspectorParts.panel("Card Text", palette, DeckbuilderInspector.TITLE_SIZE)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = InspectorParts.body_of(panel)
	for line: String in good.words:
		var label: SymbolLabel = InspectorParts.symbol_label(palette, DeckbuilderInspector.BODY_SIZE)
		label.write(line)
		body.add_child(label)
	if good.emblem != null:
		var look: CardLook = CardLook.of_definition(good.emblem)
		var brings: SymbolLabel = InspectorParts.symbol_label(palette, DeckbuilderInspector.BODY_SIZE)
		brings.write(Parts.EMBLEM_WORDS)
		body.add_child(brings)
		body.add_child(InspectorParts.words(look.name, look.rules_text, palette, DeckbuilderInspector.BODY_SIZE))
	column.add_child(panel)
	return column


func _add_bar() -> void:
	var switches: Array[Button] = [
		Parts.bar_switch("<", func() -> void: _step_layout(-1)),
		Parts.bar_switch(LAYOUT_NAMES[_layout], func() -> void: _step_layout(1)),
		Parts.bar_switch(">", func() -> void: _step_layout(1)),
		Parts.bar_switch("Stock (S): %s" % STOCK_NAMES[_stock], func() -> void:
			_stock = ((_stock + 1) % Stock.size()) as Stock
			_rebuild()),
		Parts.bar_switch("Mods and Hexes (M): %s" % ("on" if _has_mods else "off"), func() -> void:
			_has_mods = not _has_mods
			_rebuild()),
		Parts.bar_switch("Gold (G): %d" % _gold(), func() -> void:
			_is_poor = not _is_poor
			_rebuild()),
		Parts.bar_switch("Sold (X): %s" % ("on" if _has_sold else "off"), func() -> void:
			_has_sold = not _has_sold
			_rebuild()),
	]
	_bar = Parts.switch_bar(switches, "PROTOTYPE · Store, step 1 · H hides this")
	add_child(_bar)


func _step_layout(by: int) -> void:
	_layout = ((_layout + Layout.size() + by) % Layout.size()) as Layout
	_rebuild()


# ---------------------------------------------------------------------------------------
# The sample goods. Every card, Mod and icon is the game's own; the Hex is the
# deckbuilder sample's, since Content has none yet; Big Gulp is the one authored Potion,
# and the other Potions and the Armor are written here.
# ---------------------------------------------------------------------------------------

func _make_goods() -> void:
	_cards.clear()
	_items.clear()
	_next_id = 0
	var burden: Array[Mod] = [DeckbuilderSample.burden()]
	var none: Array[Mod] = []
	var potions: Array[Parts.Good] = []
	var armor: Array[Parts.Good] = []
	match _stock:
		Stock.TYPICAL:
			_cards.append(_a_card("alpha/grizzly_bears", burden))
			_cards.append(_a_card("alpha/llanowar_elves", none))
			_cards.append(_a_card("alpha/counterspell", _mods(["vexing"])))
			_cards.append(_a_card("alpha/serra_angel", none))
			_cards.append(_a_card("alpha/shivan_dragon", _mods(["violent"])))
			_cards.append(_a_card("born_of_the_gods/brimaz_king_of_oreskos", none))
			potions.append(_big_gulp())
			potions.append(_a_potion("Dragon's Breath", "dragons_breath", MmCardDefinition.Rarity.RARE,
					"This potion deals 3 damage to any target."))
			armor.append(_an_armor("Seer's Cuirass", "seers_cuirass", "Cuirass", 0, DIVINERS_BOON, 300))
		Stock.NINE_CARDS:
			_cards.append(_a_card("alpha/grizzly_bears", burden))
			_cards.append(_a_card("alpha/giant_growth", none))
			_cards.append(_a_card("alpha/llanowar_elves", none))
			_cards.append(_a_card("alpha/counterspell", _mods(["vexing"])))
			_cards.append(_a_card("alpha/serra_angel", none))
			_cards.append(_a_card("alpha/white_knight", none))
			_cards.append(_a_card("alpha/savannah_lions", burden + _mods(["sharp"])))
			_cards.append(_a_card("alpha/shivan_dragon", _mods(["violent"])))
			_cards.append(_a_card("born_of_the_gods/brimaz_king_of_oreskos", none))
		Stock.FEW_CARDS:
			_cards.append(_a_card("alpha/giant_growth", none))
			_cards.append(_a_card("alpha/white_knight", none))
			_cards.append(_a_card("alpha/savannah_lions", burden + _mods(["sharp"])))
			_cards.append(_a_card("born_of_the_gods/brimaz_king_of_oreskos", none))
			potions.append(_a_potion("Mind Hazy", "mind_hazy", MmCardDefinition.Rarity.UNCOMMON,
					"Target opponent discards a card."))
			potions.append(_a_potion("Fogbrew", "fogbrew", MmCardDefinition.Rarity.UNCOMMON,
					"Prevent all damage dealt to and dealt by target creature until end of turn."))
			potions.append(_a_potion("Demonic Brewtor", "demonic_brewtor", MmCardDefinition.Rarity.MYTHIC,
					"Search your library for a card, put it into your hand, then shuffle. Drink only as a sorcery."))
			armor.append(_an_armor("Lionguard Helm", "lionguard_helm", "Helm", 3, "", 150))
			armor.append(_an_armor("Seer's Cuirass", "seers_cuirass", "Cuirass", 0, DIVINERS_BOON, 300))
	# Cheapest first and then by name; Potions and then Armor, each cheapest first.
	for goods: Array[Parts.Good] in [_cards, potions, armor]:
		goods.sort_custom(func(a: Parts.Good, b: Parts.Good) -> bool:
			return a.price < b.price if a.price != b.price else a.name.naturalnocasecmp_to(b.name) < 0)
	_items = potions + armor
	if _has_sold:
		_cards[1].is_sold = true
		_cards[_cards.size() - 2].is_sold = true
		if not _items.is_empty():
			_items[0].is_sold = true


func _mods(files: Array[String]) -> Array[Mod]:
	var mods: Array[Mod] = []
	for file: String in files:
		mods.append(load(MODS % file) as Mod)
	return mods


func _a_card(file: String, mods: Array[Mod]) -> Parts.Good:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = load(CARDS % file) as MmCardDefinition
	_next_id += 1
	var card: DeckbuilderCard = DeckbuilderCard.new(_next_id, run_card)
	if _has_mods:
		for mod: Mod in mods:
			card.attach(mod)
	var good: Parts.Good = Parts.Good.new()
	good.kind = Parts.Kind.CARD
	good.card = card
	good.name = card.card_name()
	good.price = Parts.card_price(card)
	return good


func _big_gulp() -> Parts.Good:
	var definition: MmCardDefinition = load("res://content/potions/big_gulp.tres") as MmCardDefinition
	return _a_potion(definition.name, "big_gulp", definition.rarity, CardLook.of_definition(definition).rules_text)


func _a_potion(potion_name: String, key: String, rarity: MmCardDefinition.Rarity, words: String) -> Parts.Good:
	var good: Parts.Good = Parts.Good.new()
	good.kind = Parts.Kind.POTION
	good.name = potion_name
	good.potion_key = key
	good.rarity = rarity
	good.type_line = "%s Potion" % Inspector.RARITY_NAMES[rarity]
	good.words = [words]
	good.price = Parts.POTION_PRICES[rarity]
	return good


func _an_armor(armor_name: String, file: String, slot: String, life: int, emblem: String, price: int) -> Parts.Good:
	var good: Parts.Good = Parts.Good.new()
	good.kind = Parts.Kind.ARMOR
	good.name = armor_name
	good.armor_icon = load(Parts.ARMOR_FOLDER % file) as Texture2D
	good.type_line = slot
	if life > 0:
		good.words = [LIFE_WORDS % life]
	if emblem != "":
		good.emblem = load(emblem) as MmCardDefinition
	good.price = price
	return good
