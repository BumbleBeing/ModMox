extends Control
## PROTOTYPE (milestone 24, step 3 of 3): the Store in the arrangement step 1 chose (A,
## Bench: a top bar, the Inspector, the cards five across at 280 pixels and the Items as
## Satchel entries in a column), with step 2's selecting, Buy, Sold and gold's count, and
## now selling cards through the Collection Window (collection_window.gd).
## Throwaway: deleted after sign-off, once the real screen is ported test-first. Nothing
## here changes a run: the goods and the Collection are samples, the gold is the
## prototype's own, and Deckbox and Leave do nothing yet.
##
## godot --path . res://prototypes/store_screen/store_screen.tscn -- --run-seed=7 --stage=white
##
## What step 2 does:
##   A click on a good selects it: it rises, the Inspector holds it whatever the cursor is
##   over, and Buy shows, off while the good cannot be afforded. A click on it again, or on
##   nothing, lets it go, and a click on another good selects that one instead.
##   Buy shows under the good, chosen over the foot of the Inspector: under a card's price,
##   in room kept for it, and under an Item's price, its entry growing to show it.
##   Buy buys it: the gold counts down as the Spoils' gold counts (0.6 seconds at Blazing,
##   easing out, at the Game Speed in the settings), a Sold space eases in where the good
##   stood, and every price that can no longer be afforded turns red. Nothing is bought on
##   one click, and nothing moves when a good is bought.
##
## The bar at the foot of the screen, or the keys:
##   S  the stock: typical (6 cards, 2 Potions, 1 Armor), nine cards, or few cards (4 cards,
##      3 Potions, 2 Armor)
##   M  whether some cards carry Mods and Hexes
##   G  the gold held at the start: 480 or 55
##   R  restocks, undoing every purchase
##   H  hides the bar
## --stock=nine (or few), --plain, --poor and --no-bar start it that way.
## To drive it for a picture, in the order given, each with a real mouse event:
## --hover="Big Gulp", --click="Violent Shivan Dragon", --click-buy and --click-ground;
## --screenshot=/absolute/path.png then saves a picture and quits, with nothing eased.
##
## What step 3 does so far: Sell Cards opens the Collection Window on a sample Collection
## of some fifty cards in three Decks (Aggro, Control and Midrange). Selling a card there
## counts the Store's gold up too, and a price the gold now covers is red no longer.
## --click-sell-cards opens it for a picture, and then --pick="Card Name", --confirm and
## --close drive it.
## Satchel opens the Satchel's own prototype (prototypes/satchel/, on its own sample
## Items) over the Store, with a sell button on each Armor and each Potion: "Sell" with
## the coin and what the Store pays, then "Confirm", then one is sold and the gold counts
## up. --click-satchel opens it for a picture, and then --satchel-page=potions,
## --sell="Fogbrew" (once for Confirm, again to sell) and --satchel-close drive it.

enum Stock { TYPICAL, NINE_CARDS, FEW_CARDS }

const Parts = preload("res://prototypes/store_screen/shop_parts.gd")
const CollectionWindow = preload("res://prototypes/store_screen/collection_window.gd")
const Satchel = preload("res://prototypes/satchel/satchel.gd")
const STOCK_NAMES: Dictionary[Stock, String] = {
	Stock.TYPICAL: "typical", Stock.NINE_CARDS: "nine", Stock.FEW_CARDS: "few",
}
const TITLE: String = "Store"
const RICH: int = 480
const POOR: int = 55
const CARD_HEIGHT: float = 280.0
## A point of the cards' pane that no card ever stands on, for --click-ground.
const EMPTY_SPOT: Vector2 = Vector2(380, 112)
const INSPECTOR_WIDTH: float = 340.0
const INSPECTOR_PAD: float = 10.0
const CARDS: String = "res://content/cards/%s.tres"
const MODS: String = "res://content/mods/%s.tres"
const DIVINERS_BOON: String = "res://content/emblems/diviners_boon.tres"
const LIFE_WORDS: String = "You start each encounter with %d more life."

var _stock: Stock = Stock.TYPICAL
var _has_mods: bool = true
var _is_poor: bool = false
var _is_bar_shown: bool = true
## How long a good takes to rise, Buy to show and a Sold space to ease in, and how long the
## gold takes to count; none of either while a picture is being made.
var _ease_seconds: float = 0.0
var _count_seconds: float = 0.0
var _run: Run = null
var _screen: Control = null
var _bar: Control = null
var _cards: Array[Parts.Good] = []
var _items: Array[Parts.Good] = []
var _spots: Dictionary[Parts.Good, Parts.Spot] = {}
var _gold: int = RICH
## The gold panel's number.
var _count: Label = null
var _selected: Parts.Good = null
var _hovered: Parts.Good = null
## What the Inspector is showing: the selected good, or with none the one under the cursor.
var _shown: Parts.Good = null
var _inspector: DeckbuilderInspector = null
var _item_holder: Control = null
var _next_id: int = 0
## The sample Collection and its Decks, and the Collection Window while it is open.
var _held: Parts.Holdings = null
var _window: CollectionWindow = null
## The Satchel's own prototype, standing over this shop with a sell button on what it buys.
var _satchel: Satchel = null
var _satchel_button: Button = null
var _sell_cards: Button = null
## Whether a picture is being made, the flags driving the mouse.
var _is_driven: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for argument: String in arguments:
		if argument.begins_with("--stock="):
			for stock: Stock in STOCK_NAMES:
				if STOCK_NAMES[stock] == argument.trim_prefix("--stock=").to_lower():
					_stock = stock
		elif argument == "--plain":
			_has_mods = false
		elif argument == "--poor":
			_is_poor = true
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
		if argument == "--click-sell-cards":
			Parts.click_on(_sell_cards)
		elif argument.begins_with("--hover=") and _spot_named(argument.trim_prefix("--hover=")) != null:
			Parts.move_mouse_to(_spot_named(argument.trim_prefix("--hover=")).target)
		elif argument.begins_with("--click=") and _spot_named(argument.trim_prefix("--click=")) != null:
			Parts.click_on(_spot_named(argument.trim_prefix("--click=")).target)
		elif argument == "--click-buy" and _showing_buy() != null:
			Parts.click_on(_showing_buy())
		elif argument == "--click-ground":
			_hovered = null
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
		KEY_M:
			_has_mods = not _has_mods
		KEY_G:
			_is_poor = not _is_poor
		KEY_R:
			pass
		KEY_H:
			_is_bar_shown = not _is_bar_shown
		_:
			return
	_rebuild()


## Builds the Store again as it is when the Hero arrives: fully stocked, nothing selected,
## and the starting gold held.
func _rebuild() -> void:
	if _screen != null:
		_screen.queue_free()
	if _bar != null:
		_bar.queue_free()
		_bar = null
	_selected = null
	_hovered = null
	_shown = null
	_spots.clear()
	_window = null
	_held = Parts.sample_holdings(_has_mods)
	_gold = POOR if _is_poor else RICH
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_screen.add_child(StageIntro.ground_panel(_run.stage_visit.stage))
	# A click on nothing lets the selected good go.
	_screen.add_child(Parts.ground_catcher(func() -> void: _select(null)))
	_make_goods()
	_lay_out()
	_satchel = Satchel.new()
	_satchel.is_at_shop = true
	_satchel.is_driven = _is_driven
	_satchel.sells = [Satchel.Page.ARMOR, Satchel.Page.POTIONS]
	_satchel.sold.connect(func(price: int) -> void: _on_gold_changed(_gold + price))
	_screen.add_child(_satchel)
	if _is_bar_shown:
		_add_bar()


func _can_afford(good: Parts.Good) -> bool:
	return good.price <= _gold


## The arrangement step 1 chose: a top bar with the title, the gold and the buttons; the
## Inspector down the left; the cards five across; the Items in a column at the right.
func _lay_out() -> void:
	var bar: Panel = Parts.pane(Rect2(12, 12, 1896, 72))
	_screen.add_child(bar)
	_sell_cards = Parts.button("Sell Cards")
	_sell_cards.pressed.connect(_open_window)
	_satchel_button = Parts.button("Satchel", "satchel")
	_satchel_button.pressed.connect(func() -> void: _satchel.open_at_shop())
	_count = Parts.fill_bar(bar, TITLE, _gold, [_sell_cards, _satchel_button, Parts.button("Deckbox", "deckbox"),
			Parts.button("Leave")])
	_add_inspector(Rect2(12, 96, INSPECTOR_WIDTH, 972))
	var items_width: float = 388.0
	var right: float = 1908.0 - (items_width + 12.0 if not _items.is_empty() else 0.0)
	var cards_pane: Panel = Parts.pane(Rect2(364, 96, right - 364.0, 972))
	_screen.add_child(cards_pane)
	var centered: CenterContainer = CenterContainer.new()
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Parts.inside(cards_pane, 24).add_child(centered)
	centered.add_child(_card_grid(5, 20))
	if not _items.is_empty():
		var items_pane: Panel = Parts.pane(Rect2(1908.0 - items_width, 96, items_width, 972))
		_screen.add_child(items_pane)
		Parts.inside(items_pane, 12).add_child(_item_list())


## The cards for sale, at most [param columns] to a row, each with its price under it and
## room for its Buy under that.
func _card_grid(columns: int, across: int) -> VBoxContainer:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = null
	# The rows are evened out: six cards stand three and three, not five and one.
	var row_count: int = ceili(_cards.size() / float(columns))
	var per_row: int = ceili(_cards.size() / float(maxi(row_count, 1)))
	for index: int in _cards.size():
		if index % per_row == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", across)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rows.add_child(row)
		var good: Parts.Good = _cards[index]
		var spot: Parts.Spot = Parts.card_spot(good, CARD_HEIGHT, _can_afford(good), true, _on_hover, _on_click)
		_keep(spot)
		row.add_child(spot.root)
	return rows


## The Items for sale as Satchel entries, Potions and then Armor, scrolling if they must.
func _item_list() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# With the room each entry keeps above it to rise into, entries stand 12 pixels apart.
	list.add_theme_constant_override("separation", int(12.0 - Parts.ENTRY_LIFT))
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)
	for good: Parts.Good in _items:
		var spot: Parts.Spot = Parts.item_spot(good, _can_afford(good), true, _on_hover, _on_click)
		_keep(spot)
		list.add_child(spot.root)
	return scroll


func _keep(spot: Parts.Spot) -> void:
	_spots[spot.good] = spot
	if spot.buy_slot != null:
		var good: Parts.Good = spot.good
		Parts.buy_of(spot.buy_slot).pressed.connect(func() -> void: _buy(good))


## The Inspector on a pane at [param place]: the deckbuilder's own, without Apply a Mod and
## without the deckbuilder's hint, whose words are not the Store's.
func _add_inspector(place: Rect2) -> void:
	var pane: Panel = Parts.pane(place)
	pane.theme = DeckbuilderLook.theme()
	# A click on the Inspector is not a click on the ground.
	pane.mouse_filter = Control.MOUSE_FILTER_STOP
	pane.clip_contents = true
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
	_inspector.position = Vector2(INSPECTOR_PAD, INSPECTOR_PAD)
	_inspector.size = room + Vector2(0, apply.get_combined_minimum_size().y + DeckbuilderInspector.GAP)
	_item_holder = Control.new()
	_item_holder.position = Vector2(INSPECTOR_PAD, INSPECTOR_PAD)
	_item_holder.size = room
	_item_holder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_item_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.add_child(_item_holder)


# ---------------------------------------------------------------------------------------
# Step 2: selecting, Buy, Sold and the gold's count.
# ---------------------------------------------------------------------------------------

## The cursor has come over [param good], or left one (null). While a picture is being
## made the cursor is only where the flags put it: the real one, outside the window, would
## otherwise take every hover away.
func _on_hover(good: Parts.Good) -> void:
	if good == null and _is_driven:
		return
	_hovered = good
	_show_inspected()


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
	_show_inspected()


## Buys [param good], if it can be afforded: the gold counts down, a Sold space takes its
## place, and what can no longer be afforded turns red.
func _buy(good: Parts.Good) -> void:
	if good == null or good.is_sold or not _can_afford(good):
		return
	_gold -= good.price
	good.is_sold = true
	Parts.count_gold(_count, _gold, _count_seconds)
	Parts.sell_out(_spots[good], _ease_seconds)
	_selected = null
	if _hovered == good:
		_hovered = null
	for other: Parts.Good in _spots:
		if not other.is_sold:
			Parts.mark_price(_spots[other].price_row, _can_afford(other), _spots[other].is_price_on_paper)
	_show_inspected()


# ---------------------------------------------------------------------------------------
# Step 3: selling cards through the Collection Window.
# ---------------------------------------------------------------------------------------

## Sell Cards opens the Collection Window over the Store.
func _open_window() -> void:
	if _window != null:
		return
	_window = CollectionWindow.new()
	_window.is_driven = _is_driven
	_screen.add_child(_window)
	_window.setup(CollectionWindow.Use.SELL, _held, _gold, _ease_seconds, _count_seconds)
	_window.gold_changed.connect(_on_gold_changed)
	_window.closed.connect(func() -> void: _window = null)


## A sale has changed the gold: the Store's own panel counts too, and each price is red or
## not as the gold now covers it.
func _on_gold_changed(gold: int) -> void:
	_gold = gold
	Parts.count_gold(_count, _gold, _count_seconds)
	for good: Parts.Good in _spots:
		if not good.is_sold:
			Parts.mark_price(_spots[good].price_row, _can_afford(good), _spots[good].is_price_on_paper)
	if _selected != null:
		Parts.buy_of(_spots[_selected].buy_slot).disabled = not _can_afford(_selected)


## The Buy button that is showing now, or null: for --click-buy.
func _showing_buy() -> Button:
	return Parts.buy_of(_spots[_selected].buy_slot) if _selected != null else null


func _spot_named(good_name: String) -> Parts.Spot:
	for good: Parts.Good in _spots:
		if good.name == good_name and not good.is_sold:
			return _spots[good]
	return null


## Shows the selected good in the Inspector, or with none selected the one under the
## cursor, or nothing.
func _show_inspected() -> void:
	var good: Parts.Good = _selected if _selected != null else _hovered
	if good == _shown:
		return
	_shown = good
	var is_card: bool = good != null and good.kind == Parts.Kind.CARD
	_inspector.show_card(good.card if is_card else null, (INSPECTOR_WIDTH - 2.0 * INSPECTOR_PAD) / CardGeometry.ASPECT,
			_ease_seconds)
	InspectorParts.clear(_item_holder)
	if good != null and not is_card:
		_item_holder.add_child(_item_readout(good))


## An Item as the Inspector might show it, after the encounter's Potion Readout: its picture
## large, its name and its type line, and what it does in a Card Text panel.
func _item_readout(good: Parts.Good) -> Control:
	var palette: InspectorParts.Palette = DeckbuilderLook.inspector_palette()
	var width: float = INSPECTOR_WIDTH - 2.0 * INSPECTOR_PAD
	var side: float = 204.0
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_holder: Control = Control.new()
	art_holder.custom_minimum_size = Vector2(width, side + 40.0)
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ground: StyleBoxFlat = StyleBoxFlat.new()
		ground.bg_color = Parts.SLOT_GROUND
		ground.border_color = Color("#1c120b")
		ground.set_border_width_all(2)
		slot.add_theme_stylebox_override("panel", ground)
		var icon: TextureRect = Parts.picture(good.armor_icon, 6.0)
		icon.position = Vector2(6, 6)
		slot.add_child(icon)
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
		Parts.bar_switch("Stock (S): %s" % STOCK_NAMES[_stock], func() -> void:
			_stock = ((_stock + 1) % Stock.size()) as Stock
			_rebuild()),
		Parts.bar_switch("Mods and Hexes (M): %s" % ("on" if _has_mods else "off"), func() -> void:
			_has_mods = not _has_mods
			_rebuild()),
		Parts.bar_switch("Gold (G): %d" % (POOR if _is_poor else RICH), func() -> void:
			_is_poor = not _is_poor
			_rebuild()),
		Parts.bar_switch("Restock (R)", _rebuild),
	]
	_bar = Parts.switch_bar(switches, "PROTOTYPE · Store, step 3 · H hides this")
	add_child(_bar)


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
