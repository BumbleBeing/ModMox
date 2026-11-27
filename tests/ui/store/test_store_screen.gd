extends GutTest
## ST1 to ST11 (milestone 24, signed off as prototypes/store_screen/): the Store's screen,
## driven by real mouse events through the input pipeline. A pane across the top holds
## "Store", the gold panel and Sell Cards, Satchel, Deckbox and Leave; under it the Inspector,
## the cards at most five to a row, cheapest first, and the Items in a column, Potions then
## Armor. A click selects a good, which rises and shows its Buy; Buy buys it, leaving a Sold
## space, and the gold counts down.

## A point of the cards' pane that no card stands on.
const GROUND: Vector2 = Vector2(380, 112)

var _run: Run
var _viewport: SubViewport
var _screen: StoreScreen
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to = []
	StoreScreen.has_left = false
	RunFlow.clear()
	_run = _at_a_store(4)


func after_each() -> void:
	if _viewport != null and is_instance_valid(_viewport):
		await _move_mouse(Vector2(1910, 1070))
	StoreScreen.has_left = false
	RunFlow.clear()
	await wait_process_frames(2)


## ST1: the top bar reads "Store", the gold held, and Sell Cards, Satchel, Deckbox and Leave,
## on the Stage Intro's ground.
func test_the_top_bar_reads_store_the_gold_and_its_four_buttons() -> void:
	_run.gold = 137
	await _open_store()

	assert_eq(_screen.title_text(), "Store")
	assert_eq(_screen.gold_text(), "137")
	var words: Array[String] = []
	for each: Button in _screen.top_buttons():
		words.append(each.text)
	assert_eq(words, ["Sell Cards", "Satchel", "Deckbox", "Leave"] as Array[String])
	assert_not_null(_screen.ground())
	assert_true(_screen.ground().is_visible_in_tree())
	assert_eq(_screen.ground().get_global_rect(), Rect2(Vector2.ZERO, Vector2(1920, 1080)), "the whole screen")


## ST2: the cards stand cheapest first and then by name, at most five to a row with the rows
## evened out.
func test_the_cards_stand_cheapest_first_five_to_a_row_at_most() -> void:
	await _open_store()

	var shown: Array[StoreGood] = []
	for row: Array in _screen.card_rows():
		assert_lte(row.size(), StoreLayout.MOST_IN_A_ROW)
		for good: StoreGood in row:
			shown.append(good)
	var cards: Array[StoreGood] = _goods_of(StoreGood.Kind.CARD)
	assert_eq(shown.size(), cards.size())
	cards.sort_custom(_cheapest_first)
	assert_eq(_names(shown), _names(cards))
	var sizes: Array[int] = []
	for row: Array in _screen.card_rows():
		sizes.append(row.size())
	assert_eq(sizes, StoreLayout.row_sizes(cards.size()))


## ST2: rows are evened out: six cards stand three and three, seven four and three, nine five
## and four.
func test_rows_are_evened_out() -> void:
	assert_eq(StoreLayout.row_sizes(0), [] as Array[int])
	assert_eq(StoreLayout.row_sizes(4), [4] as Array[int])
	assert_eq(StoreLayout.row_sizes(5), [5] as Array[int])
	assert_eq(StoreLayout.row_sizes(6), [3, 3] as Array[int])
	assert_eq(StoreLayout.row_sizes(7), [4, 3] as Array[int])
	assert_eq(StoreLayout.row_sizes(8), [4, 4] as Array[int])
	assert_eq(StoreLayout.row_sizes(9), [5, 4] as Array[int])


## ST2: Potions and then Armor stand in the Items column, each cheapest first.
func test_potions_then_armor_stand_in_the_items_column() -> void:
	_run = _at_a_store_with_items()
	await _open_store()

	var potions: Array[StoreGood] = _goods_of(StoreGood.Kind.POTION)
	var armor: Array[StoreGood] = _goods_of(StoreGood.Kind.ARMOR)
	potions.sort_custom(_cheapest_first)
	armor.sort_custom(_cheapest_first)
	assert_eq(_names(_screen.item_goods()), _names(potions + armor))


## ST3: every good shows its price with the coin, red when the gold does not cover it.
func test_every_good_shows_its_price_red_when_it_cannot_be_afforded() -> void:
	_run = _at_a_store_with_items()
	_run.gold = 40
	await _open_store()

	for good: StoreGood in _run.store_stock().goods():
		assert_eq(_screen.price_text_of(good), str(good.price()), good.name())
		assert_true(_screen.has_coin(good), good.name())
		assert_eq(_screen.is_price_red(good), good.price() > 40, good.name())


## ST4: a card carrying Mods or Hexes shows its Modded Name and its Mod Slots, at its Store
## price as it is.
func test_a_modded_card_shows_its_modded_name_and_slots_at_its_price() -> void:
	_run = _at_a_store_with_a_modded_card()
	await _open_store()

	var modded: StoreGood = _goods_of(StoreGood.Kind.CARD).filter(func(good: StoreGood) -> bool:
		return good.card.is_modified())[0]
	var face: CardFace = _screen.face_of(modded)
	assert_eq(face.title_text().shown_text(), modded.name())
	assert_ne(modded.name(), modded.card.run_card.base.name)
	assert_not_null(DeckbuilderFace.mod_slots_on(face))
	assert_eq(_screen.price_text_of(modded), str(Prices.of_card(modded.card)))


## ST5: with nothing selected, the Inspector shows the good under the cursor, and nothing once
## the cursor leaves it.
func test_with_nothing_selected_the_inspector_shows_the_good_under_the_cursor() -> void:
	await _open_store()
	var good: StoreGood = _screen.card_rows()[0][0]

	await _move_mouse(_center(_screen.target_of(good)))
	assert_eq(_screen.inspected(), good)
	await _move_mouse(GROUND)

	assert_null(_screen.inspected())


## ST6: a click on a good selects it: it rises, the Inspector holds it, and Buy shows under it.
func test_a_click_on_a_good_selects_it() -> void:
	_run.gold = 5000
	await _open_store()
	var good: StoreGood = _screen.card_rows()[0][0]

	await _click(_center(_screen.target_of(good)))

	assert_eq(_screen.selected(), good)
	assert_true(_screen.is_risen(good))
	await _move_mouse(GROUND)
	assert_eq(_screen.inspected(), good, "the Inspector holds it whatever the cursor is over")
	assert_true(_screen.buy_button_of(good).visible)
	assert_false(_screen.buy_button_of(good).disabled)


## ST6: Buy is off while the good cannot be afforded.
func test_buy_is_off_while_the_good_cannot_be_afforded() -> void:
	_run.gold = 0
	await _open_store()
	var good: StoreGood = _screen.card_rows()[0][0]

	await _click(_center(_screen.target_of(good)))

	assert_true(_screen.buy_button_of(good).visible)
	assert_true(_screen.buy_button_of(good).disabled)


## ST7: a click on the selected good or on nothing lets it go, a click on another selects that
## one, and only one Buy shows.
func test_a_click_again_or_on_nothing_lets_it_go_and_one_buy_shows() -> void:
	await _open_store()
	var first: StoreGood = _screen.card_rows()[0][0]
	var second: StoreGood = _screen.card_rows()[0][1]

	await _click(_center(_screen.target_of(first)))
	await _click(_center(_screen.target_of(first)))
	assert_null(_screen.selected())
	assert_false(_screen.is_risen(first))
	await _click(_center(_screen.target_of(first)))
	await _click(GROUND)
	assert_null(_screen.selected())
	await _click(_center(_screen.target_of(first)))
	await _click(_center(_screen.target_of(second)))

	assert_eq(_screen.selected(), second)
	assert_false(_screen.is_risen(first))
	assert_eq(_screen.showing_buys(), [_screen.buy_button_of(second)] as Array[Button])


## ST8: Buy buys it: the gold drops by its price, the card is in the Collection, a Sold space
## stands in its place and takes no clicks, and nothing else moves.
func test_buy_buys_it_and_leaves_a_sold_space() -> void:
	_run.gold = 5000
	await _open_store()
	var good: StoreGood = _screen.card_rows()[0][0]
	var owned: int = _run.collection.cards().size()
	var places: Dictionary = _places()

	await _click(_center(_screen.target_of(good)))
	await _click(_center(_screen.buy_button_of(good)))
	await wait_process_frames(2)

	assert_eq(_run.gold, 5000 - good.price())
	assert_true(good.is_sold)
	assert_eq(_run.collection.cards().size(), owned + 1)
	assert_not_null(_screen.sold_space_of(good))
	var after: Dictionary = _places()
	for name: String in after:
		assert_eq(after[name], places[name], "%s does not move" % name)
	await _click(_center(_screen.sold_space_of(good)))
	assert_null(_screen.selected(), "a Sold space takes no clicks")


## ST8: a bought Item goes in the Satchel.
func test_a_bought_item_goes_in_the_satchel() -> void:
	_run = _at_a_store_with_items()
	_run.gold = 5000
	await _open_store()
	var good: StoreGood = _screen.item_goods()[0]
	var held: int = _items_held()

	await _click(_center(_screen.target_of(good)))
	await _click(_center(_screen.buy_button_of(good)))

	assert_eq(_items_held(), held + 1)
	assert_not_null(_screen.sold_space_of(good))


## ST9: after a purchase the gold panel counts to the new gold, and each price the gold no
## longer covers is red.
func test_after_a_purchase_the_gold_counts_down_and_prices_turn_red() -> void:
	await _open_store()
	var cards: Array[StoreGood] = _goods_of(StoreGood.Kind.CARD)
	cards.sort_custom(_cheapest_first)
	var bought: StoreGood = cards[-1]
	_run.gold = bought.price()
	await _open_store()

	await _click(_center(_screen.target_of(bought)))
	await _click(_center(_screen.buy_button_of(bought)))

	assert_eq(_screen.gold_text(), "0")
	for good: StoreGood in _run.store_stock().goods():
		if not good.is_sold:
			assert_true(_screen.is_price_red(good), good.name())


## ST10: Deckbox opens the Deckbox over the Store, and closing it returns there.
func test_deckbox_opens_the_deckbox_and_closing_it_returns_to_the_store() -> void:
	await _open_store()

	await _click(_center(_screen.button_named("Deckbox")))

	assert_eq(_went_to, [Screens.DECKBOX] as Array[String])
	assert_eq(RunFlow.close_deckbox(), RunFlow.Screen.STORE)


## ST10: Leave returns to the Stage Map, where a click on the Node reopens the Store as it was
## left.
func test_leave_returns_to_the_map_where_a_click_on_the_node_reopens_it() -> void:
	_run.gold = 5000
	await _open_store()
	var good: StoreGood = _screen.card_rows()[0][0]
	await _click(_center(_screen.target_of(good)))
	await _click(_center(_screen.buy_button_of(good)))

	await _click(_center(_screen.button_named("Leave")))
	assert_eq(_went_to, [Screens.STAGE_MAP] as Array[String])
	_went_to.clear()
	var map: StageMapScreen = await _open_map()
	await _click(map.node_spot(_run.stage_visit.current))

	assert_eq(_went_to, [Screens.STORE] as Array[String])
	await _open_store()
	assert_not_null(_screen.sold_space_of(good), "the Store as it was left")


## The Satchel opens over the Store.
func test_satchel_opens_the_satchel_over_the_store() -> void:
	await _open_store()

	await _click(_center(_screen.button_named("Satchel")))

	assert_true(_screen.satchel().is_open())


## ST11: --store opens the Store of a debug run.
func test_the_store_flag_opens_the_store_of_a_debug_run() -> void:
	RunFlow.clear()
	var menu: MainMenu = MainMenu.new()
	menu.navigate = func(scene: String) -> void: _went_to.append(scene)
	menu.quit = func() -> void: pass
	menu.arguments = PackedStringArray([StoreScreen.FLAG, "--run-seed=7"])
	add_child_autofree(menu)
	await wait_process_frames(2)

	assert_eq(_went_to, [Screens.STORE] as Array[String])
	assert_eq(RunFlow.run.run_seed, 7)
	assert_not_null(RunFlow.run.store_stock())


## A debug run standing on its first Store, with Run Seed [param run_seed], arrived at
## through RunFlow.
func _at_a_store(run_seed: int) -> Run:
	RunFlow.clear()
	var run: Run = Run.debug(run_seed)
	RunFlow.start(run)
	RunFlow.finish_intro()
	for id: int in run.stage_visit.choices():
		if run.stage_visit.map.nodes[id].kind == StageMap.Kind.STORE:
			run.move_to(id)
	RunFlow.arrive()
	return run


func _at_a_store_with_items() -> Run:
	for run_seed: int in 200:
		var run: Run = _at_a_store(run_seed)
		var kinds: Array = run.store_stock().goods().map(func(good: StoreGood) -> StoreGood.Kind: return good.kind)
		if kinds.has(StoreGood.Kind.POTION) and kinds.has(StoreGood.Kind.ARMOR):
			return run
	assert_true(false, "no Store of the first 200 Run Seeds has a Potion and an Armor")
	return null


func _at_a_store_with_a_modded_card() -> Run:
	for run_seed: int in 200:
		var run: Run = _at_a_store(run_seed)
		if run.store_stock().goods().any(func(good: StoreGood) -> bool: return good.card != null and good.card.is_modified()):
			return run
	assert_true(false, "no Store of the first 200 Run Seeds has a Modded card")
	return null


## The Store of the run in a viewport of its own, so that real events reach it.
func _open_store() -> void:
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.queue_free()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.gui_disable_input = false
	add_child_autofree(_viewport)
	_screen = StoreScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	_viewport.add_child(_screen)
	_screen.size = Vector2(1920, 1080)
	_screen.begin(_run)
	await wait_process_frames(3)


func _open_map() -> StageMapScreen:
	_viewport.queue_free()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(StageMapLayout.SCREEN)
	_viewport.gui_disable_input = false
	add_child_autofree(_viewport)
	var map: StageMapScreen = StageMapScreen.new()
	map.starts_itself = false
	map.navigate = func(scene: String) -> void: _went_to.append(scene)
	_viewport.add_child(map)
	map.size = StageMapLayout.SCREEN
	map.set_process(false)
	map.begin(_run)
	await wait_process_frames(3)
	return map


## How many Potions and Armor the Hero holds, each counted as often as held.
func _items_held() -> int:
	var count: int = _run.held_potions.all().size()
	for armor: Armor in _run.held_armor.kinds():
		count += _run.held_armor.count_of(armor)
	return count


func _goods_of(kind: StoreGood.Kind) -> Array[StoreGood]:
	return _run.store_stock().goods().filter(func(good: StoreGood) -> bool: return good.kind == kind)


func _cheapest_first(a: StoreGood, b: StoreGood) -> bool:
	return a.price() < b.price() if a.price() != b.price() else a.name().naturalnocasecmp_to(b.name()) < 0


func _names(goods: Array) -> Array[String]:
	var names: Array[String] = []
	for good: StoreGood in goods:
		names.append(good.name())
	return names


## Where each good not Sold stands now, by its name.
func _places() -> Dictionary:
	var places: Dictionary = {}
	for good: StoreGood in _run.store_stock().goods():
		if not good.is_sold:
			places[good.name()] = _screen.place_of(good)
	return places


func _move_mouse(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_viewport.push_input(motion)
	await wait_process_frames(2)


## A real press and release at [param at], then a frame for what it changed to be laid out.
func _click(at: Vector2) -> void:
	await _move_mouse(at)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		_viewport.push_input(click)
	await wait_process_frames(2)


func _center(control: Control) -> Vector2:
	assert_not_null(control)
	return control.get_global_rect().get_center()
