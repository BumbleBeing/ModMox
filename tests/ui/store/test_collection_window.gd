extends GutTest
## CW1 to CW6 (milestone 24, signed off as prototypes/store_screen/): the Collection Window
## for selling, opened by the Store's Sell Cards and driven by real mouse events. It lays the
## Collection out eight to a row under the deckbuilder's filter bar, with the Inspector down
## its left; a card in Decks carries a tag; a click selects a card, and Sell sells it for a
## third of its Store price, taking it out of the Collection and every Deck.

const CARDS: String = "res://content/cards/alpha/%s.tres"
const ANCESTRAL_RECALL: String = "res://content/cards/alpha/ancestral_recall.tres"
## The sample Collection, in the order taken in.
const FILES: Array[String] = [
	"grizzly_bears", "llanowar_elves", "serra_angel", "shivan_dragon", "counterspell", "lightning_bolt",
	"giant_growth", "savannah_lions", "white_knight", "terror", "fog", "shatter",
]

var _run: Run
var _viewport: SubViewport
var _screen: StoreScreen
var _went_to: Array[String] = []
var _cards: Dictionary[String, DeckbuilderCard] = {}


func before_each() -> void:
	_went_to = []
	RunFlow.clear()
	_run = Run.debug(4)
	RunFlow.start(_run)
	RunFlow.finish_intro()
	for id: int in _run.stage_visit.choices():
		if _run.stage_visit.map.nodes[id].kind == StageMap.Kind.STORE:
			_run.move_to(id)
	RunFlow.arrive()
	_hold_sample()


func after_each() -> void:
	if _viewport != null and is_instance_valid(_viewport):
		await _move_mouse(Vector2(1910, 1070))
	RunFlow.clear()
	await wait_process_frames(2)


## CW1: Sell Cards opens it over the dimmed Store, titled "Sell Cards"; the Store takes no
## clicks while it is open; Close closes it.
func test_sell_cards_opens_it_over_the_store_and_close_closes_it() -> void:
	await _open_window()

	assert_eq(_window().title_text(), "Sell Cards")
	var good: StoreGood = _screen.card_rows()[0][0]
	await _click(_center(_screen.target_of(good)))
	assert_null(_screen.selected(), "the Store under it takes no clicks")
	await _click(_center(_window().close_button()))
	await wait_process_frames(2)

	assert_null(_screen.collection_window())


## CW2: it shows the whole Collection eight to a row, and the filter bar narrows it.
func test_it_shows_the_whole_collection_eight_to_a_row() -> void:
	await _open_window()

	assert_eq(_window().shown_cards().size(), FILES.size())
	assert_eq(_window().columns(), 8)
	var first: Rect2 = _window().cell_of(_window().shown_cards()[0]).get_global_rect()
	var eighth: Rect2 = _window().cell_of(_window().shown_cards()[7]).get_global_rect()
	var ninth: Rect2 = _window().cell_of(_window().shown_cards()[8]).get_global_rect()
	assert_almost_eq(eighth.position.y, first.position.y, 0.5, "the eighth on the first row")
	assert_gt(ninth.position.y, first.position.y, "the ninth on the second")
	assert_almost_eq(ninth.position.x, first.position.x, 0.5)
	var search: LineEdit = _window().filter_bar().search_box()
	search.text = "Shivan"
	search.text_changed.emit(search.text)
	await wait_process_frames(2)
	assert_eq(_names(_window().shown_cards()), ["Shivan Dragon"] as Array[String])


## CW3: a card in Decks carries "In 1 Deck" or "In 2 Decks"; a card in none carries no tag.
func test_a_card_in_decks_carries_a_tag() -> void:
	await _open_window()

	assert_eq(_window().tag_of(_cards["grizzly_bears"]), "In 2 Decks")
	assert_eq(_window().tag_of(_cards["serra_angel"]), "In 1 Deck")
	assert_eq(_window().tag_of(_cards["shatter"]), "")


## CW4: a click selects a card, ringed and held in the Inspector; a click on it again lets it
## go; a gray card takes no clicks.
func test_a_click_selects_a_card_and_a_gray_one_takes_none() -> void:
	var power_nine: DeckbuilderCard = _run.collection.add(_run_card(ANCESTRAL_RECALL))
	await _open_window()
	var card: DeckbuilderCard = _cards["serra_angel"]

	await _click(_center(_window().cell_of(card)))
	assert_eq(_window().selected(), card)
	assert_true(_window().is_ringed(card))
	assert_eq(_window().inspected(), card)
	await _click(_center(_window().cell_of(card)))
	assert_null(_window().selected())
	assert_false(_window().is_ringed(card))

	assert_true(_window().is_gray(power_nine))
	await _click(_center(_window().cell_of(power_nine)))
	assert_null(_window().selected())


## CW5: the button reads "Sell" with a third of the card's Store price, rounded down, and
## "Currently in …" names its Decks.
func test_the_button_reads_sell_with_a_third_of_the_price() -> void:
	await _open_window()
	var card: DeckbuilderCard = _cards["grizzly_bears"]

	await _click(_center(_window().cell_of(card)))

	assert_eq(_window().confirm_words(), "Sell")
	assert_eq(_window().confirm_price(), str(Prices.of_card(card) / 3))
	assert_eq(_window().decks_line(), "Currently in Aggro and Control")


## CW5: "Currently in …" in each of its three forms.
func test_currently_in_names_one_two_or_three_decks() -> void:
	assert_eq(CollectionWindow.currently_in([] as Array[String]), "")
	assert_eq(CollectionWindow.currently_in(["Aggro"] as Array[String]), "Currently in Aggro")
	assert_eq(CollectionWindow.currently_in(["Aggro", "Control"] as Array[String]), "Currently in Aggro and Control")
	assert_eq(CollectionWindow.currently_in(["Aggro", "Control", "Midrange"] as Array[String]),
			"Currently in Aggro, Control, and Midrange")


## CW6: Sell takes the card out of the Collection and every Deck, the rest close up, and the
## gold counts up in the window and on the Store, where a price the gold now covers is red no
## longer.
func test_sell_takes_the_card_out_and_counts_the_gold_up() -> void:
	var cards: Array[StoreGood] = _run.store_stock().goods().filter(func(good: StoreGood) -> bool:
		return good.kind == StoreGood.Kind.CARD)
	cards.sort_custom(func(a: StoreGood, b: StoreGood) -> bool: return a.price() < b.price())
	var card: DeckbuilderCard = _cards["shivan_dragon"]
	var paid: int = Prices.of_card(card) / 3
	_run.gold = cards[0].price() - paid
	await _open_window()
	assert_true(_screen.is_price_red(cards[0]))
	var shown: Array[DeckbuilderCard] = _window().shown_cards()
	var next: DeckbuilderCard = shown[shown.find(card) + 1]
	var place: Vector2 = _window().cell_of(card).get_global_rect().position

	await _click(_center(_window().cell_of(card)))
	await _click(_center(_window().confirm_button()))
	await wait_process_frames(2)

	assert_false(_run.collection.owns(card))
	for deck: Deck in _run.deckbox.decks():
		assert_false(deck.card_ids.has(card.id), deck.name)
	assert_false(_window().shown_cards().has(card))
	assert_eq(_window().cell_of(next).get_global_rect().position, place, "the rest close up")
	assert_eq(_run.gold, cards[0].price())
	assert_eq(_window().gold_text(), str(_run.gold))
	assert_eq(_screen.gold_text(), str(_run.gold))
	assert_false(_screen.is_price_red(cards[0]))


## The run's Collection made small and known: twelve cards in three Decks. Grizzly Bears is in
## Aggro and Control, Serra Angel in Control alone, and Shatter in none.
func _hold_sample() -> void:
	_run.collection = Collection.new()
	_run.deckbox = Deckbox.new()
	_cards.clear()
	for file: String in FILES:
		_cards[file] = _run.collection.add(_run_card(CARDS % file))
	var decks: Dictionary[String, Array] = {
		"Aggro": ["grizzly_bears", "llanowar_elves", "shivan_dragon", "lightning_bolt"],
		"Control": ["grizzly_bears", "serra_angel", "counterspell"],
		"Midrange": ["giant_growth", "savannah_lions"],
	}
	for deck_name: String in decks:
		var deck: Deck = Deck.new()
		deck.name = deck_name
		for file: String in decks[deck_name]:
			deck.card_ids.append(_cards[file].id)
		_run.deckbox.put(deck)
	_run.deckbox.set_active(_run.deckbox.decks()[0])


func _run_card(path: String) -> MmRunCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = load(path) as MmCardDefinition
	return run_card


## The Store in a viewport of its own, with its Collection Window opened by Sell Cards.
func _open_window() -> void:
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
	await _click(_center(_screen.button_named("Sell Cards")))
	assert_not_null(_screen.collection_window(), "Sell Cards opened the Collection Window")
	# Every face is made a few each frame.
	await wait_process_frames(6)


func _window() -> CollectionWindow:
	return _screen.collection_window()


func _names(cards: Array[DeckbuilderCard]) -> Array[String]:
	var names: Array[String] = []
	for card: DeckbuilderCard in cards:
		names.append(card.card_name())
	return names


func _move_mouse(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_viewport.push_input(motion)
	await wait_process_frames(2)


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
