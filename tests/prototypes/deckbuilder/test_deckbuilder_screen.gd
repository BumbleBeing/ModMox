extends GutTest
## The deckbuilder drawn from the made-up run: every card of the Deck in a column, every
## owned card in the Collection pane, and the Deck's name and size in the top bar.

var _sample: DeckbuilderSample
var _screen: DeckbuilderScreen


func before_each() -> void:
	_sample = DeckbuilderSample.make()
	_screen = DeckbuilderScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = Vector2(1920, 1080)
	_screen.begin(_sample)


func after_each() -> void:
	await wait_process_frames(2)


func test_the_sample_run_owns_three_of_every_card_and_no_basic_lands() -> void:
	var cards: Array[DeckbuilderCard] = _sample.collection.cards()

	assert_eq(cards.size() % DeckbuilderSample.COPIES, 0)
	assert_eq(_sample.basic_lands.size(), 5)
	for card: DeckbuilderCard in cards:
		assert_false(card.is_basic_land())


func test_the_sample_deck_is_legal_and_saved() -> void:
	var deck: WorkingDeck = _sample.working_deck()

	assert_eq(deck.name, DeckbuilderSample.DECK_NAME)
	assert_eq(deck.size(), WorkingDeck.MINIMUM_SIZE)
	assert_true(deck.is_legal())
	assert_false(deck.has_unsaved_changes())


func test_the_sample_run_has_a_hexed_card_a_full_card_and_mods_to_apply() -> void:
	var hexed: int = 0
	var full: int = 0
	for card: DeckbuilderCard in _sample.collection.cards():
		full += 1 if not card.has_empty_mod_slot() else 0
		hexed += 1 if card.mods.any(func(mod: Mod) -> bool: return mod.is_hex) else 0

	assert_gt(hexed, 0)
	assert_gt(full, 0)
	assert_gt(_sample.held_mods.kinds().size(), 1)
	for mod: Mod in _sample.held_mods.kinds():
		assert_false(mod.is_hex, "The Hero never holds a Hex.")


func test_every_card_in_the_deck_has_its_own_face_in_its_column() -> void:
	var deck: WorkingDeck = _sample.working_deck()
	var places: DeckbuilderLayout = _screen.layout()

	for column: int in WorkingDeck.COLUMN_COUNT:
		var cards: Array[DeckbuilderCard] = deck.cards_in(column)
		for index: int in cards.size():
			# A basic land is made fresh by each Working Deck, in the same order, so the
			# screen's own copy has the same identity.
			var shown: DeckbuilderCard = cards[index]
			var face: CardFace = _screen.column_face(shown)
			assert_not_null(face)
			if face == null:
				continue
			assert_almost_eq(face.position.y, places.fan_offset(index), 0.01)
			assert_true(places.column(column).has_point(face.global_position + Vector2(2, 2)),
					"%s is drawn in column %d." % [shown.look().name, column])


func test_every_owned_card_is_in_the_collection_pane_and_those_in_the_deck_are_dimmed() -> void:
	var deck: WorkingDeck = _sample.working_deck()

	for card: DeckbuilderCard in _sample.collection.cards():
		var face: CardFace = _screen.collection_face(card)
		assert_not_null(face)
		if face != null:
			assert_eq(face.modulate.a < 1.0, deck.contains(card), card.look().name)


func test_the_top_bar_shows_the_decks_name_and_size() -> void:
	assert_eq(_screen.name_box().text, DeckbuilderSample.DECK_NAME)
	assert_eq(_screen.count_label().text, "40 / 40 cards")



func test_a_filter_hides_the_cards_it_rules_out_and_packs_the_rest_from_the_first_cell() -> void:
	_screen.filter_bar().press("color:u")
	_screen.filter_bar().press("type:Instant")

	var shown: Array[DeckbuilderCard] = _screen.collection_filter().apply(_sample.collection.cards())
	assert_gt(shown.size(), 0)
	assert_lt(shown.size(), _sample.collection.cards().size())
	for card: DeckbuilderCard in _sample.collection.cards():
		assert_eq(_screen.collection_face(card) != null, shown.has(card), card.look().name)
	assert_eq(_screen.collection_face(shown[0]).position, Vector2.ZERO)
	assert_eq(_screen.filter_bar().count_label().text, "%d of 111" % shown.size())


func test_searching_keeps_the_same_bar_and_faces() -> void:
	var bar: FilterBar = _screen.filter_bar()
	var bolt: DeckbuilderCard = _owned("Lightning Bolt")
	var face: CardFace = _screen.collection_face(bolt)

	bar.search_box().text = "lightning"
	bar.search_box().text_changed.emit("lightning")

	assert_eq(_screen.filter_bar(), bar, "The bar is not rebuilt, so the search box keeps its cursor.")
	assert_eq(_screen.collection_face(bolt), face, "Nor is the card's face.")
	assert_null(_screen.collection_face(_owned("Serra Angel")))


func test_clearing_the_filter_shows_every_card_again() -> void:
	_screen.filter_bar().press("colorless")

	_screen.filter_bar().press("clear")

	for card: DeckbuilderCard in _sample.collection.cards():
		assert_not_null(_screen.collection_face(card))
	assert_eq(_screen.filter_bar().count_label().text, "111 cards")


## A card in the Collection whose base card is named [param card_name], with no Mods.
func _owned(card_name: String) -> DeckbuilderCard:
	for card: DeckbuilderCard in _sample.collection.cards():
		if card.run_card.base.name == card_name and card.mods.is_empty():
			return card
	return null
