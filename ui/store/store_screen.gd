class_name StoreScreen
extends Control
## The Store (game glossary; milestone 24, ADRs 0070 and 0071, signed off as
## prototypes/store_screen/): a full screen of its own on the Stage Intro's ground, opened on
## arriving at a Store's Node and again from the Stage Map by a click on that Node, as it was
## left, until the Hero moves on. A pane across the top holds "Store" at its left and the gold
## panel, Sell Cards, Satchel, Deckbox and Leave at its right. Under it stand the Inspector,
## which shows the selected good or, with none selected, the one under the cursor; the cards,
## at most five to a row, cheapest first; and the Items, Potions and then Armor, as Satchel
## entries in a column. Every good shows its price with the coin, red when the gold does not
## cover it.
##
## A click on a good selects it: it rises and its Buy shows under it, off while it cannot be
## afforded; a click on it again, or on nothing, lets it go. Buy buys it: the gold counts
## down, a Sold space takes its place, and nothing else moves. Sell Cards opens the Collection
## Window, Satchel the Satchel over the Store, Deckbox the Deckbox, which closes back here, and
## Leave the Stage Map. There is no shopkeeper, and it takes the mouse only.
##
## --store opens the Store of a debug run (--run-seed=N, --stage=red, --tier=N as the Stage
## Map takes them), honoring --screenshot=/absolute/path.png.
## Later (milestone 24): a sell button on the Satchel's entries while it is open here.

const FLAG: String = "--store"
const TITLE: String = "Store"
const SELL_CARDS: String = "Sell Cards"
const SATCHEL: String = "Satchel"
const DECKBOX: String = "Deckbox"
const LEAVE: String = "Leave"

## Whether the screen reads the run from RunFlow when it is ready. Tests hand it one.
var starts_itself: bool = true
## How the screen opens another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: SceneFade.change_scene(get_tree(), scene)
## Whether goods ease and the gold counts; a screen that is not paced shows everything at once.
var is_paced: bool = false
## Whether the Inspector shows the good under the cursor. Not while a picture is made, when
## the real cursor, wherever it is on the desktop, is no part of it.
var follows_cursor: bool = true
var game_speed: GameSpeed.Speed = GameSpeed.Speed.NORMAL
## The Pause Menu over the screen (milestone 21), made by begin().
var run_pause: RunPause = null
## Whether a Store has been left, so the --store flag opens it only once.
static var has_left: bool = false

var _run: Run = null
var _ground: Control = null
var _title: Label = null
var _count: Label = null
var _buttons: Array[Button] = []
var _inspector: DeckbuilderInspector = null
var _item_holder: Control = null
var _card_rows: Array = []
var _items: Array[StoreGood] = []
var _spots: Dictionary[StoreGood, StoreSpot] = {}
var _selected: StoreGood = null
var _hovered: StoreGood = null
## What the Inspector is showing: the selected good, or with none the one under the cursor.
var _shown: StoreGood = null
var _satchel: SatchelWindow = null
var _window: CollectionWindow = null


func _ready() -> void:
	if not starts_itself:
		return
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var picture: String = EncounterScreen.screenshot_path(arguments)
	is_paced = picture == ""
	follows_cursor = picture == ""
	game_speed = GameSettings.load_from(GameSettings.PATH).game_speed
	if RunFlow.run == null:
		RunFlow.start(StageMapScreen.debug_run_from(arguments))
		RunFlow.finish_intro()
		walk_to_a_store(RunFlow.run)
		RunFlow.arrive()
	begin(RunFlow.run)
	if picture != "":
		for frame: int in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## Moves the Hero of [param run], on its Start Node, to the Store beside it, as the --store
## flag asks.
static func walk_to_a_store(run: Run) -> void:
	for id: int in run.stage_visit.choices():
		if run.stage_visit.map.nodes[id].kind == StageMap.Kind.STORE:
			run.move_to(id)
			return


## Shows the Store [param run]'s Hero stands on, as it was left.
func begin(run: Run) -> void:
	_run = run
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground = StageIntro.ground_panel(run.stage_visit.stage)
	add_child(_ground)
	# A click on nothing lets the selected good go.
	var catcher: Control = Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	StoreLook.take_clicks(catcher, func() -> void: _select(null))
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.mouse_default_cursor_shape = Control.CURSOR_ARROW
	add_child(catcher)
	_card_rows = []
	var cards: Array[StoreGood] = StoreLayout.cards_in_order(run.store_stock())
	var start: int = 0
	for size: int in StoreLayout.row_sizes(cards.size()):
		_card_rows.append(cards.slice(start, start + size))
		start += size
	_items = StoreLayout.items_in_order(run.store_stock())
	_add_bar()
	_add_inspector()
	_add_cards()
	if not _items.is_empty():
		_add_items()
	_satchel = SatchelWindow.over(self, run)
	_satchel.use_pace(is_paced, game_speed)
	run_pause = RunPause.over(self, func(scene: String) -> void: navigate.call(scene),
		GameSettings.PATH if starts_itself else "")


func _process(_delta: float) -> void:
	if _run == null or not follows_cursor:
		return
	var good: StoreGood = null
	if not _satchel.is_open() and _window == null and not run_pause.is_open():
		good = _good_at(get_viewport().gui_get_hovered_control())
	if good != _hovered:
		_hovered = good
		_show_inspected()


func title_text() -> String:
	return _title.text


## The gold panel's number, as it shows now.
func gold_text() -> String:
	return _count.text


## Sell Cards, Satchel, Deckbox and Leave, in their order.
func top_buttons() -> Array[Button]:
	return _buttons.duplicate()


func button_named(words: String) -> Button:
	for each: Button in _buttons:
		if each.text == words:
			return each
	return null


## The Stage Intro's ground under everything.
func ground() -> Control:
	return _ground


## The cards in their rows, top to bottom, each row left to right.
func card_rows() -> Array:
	return _card_rows.duplicate()


## The Items in their column, top to bottom.
func item_goods() -> Array[StoreGood]:
	return _items.duplicate()


## What takes [param good]'s clicks.
func target_of(good: StoreGood) -> Control:
	return _spots[good].target


## Where [param good] stands in the layout.
func place_of(good: StoreGood) -> Rect2:
	return _spots[good].root.get_global_rect()


func price_text_of(good: StoreGood) -> String:
	return StoreLook.amount_of(_spots[good].price_row).text


func has_coin(good: StoreGood) -> bool:
	var coin: Control = _spots[good].price_row.get_child(0) as Control
	return coin is TextureRect and (coin as TextureRect).texture == load(StoreLook.COIN)


func is_price_red(good: StoreGood) -> bool:
	return StoreLook.is_red(_spots[good].price_row)


## A card's face, or null for an Item or a good Sold.
func face_of(good: StoreGood) -> CardFace:
	return _spots[good].face


func selected() -> StoreGood:
	return _selected


## What the Inspector shows: the selected good, or with none the one under the cursor.
func inspected() -> StoreGood:
	return _shown


func is_risen(good: StoreGood) -> bool:
	return StoreLook.is_lifted(_spots[good].lifter)


func buy_button_of(good: StoreGood) -> Button:
	return _spots[good].buy_button()


## Every Buy button showing now.
func showing_buys() -> Array[Button]:
	var showing: Array[Button] = []
	for good: StoreGood in _spots:
		var buy: Button = _spots[good].buy_button()
		if Easing.is_shown(buy) and buy.visible:
			showing.append(buy)
	return showing


## The Sold space [param good] left, or null while it is for sale.
func sold_space_of(good: StoreGood) -> Control:
	return _spots[good].sold


## The Collection Window while it is open, or null.
func collection_window() -> CollectionWindow:
	return _window


func satchel() -> SatchelWindow:
	return _satchel


func inspector() -> DeckbuilderInspector:
	return _inspector


func _ease_seconds() -> float:
	return GameSpeed.seconds(Pacing.EASE_SECONDS, game_speed) if is_paced else 0.0


func _count_seconds() -> float:
	return GameSpeed.seconds(StoreLook.COUNT_SECONDS, game_speed) if is_paced else 0.0


## The top bar: the title at its left, then the gold panel and the four buttons at its right.
func _add_bar() -> void:
	var bar: Panel = StoreLook.pane(StoreLayout.BAR)
	# A click on the bar is not a click on the ground.
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	var holder: MarginContainer = StoreLook.inside(bar, 0)
	holder.add_theme_constant_override("margin_left", 24)
	holder.add_theme_constant_override("margin_right", 14)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	_title = StoreLook.text(TITLE, 36, StoreLook.TEXT, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_title)
	var gold: Control = StoreLook.gold_panel(_run.gold)
	_count = StoreLook.count_of(gold)
	row.add_child(gold)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	_buttons = [
		StoreLook.button(SELL_CARDS), StoreLook.button(SATCHEL, "satchel"), StoreLook.button(DECKBOX, "deckbox"),
		StoreLook.button(LEAVE),
	]
	_buttons[0].pressed.connect(_open_window)
	_buttons[1].pressed.connect(func() -> void: _satchel.open())
	_buttons[2].pressed.connect(func() -> void: navigate.call(Screens.scene(RunFlow.open_deckbox(RunFlow.Screen.STORE))))
	_buttons[3].pressed.connect(_leave)
	for each: Button in _buttons:
		row.add_child(each)


func _add_inspector() -> void:
	var place: Rect2 = StoreLayout.inspector_rect()
	_inspector = StoreLook.add_inspector(self, place)
	_item_holder = Control.new()
	_item_holder.position = Vector2(StoreLayout.INSPECTOR_PAD, StoreLayout.INSPECTOR_PAD)
	_item_holder.size = place.size - 2.0 * Vector2(StoreLayout.INSPECTOR_PAD, StoreLayout.INSPECTOR_PAD)
	_item_holder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_item_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspector.get_parent().add_child(_item_holder)


## The cards for sale in their rows, each with its price under it and room for its Buy under
## that.
func _add_cards() -> void:
	var pane: Panel = StoreLook.pane(StoreLayout.cards_rect(not _items.is_empty()))
	add_child(pane)
	var centered: CenterContainer = CenterContainer.new()
	centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
	StoreLook.inside(pane, StoreLayout.CARDS_PAD).add_child(centered)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", StoreLayout.ROW_GAP)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centered.add_child(rows)
	for cards: Array in _card_rows:
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", StoreLayout.CARD_GAP)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(row)
		for good: StoreGood in cards:
			var spot: StoreSpot = StoreSpot.of_card(good, StoreLayout.CARD_HEIGHT, _can_afford(good))
			_keep(spot)
			row.add_child(spot.root)


## The Items for sale as Satchel entries, Potions and then Armor, scrolling if they must.
func _add_items() -> void:
	var pane: Panel = StoreLook.pane(StoreLayout.items_rect())
	add_child(pane)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	StoreLook.inside(pane, StoreLayout.ITEMS_PAD).add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(StoreLayout.ENTRY_GAP - StoreLook.ENTRY_LIFT))
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)
	for good: StoreGood in _items:
		var spot: StoreSpot = StoreSpot.of_item(good, _can_afford(good))
		_keep(spot)
		list.add_child(spot.root)


func _keep(spot: StoreSpot) -> void:
	_spots[spot.good] = spot
	var good: StoreGood = spot.good
	spot.buy_button().pressed.connect(func() -> void: _buy(good))
	if good.is_sold:
		# Bought before the Store was left: its Sold space is there when it opens again, as
		# large as the good, once the good has been laid out.
		_show_bought.call_deferred(spot)
		return
	StoreLook.take_clicks(spot.target, func() -> void: _on_click(good))


func _show_bought(spot: StoreSpot) -> void:
	await get_tree().process_frame
	spot.sell_out(0.0)


func _can_afford(good: StoreGood) -> bool:
	return good.price() <= _run.gold


## The good not Sold whose target is [param control] or holds it, or null.
func _good_at(control: Control) -> StoreGood:
	var node: Node = control
	while node != null and node != self:
		for good: StoreGood in _spots:
			if _spots[good].target == node and not good.is_sold:
				return good
		node = node.get_parent()
	return null


## A click on [param good] selects it, or lets it go if it is the one selected.
func _on_click(good: StoreGood) -> void:
	if good.is_sold:
		return
	_select(null if good == _selected else good)


## Selects [param good] in place of whatever was selected, or nothing for null.
func _select(good: StoreGood) -> void:
	if good == _selected:
		return
	if _selected != null:
		_spots[_selected].set_selected(false, false, _ease_seconds())
	_selected = good
	if good != null:
		_spots[good].set_selected(true, _can_afford(good), _ease_seconds())
	_show_inspected()


## Buys [param good], if it can be afforded: the gold counts down, a Sold space takes its
## place, and what can no longer be afforded turns red.
func _buy(good: StoreGood) -> void:
	if _run.buy(good) != "":
		return
	_selected = null
	if _hovered == good:
		_hovered = null
	_spots[good].sell_out(_ease_seconds())
	_show_gold()
	_show_inspected()


## The gold has changed: the panel counts to it, and each price is red or not as it covers it.
func _show_gold() -> void:
	StoreLook.count_gold(_count, _run.gold, _count_seconds())
	for good: StoreGood in _spots:
		if not good.is_sold:
			_spots[good].show_price(_can_afford(good))


## Shows the selected good in the Inspector, or with none selected the one under the cursor,
## or nothing.
func _show_inspected() -> void:
	var good: StoreGood = _selected if _selected != null else _hovered
	if good == _shown:
		return
	_shown = good
	var is_card: bool = good != null and good.kind == StoreGood.Kind.CARD
	var width: float = StoreLayout.INSPECTOR_WIDTH - 2.0 * StoreLayout.INSPECTOR_PAD
	_inspector.show_card(good.card if is_card else null, width / CardGeometry.ASPECT, _ease_seconds())
	InspectorParts.clear(_item_holder)
	if good != null and not is_card:
		_item_holder.add_child(ItemReadout.of(good, width))


## Sell Cards opens the Collection Window over the Store, under the Pause Menu.
func _open_window() -> void:
	if _window != null:
		return
	_select(null)
	_window = CollectionWindow.over(self, _run, _ease_seconds(), _count_seconds())
	move_child(_window, run_pause.get_index())
	_window.sold.connect(_show_gold)
	_window.closed.connect(func() -> void: _window = null)


func _leave() -> void:
	has_left = true
	navigate.call(Screens.scene(RunFlow.leave_store()))
