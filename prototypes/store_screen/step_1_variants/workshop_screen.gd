extends Control
## PROTOTYPE (milestone 25, step 1 of 3): the Workshop's still layout, in three arrangements
## to choose between, each built from the words and the parts the roadmap already fixes and
## from the Store prototype's parts (prototypes/store_screen/shop_parts.gd). Throwaway:
## deleted after sign-off, once the real screen is ported test-first. Nothing here changes
## a run: the four Mods are Content's own, and no button does anything.
##
## godot --path . res://prototypes/workshop_screen/workshop_screen.tscn -- --run-seed=7 --stage=white
##
## The bar at the foot of the screen, or the keys:
##   Left, Right (or A, B, C)  the arrangement:
##       A, Bench: the Store's A. A top bar; the four Mods two by two on one pane; Removal
##          over Duplication on another.
##       B, Window: the Store's B. One window on the Stage's ground with "Workshop" on its
##          bar: the Mods in a column as the Satchel lists them, and Removal, Duplication,
##          the gold and the buttons down its side.
##       C, Counter: the Store's C. A strip across the top; the four Mods as tall tags in a
##          row, each with its price at its foot; Removal and Duplication side by side
##          under them, on parchment as the Mods are.
##   S  the stock: typical, or the four wordiest Mods in Content
##   G  the gold held: enough for everything, or too little for most
##   X  whether two Mods have been bought and the Duplication used
##   H  hides the bar
## --layout=b, --stock=wordy, --poor, --sold and --no-bar start it that way, and
## --screenshot=/absolute/path.png saves a picture and quits.
##
## Steps 2 and 3 come after this one is signed off: buying Mods; then Removal and
## Duplication through the Collection Window.

enum Layout { BENCH, WINDOW, COUNTER }
enum Stock { TYPICAL, WORDY }

const Parts = preload("res://prototypes/store_screen/shop_parts.gd")
const LAYOUT_NAMES: Dictionary[Layout, String] = {
	Layout.BENCH: "A · Bench", Layout.WINDOW: "B · Window", Layout.COUNTER: "C · Counter",
}
const STOCK_NAMES: Dictionary[Stock, String] = { Stock.TYPICAL: "typical", Stock.WORDY: "wordy" }
const STOCKS: Dictionary[Stock, Array] = {
	Stock.TYPICAL: ["tough", "sharp", "slippery", "violent"],
	Stock.WORDY: ["vexing", "flashy", "overloaded", "erupting"],
}
const MODS: String = "res://content/mods/%s.tres"
const TITLE: String = "Workshop"
const REMOVAL: String = "Removal"
const REMOVAL_WORDS: String = "Takes a Mod or Hex off of a card. Mods go back into your Satchel."
const DUPLICATION: String = "Duplication"
const DUPLICATION_WORDS: String = "Makes an exact copy of a card, with its Mods and Hexes."
const CHOOSE: String = "Choose a Card"
const SOLD: String = "Sold"
const RICH: int = 480
const POOR: int = 55
## What a service panel is set into a pane in: darker than the pane.
const SET_IN: Color = Color("#302727")

var _layout: Layout = Layout.BENCH
var _stock: Stock = Stock.TYPICAL
var _is_poor: bool = false
var _has_sold: bool = false
var _is_bar_shown: bool = true
var _run: Run = null
var _screen: Control = null
var _bar: Control = null
var _mods: Array[Parts.Good] = []


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
		elif argument == "--poor":
			_is_poor = true
		elif argument == "--sold":
			_has_sold = true
		elif argument == "--no-bar":
			_is_bar_shown = false
	_run = StageMapScreen.debug_run_from(arguments)
	_rebuild()
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
			_layout = Layout.COUNTER
		KEY_S:
			_stock = ((_stock + 1) % Stock.size()) as Stock
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
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_screen.add_child(StageIntro.ground_panel(_run.stage_visit.stage))
	_make_mods()
	match _layout:
		Layout.BENCH:
			_lay_out_bench()
		Layout.WINDOW:
			_lay_out_window()
		_:
			_lay_out_counter()
	if _is_bar_shown:
		_add_bar()


func _gold() -> int:
	return POOR if _is_poor else RICH


# ---------------------------------------------------------------------------------------
# A, Bench: a top bar with the title, the gold and the buttons; the four Mods two by two
# on one pane; Removal over Duplication on another.
# ---------------------------------------------------------------------------------------

func _lay_out_bench() -> void:
	var bar: Panel = Parts.pane(Rect2(12, 12, 1896, 72))
	_screen.add_child(bar)
	_fill_bar(bar, 24, 14)
	var mods_pane: Panel = Parts.pane(Rect2(12, 96, 1236, 972))
	_screen.add_child(mods_pane)
	var centered: CenterContainer = CenterContainer.new()
	Parts.inside(mods_pane, 24).add_child(centered)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	centered.add_child(grid)
	for good: Parts.Good in _mods:
		var entry: Control = _mod_entry(good, 30, 22)
		entry.custom_minimum_size = Vector2(574, 230)
		grid.add_child(entry)
	var services_pane: Panel = Parts.pane(Rect2(1260, 96, 648, 972))
	_screen.add_child(services_pane)
	var middle: CenterContainer = CenterContainer.new()
	Parts.inside(services_pane, 24).add_child(middle)
	var services: VBoxContainer = VBoxContainer.new()
	services.add_theme_constant_override("separation", 20)
	middle.add_child(services)
	for service: Control in [_removal(false, 30, 22), _duplication(false, 30, 22)]:
		service.custom_minimum_size = Vector2(600, 230)
		services.add_child(service)


# ---------------------------------------------------------------------------------------
# B, Window: one window on the Stage's ground, "Workshop" on its bar; the Mods in a column
# as the Satchel lists them; Removal, Duplication, the gold and the buttons down its side.
# ---------------------------------------------------------------------------------------

func _lay_out_window() -> void:
	var area: CenterContainer = CenterContainer.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var list: VBoxContainer = VBoxContainer.new()
	list.custom_minimum_size = Vector2(620, 0)
	list.add_theme_constant_override("separation", 12)
	body.add_child(list)
	for good: Parts.Good in _mods:
		var entry: Control = _mod_entry(good, 26, 20)
		entry.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.add_child(entry)
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(430, 0)
	side.add_theme_constant_override("separation", 12)
	body.add_child(side)
	side.add_child(_removal(false, 26, 20))
	side.add_child(_duplication(false, 26, 20))
	var room: Control = Control.new()
	room.custom_minimum_size = Vector2(0, 8)
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(room)
	var gold: Control = Parts.gold_panel(_gold(), true)
	gold.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side.add_child(gold)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	for button: Button in _buttons():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	side.add_child(buttons)


# ---------------------------------------------------------------------------------------
# C, Counter: a strip across the top, as the Run Bar lies across the Stage Map; the four
# Mods as tall tags in a row, each with its price at its foot; Removal and Duplication
# side by side under them, on parchment as the Mods are.
# ---------------------------------------------------------------------------------------

func _lay_out_counter() -> void:
	var strip: Panel = Parts.pane(Rect2(-2, -2, 1924, 82), 0, Parts.STRIP_EDGE)
	_screen.add_child(strip)
	_fill_bar(strip, 34, 34)
	var board: Panel = Parts.pane(Rect2(12, 92, 1896, 976))
	_screen.add_child(board)
	var centered: CenterContainer = CenterContainer.new()
	Parts.inside(board, 24).add_child(centered)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 28)
	centered.add_child(rows)
	var tags: HBoxContainer = HBoxContainer.new()
	tags.add_theme_constant_override("separation", 24)
	rows.add_child(tags)
	for good: Parts.Good in _mods:
		tags.add_child(_mod_tag(good))
	var services: HBoxContainer = HBoxContainer.new()
	services.add_theme_constant_override("separation", 24)
	rows.add_child(services)
	for service: Control in [_removal(true, 30, 22), _duplication(true, 30, 22)]:
		service.custom_minimum_size = Vector2(0, 200)
		service.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		services.add_child(service)


## A Mod as a tall tag: its name and type line at its head, its words under them, and its
## price at its foot. A Sold one is a hollow of its size.
func _mod_tag(good: Parts.Good) -> Control:
	var tag_size: Vector2 = Vector2(320, 400)
	if good.is_sold:
		return Parts.sold_space(tag_size, Parts.PAPER_RADIUS)
	var panel: PanelContainer = Parts.paper(Vector2(20, 18))
	panel.custom_minimum_size = tag_size
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.add_child(column)
	var title: Label = Parts.wrapped(good.name, 32, Parts.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var type_line: Label = Parts.wrapped(good.type_line, 20, Parts.INK_MUTED, false)
	type_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(type_line)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(Parts.PAPER_EDGE, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	var ruled: MarginContainer = MarginContainer.new()
	ruled.add_theme_constant_override("margin_top", 10)
	ruled.add_theme_constant_override("margin_bottom", 10)
	ruled.add_child(rule)
	column.add_child(ruled)
	for line: String in good.words:
		column.add_child(Parts.words(line, 22, Parts.INK))
	var room: Control = Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(room)
	column.add_child(Parts.price(good.price, good.price <= _gold(), true, 28))
	return panel


# ---------------------------------------------------------------------------------------
# What every arrangement is made of.
# ---------------------------------------------------------------------------------------

## The title at the left of [param bar], then the gold panel and the three buttons at its
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
	return [Parts.button("Satchel", "satchel"), Parts.button("Deckbox", "deckbox"), Parts.button("Leave")]


## A Mod as the Satchel draws one, with its price: its name with the price across from it,
## its type line, and its ModText words, on parchment. A Sold one is a hollow.
func _mod_entry(good: Parts.Good, name_size: int, body_size: int) -> Control:
	if good.is_sold:
		return Parts.sold_space(Vector2(0, 112), Parts.PAPER_RADIUS)
	var panel: PanelContainer = Parts.paper(Vector2(18, 14))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.add_child(column)
	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	column.add_child(heading)
	var title: Label = Parts.text(good.name, name_size, Parts.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(Parts.price(good.price, good.price <= _gold(), true, name_size))
	column.add_child(Parts.wrapped(good.type_line, body_size - 2, Parts.INK_MUTED, false))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)
	for line: String in good.words:
		column.add_child(Parts.words(line, body_size, Parts.INK))
	return panel


## The Removal panel: its name, what it does, its price and Choose a Card, which is off
## while the price cannot be paid.
func _removal(is_on_paper: bool, name_size: int, body_size: int) -> Control:
	var can_afford: bool = Parts.REMOVAL_PRICE <= _gold()
	var choose: Button = Parts.button(CHOOSE)
	choose.disabled = not can_afford
	return _service(REMOVAL, REMOVAL_WORDS, Parts.price(Parts.REMOVAL_PRICE, can_afford, is_on_paper, name_size - 2),
			choose, is_on_paper, name_size, body_size)


## The Duplication panel: its name, what it does and Choose a Card, or Sold once it has
## been used this visit. Its price is the chosen card's, so the panel shows none.
func _duplication(is_on_paper: bool, name_size: int, body_size: int) -> Control:
	var last: Control
	if _has_sold:
		last = Parts.text(SOLD, name_size - 2, Parts.INK_MUTED if is_on_paper else Parts.MUTED, true)
	else:
		last = Parts.button(CHOOSE)
	return _service(DUPLICATION, DUPLICATION_WORDS, null, last, is_on_paper, name_size, body_size)


## A service's panel: [param title] over [param sentence], and along its foot [param cost]
## (or nothing) at the left and [param last], its button or its Sold, at the right.
func _service(title: String, sentence: String, cost: Control, last: Control, is_on_paper: bool, name_size: int,
		body_size: int) -> Control:
	var panel: PanelContainer
	if is_on_paper:
		panel = Parts.paper(Vector2(22, 18))
	else:
		panel = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = SET_IN
		style.border_color = Parts.PANE_EDGE
		style.set_border_width_all(2)
		style.set_corner_radius_all(Parts.PANE_RADIUS)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 18
		style.content_margin_bottom = 18
		panel.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.add_child(column)
	column.add_child(Parts.text(title, name_size, Parts.INK if is_on_paper else Parts.TEXT, true))
	column.add_child(Parts.wrapped(sentence, body_size, Parts.INK if is_on_paper else Parts.TEXT, false))
	var room: Control = Control.new()
	room.custom_minimum_size = Vector2(0, 8)
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(room)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	column.add_child(foot)
	if cost != null:
		foot.add_child(cost)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	last.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(last)
	return panel


func _add_bar() -> void:
	var switches: Array[Button] = [
		Parts.bar_switch("<", func() -> void: _step_layout(-1)),
		Parts.bar_switch(LAYOUT_NAMES[_layout], func() -> void: _step_layout(1)),
		Parts.bar_switch(">", func() -> void: _step_layout(1)),
		Parts.bar_switch("Stock (S): %s" % STOCK_NAMES[_stock], func() -> void:
			_stock = ((_stock + 1) % Stock.size()) as Stock
			_rebuild()),
		Parts.bar_switch("Gold (G): %d" % _gold(), func() -> void:
			_is_poor = not _is_poor
			_rebuild()),
		Parts.bar_switch("Sold (X): %s" % ("on" if _has_sold else "off"), func() -> void:
			_has_sold = not _has_sold
			_rebuild()),
	]
	_bar = Parts.switch_bar(switches, "PROTOTYPE · Workshop, step 1 · H hides this")
	add_child(_bar)


func _step_layout(by: int) -> void:
	_layout = ((_layout + Layout.size() + by) % Layout.size()) as Layout
	_rebuild()


## The four Mods in stock, Content's own, cheapest first and then by name.
func _make_mods() -> void:
	_mods.clear()
	for file: String in STOCKS[_stock]:
		var mod: Mod = load(MODS % file) as Mod
		var good: Parts.Good = Parts.Good.new()
		good.kind = Parts.Kind.MOD
		good.mod = mod
		good.name = mod.name
		good.type_line = Parts.mod_type_line(mod)
		good.words = [ModText.of(mod)]
		good.price = Parts.MOD_PRICES[mini(mod.rarity, Parts.MOD_PRICES.size() - 1)]
		_mods.append(good)
	_mods.sort_custom(func(a: Parts.Good, b: Parts.Good) -> bool:
		return a.price < b.price if a.price != b.price else a.name.naturalnocasecmp_to(b.name) < 0)
	if _has_sold:
		_mods[0].is_sold = true
		_mods[2].is_sold = true
