extends Control
## PROTOTYPE (milestone 25, step 3 of 3): the Workshop in the arrangement step 1 chose (C,
## Counter: the four Mods as tall tags in a row, each with its price at its foot, and
## Removal and Duplication side by side under them, on parchment as the Mods are), with
## step 2's buying of Mods, and now Removal and Duplication through the Collection Window.
## It stands under the Store's own top bar, so the two shops share their gold panel and
## buttons. Built from the Store prototype's parts (prototypes/store_screen/shop_parts.gd
## and collection_window.gd). Throwaway: deleted after sign-off, once the real screen is
## ported test-first. Nothing here changes a run: the four Mods are Content's own, the
## Collection is a sample, the gold is the prototype's own, and Deckbox and Leave do
## nothing yet.
##
## godot --path . res://prototypes/workshop_screen/workshop_screen.tscn -- --run-seed=7 --stage=white
##
## What step 2 does:
##   A click on a Mod selects it: its tag rises and Buy shows at its foot, across from its
##   price, off while the Mod cannot be afforded. A click on it again, or on nothing, lets
##   it go, and a click on another Mod selects that one instead.
##   Buy buys it: the gold counts down as the Store's does, a Sold space eases in where the
##   tag stood, and every price that can no longer be afforded turns red, Removal's
##   included, whose Choose a Card goes off with it.
##
## The bar at the foot of the screen, or the keys:
##   S  the stock: typical, or the four wordiest Mods in Content
##   G  the gold held at the start: 480 or 55
##   X  whether the Duplication has been used this visit, so that its panel reads Sold
##   R  restocks, undoing every purchase
##   H  hides the bar
## --stock=wordy, --poor, --used and --no-bar start it that way. To drive it for a picture,
## in the order given, each with a real mouse event: --click="Violent", --click-buy and
## --click-ground; --screenshot=/absolute/path.png then saves a picture and quits, with
## nothing eased.
##
## What step 3 does: each Choose a Card opens the Collection Window on a sample
## Collection of some fifty cards, six of them carrying Mods or a Hex. A Removal or a
## Duplication paid for there counts the Workshop's gold down too, and once a card is
## duplicated the Duplication's panel reads Sold. --bare starts with no Mod or Hex on any
## card. --click-removal and --click-duplication open the window for a picture, and then
## --pick="Card Name", --pick-mod=1, --confirm and --close drive it.
## Satchel opens the Satchel's own prototype (prototypes/satchel/, on its own sample
## Items) over the Workshop, which buys every Item that is not a card: each Armor, Mod and
## Potion has a sell button, "Sell" with the coin and what the Workshop pays, then
## "Confirm", then one is sold and the gold counts up. This is how the Hero sells at a
## Workshop. --click-satchel opens it for a picture, and then
## --satchel-page=mods, --sell="Savage" (once for Confirm, again to sell) and
## --satchel-close drive it.

enum Stock { TYPICAL, WORDY }

const Parts = preload("res://prototypes/store_screen/shop_parts.gd")
const CollectionWindow = preload("res://prototypes/store_screen/collection_window.gd")
const Satchel = preload("res://prototypes/satchel/satchel.gd")
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
const RICH: int = 480
const POOR: int = 55
const TAG_SIZE: Vector2 = Vector2(320, 400)
## How far a selected tag rises.
const TAG_LIFT: float = 10.0
## A point of the board that nothing stands on, for --click-ground.
const EMPTY_SPOT: Vector2 = Vector2(40, 130)

var _stock: Stock = Stock.TYPICAL
var _is_poor: bool = false
var _is_duplication_used: bool = false
var _is_bar_shown: bool = true
## How long a tag takes to rise, Buy to show and a Sold space to ease in, and how long the
## gold takes to count; none of either while a picture is being made.
var _ease_seconds: float = 0.0
var _count_seconds: float = 0.0
var _run: Run = null
var _screen: Control = null
var _bar: Control = null
var _mods: Array[Parts.Good] = []
var _spots: Dictionary[Parts.Good, Parts.Spot] = {}
var _gold: int = RICH
## The gold panel's number.
var _count: Label = null
var _selected: Parts.Good = null
var _removal_price: HBoxContainer = null
var _removal_button: Button = null
var _duplication_button: Button = null
## The sample Collection, with Mods and Hexes on some cards unless it is bare, and the
## Collection Window while it is open.
var _is_bare: bool = false
var _is_driven: bool = false
var _held: Parts.Holdings = null
var _window: CollectionWindow = null
## The Satchel's own prototype, standing over this shop with a sell button on what it buys.
var _satchel: Satchel = null
var _satchel_button: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument.begins_with("--stock="):
			for stock: Stock in STOCK_NAMES:
				if STOCK_NAMES[stock] == argument.trim_prefix("--stock=").to_lower():
					_stock = stock
		elif argument == "--poor":
			_is_poor = true
		elif argument == "--used":
			_is_duplication_used = true
		elif argument == "--bare":
			_is_bare = true
		elif argument == "--no-bar":
			_is_bar_shown = false
	var picture: String = EncounterScreen.screenshot_path(arguments)
	_is_driven = picture != ""
	if picture == "":
		var speed: GameSpeed.Speed = GameSettings.load_from(GameSettings.PATH).game_speed
		_ease_seconds = GameSpeed.seconds(Pacing.EASE_SECONDS, speed)
		_count_seconds = GameSpeed.seconds(Parts.COUNT_SECONDS, speed)
	_run = StageMapScreen.debug_run_from(arguments)
	_rebuild()
	for argument: String in arguments:
		for frame: int in 3:
			await get_tree().process_frame
		if _window != null and await _window.drive(argument):
			continue
		if _satchel.drive(argument):
			continue
		if argument == "--click-satchel":
			Parts.click_on(_satchel_button)
			continue
		if argument == "--click-removal":
			Parts.click_on(_removal_button)
		elif argument == "--click-duplication" and _duplication_button != null:
			Parts.click_on(_duplication_button)
		elif argument.begins_with("--click=") and _spot_named(argument.trim_prefix("--click=")) != null:
			Parts.click_on(_spot_named(argument.trim_prefix("--click=")).target)
		elif argument == "--click-buy" and _selected != null:
			Parts.click_on(Parts.buy_of(_spots[_selected].buy_slot))
		elif argument == "--click-ground":
			Parts.click_at(get_viewport(), EMPTY_SPOT)
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
		KEY_S:
			_stock = ((_stock + 1) % Stock.size()) as Stock
		KEY_G:
			_is_poor = not _is_poor
		KEY_X:
			_is_duplication_used = not _is_duplication_used
		KEY_R:
			pass
		KEY_H:
			_is_bar_shown = not _is_bar_shown
		_:
			return
	_rebuild()


## Builds the Workshop again as it is when the Hero arrives: fully stocked, nothing
## selected, and the starting gold held.
func _rebuild() -> void:
	if _screen != null:
		_screen.queue_free()
	if _bar != null:
		_bar.queue_free()
		_bar = null
	_selected = null
	_spots.clear()
	_window = null
	_held = Parts.sample_holdings(not _is_bare)
	_gold = POOR if _is_poor else RICH
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_screen.add_child(StageIntro.ground_panel(_run.stage_visit.stage))
	# A click on nothing lets the selected Mod go.
	_screen.add_child(Parts.ground_catcher(func() -> void: _select(null)))
	_make_mods()
	_lay_out()
	_satchel = Satchel.new()
	_satchel.is_at_shop = true
	_satchel.is_driven = _is_driven
	# The Workshop buys every Item that is not a card, whatever it sells itself.
	_satchel.sells = [Satchel.Page.ARMOR, Satchel.Page.MODS, Satchel.Page.POTIONS]
	_satchel.sold.connect(func(price: int) -> void: _on_gold_changed(_gold + price))
	_screen.add_child(_satchel)
	if _is_bar_shown:
		_add_bar()


func _can_afford(good: Parts.Good) -> bool:
	return good.price <= _gold


## The arrangement step 1 chose, under the Store's top bar: the four Mods as tall tags in
## a row, and Removal and Duplication side by side under them.
func _lay_out() -> void:
	var bar: Panel = Parts.pane(Rect2(12, 12, 1896, 72))
	_screen.add_child(bar)
	_satchel_button = Parts.button("Satchel", "satchel")
	_satchel_button.pressed.connect(func() -> void: _satchel.open_at_shop())
	_count = Parts.fill_bar(bar, TITLE, _gold, [_satchel_button, Parts.button("Deckbox", "deckbox"), Parts.button("Leave")])
	var board: Panel = Parts.pane(Rect2(12, 96, 1896, 972))
	_screen.add_child(board)
	var centered: CenterContainer = CenterContainer.new()
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Parts.inside(board, 24).add_child(centered)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 28)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centered.add_child(rows)
	var tags: HBoxContainer = HBoxContainer.new()
	tags.add_theme_constant_override("separation", 24)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(tags)
	for good: Parts.Good in _mods:
		var spot: Parts.Spot = _mod_tag(good)
		_spots[good] = spot
		tags.add_child(spot.root)
	var services: HBoxContainer = HBoxContainer.new()
	services.add_theme_constant_override("separation", 24)
	services.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(services)
	for service: Control in [_removal(), _duplication()]:
		service.custom_minimum_size = Vector2(0, 200)
		service.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		services.add_child(service)


## A Mod as a tall tag: its name and type line at its head, its words under them, and at
## its foot its price, with room across from it for its Buy.
func _mod_tag(good: Parts.Good) -> Parts.Spot:
	var spot: Parts.Spot = Parts.Spot.new()
	spot.good = good
	spot.is_price_on_paper = true
	var panel: PanelContainer = Parts.paper(Vector2(20, 18))
	panel.custom_minimum_size = TAG_SIZE
	var holder: MarginContainer = MarginContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	spot.holder = holder
	spot.target = panel
	spot.lifter = Parts.lifter(holder, TAG_LIFT, Parts.PAPER_RADIUS)
	spot.root = spot.lifter
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ruled: MarginContainer = MarginContainer.new()
	ruled.add_theme_constant_override("margin_top", 10)
	ruled.add_theme_constant_override("margin_bottom", 10)
	ruled.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ruled.add_child(rule)
	column.add_child(ruled)
	for line: String in good.words:
		column.add_child(Parts.words(line, 22, Parts.INK))
	var room: Control = Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(room)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	spot.price_row = Parts.price(good.price, _can_afford(good), true, 28)
	spot.price_row.size_flags_vertical = Control.SIZE_SHRINK_END
	foot.add_child(spot.price_row)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(spacer)
	spot.buy_slot = Parts.buy_slot(true)
	foot.add_child(spot.buy_slot)
	Parts.buy_of(spot.buy_slot).pressed.connect(func() -> void: _buy(good))
	Parts.watch(panel, good, func(_over: Parts.Good) -> void: pass, _on_click)
	return spot


## The Removal panel: its name, what it does, its price and Choose a Card, which is off
## while the price cannot be paid.
func _removal() -> Control:
	var can_afford: bool = Parts.REMOVAL_PRICE <= _gold
	_removal_price = Parts.price(Parts.REMOVAL_PRICE, can_afford, true, 28)
	_removal_button = Parts.button(CHOOSE)
	_removal_button.disabled = not can_afford
	_removal_button.pressed.connect(func() -> void: _open_window(CollectionWindow.Use.REMOVE))
	return _service(REMOVAL, REMOVAL_WORDS, _removal_price, _removal_button)


## The Duplication panel: its name, what it does and Choose a Card, or Sold once it has
## been used this visit. Its price is the chosen card's, so the panel shows none.
func _duplication() -> Control:
	_duplication_button = null
	if _is_duplication_used:
		return _service(DUPLICATION, DUPLICATION_WORDS, null, Parts.text(Parts.SOLD, 28, Parts.INK_MUTED, true))
	_duplication_button = Parts.button(CHOOSE)
	_duplication_button.pressed.connect(func() -> void: _open_window(CollectionWindow.Use.DUPLICATE))
	return _service(DUPLICATION, DUPLICATION_WORDS, null, _duplication_button)


## A service's panel, on parchment: [param title] over [param sentence], and along its
## foot [param cost] (or nothing) at the left and [param last], its button or its Sold, at
## the right.
func _service(title: String, sentence: String, cost: Control, last: Control) -> Control:
	var panel: PanelContainer = Parts.paper(Vector2(22, 18))
	# A click on a service's panel is not a click on the ground.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	column.add_child(Parts.text(title, 30, Parts.INK, true))
	column.add_child(Parts.wrapped(sentence, 22, Parts.INK, false))
	var room: Control = Control.new()
	room.custom_minimum_size = Vector2(0, 8)
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(room)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	if cost != null:
		foot.add_child(cost)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(spacer)
	last.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(last)
	return panel


# ---------------------------------------------------------------------------------------
# Step 2: buying Mods.
# ---------------------------------------------------------------------------------------

## A click on [param good] selects it, or lets it go if it is the one selected.
func _on_click(good: Parts.Good) -> void:
	_select(null if good == _selected else good)


## Selects [param good] in place of whatever was selected, or nothing for null.
func _select(good: Parts.Good) -> void:
	if good == _selected:
		return
	if _selected != null:
		Parts.set_selected(_spots[_selected], false, false, _ease_seconds)
	_selected = good
	if good != null:
		Parts.set_selected(_spots[good], true, _can_afford(good), _ease_seconds)


## Buys [param good], if it can be afforded: the gold counts down, a Sold space takes its
## place, and what can no longer be afforded turns red, Removal included.
func _buy(good: Parts.Good) -> void:
	if good == null or good.is_sold or not _can_afford(good):
		return
	_gold -= good.price
	good.is_sold = true
	Parts.count_gold(_count, _gold, _count_seconds)
	Parts.sell_out(_spots[good], _ease_seconds)
	_selected = null
	_mark_prices()


# ---------------------------------------------------------------------------------------
# Step 3: Removal and Duplication through the Collection Window.
# ---------------------------------------------------------------------------------------

## A Choose a Card opens the Collection Window over the Workshop for [param use].
func _open_window(use: CollectionWindow.Use) -> void:
	if _window != null:
		return
	_window = CollectionWindow.new()
	_window.is_driven = _is_driven
	_screen.add_child(_window)
	_window.setup(use, _held, _gold, _ease_seconds, _count_seconds)
	_window.gold_changed.connect(_on_gold_changed)
	_window.duplicated.connect(_on_duplicated)
	_window.closed.connect(func() -> void: _window = null)


## A Removal or a Duplication has been paid for: the Workshop's own panel counts too, and
## each price is red or not as the gold now covers it.
func _on_gold_changed(gold: int) -> void:
	_gold = gold
	Parts.count_gold(_count, _gold, _count_seconds)
	_mark_prices()


## The visit's one Duplication is used: its panel reads Sold where Choose a Card was.
func _on_duplicated() -> void:
	_is_duplication_used = true
	var foot: Control = _duplication_button.get_parent() as Control
	_duplication_button.queue_free()
	_duplication_button = null
	var sold: Label = Parts.text(Parts.SOLD, 28, Parts.INK_MUTED, true)
	sold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(sold)
	Easing.fade_in(sold, _ease_seconds)


## Writes every price in its plain color or in red, as the gold covers it now, Removal's
## included, whose Choose a Card is off while its price cannot be paid.
func _mark_prices() -> void:
	for other: Parts.Good in _spots:
		if not other.is_sold:
			Parts.mark_price(_spots[other].price_row, _can_afford(other), true)
	if _selected != null:
		Parts.buy_of(_spots[_selected].buy_slot).disabled = not _can_afford(_selected)
	var can_remove: bool = Parts.REMOVAL_PRICE <= _gold
	Parts.mark_price(_removal_price, can_remove, true)
	_removal_button.disabled = not can_remove


func _spot_named(good_name: String) -> Parts.Spot:
	for good: Parts.Good in _spots:
		if good.name == good_name and not good.is_sold:
			return _spots[good]
	return null


func _add_bar() -> void:
	var switches: Array[Button] = [
		Parts.bar_switch("Stock (S): %s" % STOCK_NAMES[_stock], func() -> void:
			_stock = ((_stock + 1) % Stock.size()) as Stock
			_rebuild()),
		Parts.bar_switch("Gold (G): %d" % (POOR if _is_poor else RICH), func() -> void:
			_is_poor = not _is_poor
			_rebuild()),
		Parts.bar_switch("Duplication used (X): %s" % ("yes" if _is_duplication_used else "no"), func() -> void:
			_is_duplication_used = not _is_duplication_used
			_rebuild()),
		Parts.bar_switch("Restock (R)", _rebuild),
	]
	_bar = Parts.switch_bar(switches, "PROTOTYPE · Workshop, step 3 · H hides this")
	add_child(_bar)


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
