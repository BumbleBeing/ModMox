extends GutTest
## The Deckbox and the Collection behind it (ADR 0028, milestone 16): Run Card identities,
## Decks holding only identities, the Active Deck, and New, Duplicate and Delete Deck.

const ALPHA: String = "res://content/cards/alpha/%s.tres"

var _collection: Collection
var _deckbox: Deckbox


func before_each() -> void:
	_collection = Collection.new()
	_deckbox = Deckbox.new()


func _own(card: String) -> DeckbuilderCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = load(ALPHA % card) as MmCardDefinition
	return _collection.add(run_card)


func _deck_of(deck_name: String, cards: Array[DeckbuilderCard], forests: int = 0) -> Deck:
	var deck: Deck = Deck.new()
	deck.name = deck_name
	for card: DeckbuilderCard in cards:
		deck.card_ids.append(card.id)
	if forests > 0:
		deck.basic_lands["Forest"] = forests
	_deckbox.put(deck)
	return deck


func test_the_collection_hands_out_identities_counting_up_from_one() -> void:
	var first: DeckbuilderCard = _own("grizzly_bears")
	var second: DeckbuilderCard = _own("grizzly_bears")
	assert_eq(first.id, 1)
	assert_eq(second.id, 2)
	assert_eq(_collection.next_id(), 3)


func test_an_identity_is_never_given_again_after_its_card_leaves() -> void:
	var first: DeckbuilderCard = _own("grizzly_bears")
	_collection.remove(first)
	var second: DeckbuilderCard = _own("hill_giant")
	assert_eq(second.id, 2)
	assert_null(_collection.card(1))


func test_an_adopted_basic_land_takes_the_next_identity() -> void:
	_own("grizzly_bears")
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = load(ALPHA % "forest") as MmCardDefinition
	var land: DeckbuilderCard = DeckbuilderCard.new(-1, run_card)
	_collection.adopt(land)
	assert_eq(land.id, 2)
	assert_true(_collection.owns(land))


func test_a_deck_holds_identities_and_never_the_cards() -> void:
	var bears: DeckbuilderCard = _own("grizzly_bears")
	var deck: Deck = _deck_of("Bears", [bears])
	assert_eq(deck.card_ids, [bears.id] as Array[int])
	for property: Dictionary in deck.get_property_list():
		assert_ne(property["class_name"], &"DeckbuilderCard", property["name"])


func test_a_card_leaving_the_collection_drops_out_of_every_deck() -> void:
	var bears: DeckbuilderCard = _own("grizzly_bears")
	var giant: DeckbuilderCard = _own("hill_giant")
	var one: Deck = _deck_of("One", [bears, giant])
	var two: Deck = _deck_of("Two", [bears])
	_collection.remove(bears)
	_deckbox.forget(bears.id)
	assert_eq(one.card_ids, [giant.id] as Array[int])
	assert_true(two.card_ids.is_empty())


func test_a_deck_is_legal_at_forty_cards_or_more() -> void:
	var bears: DeckbuilderCard = _own("grizzly_bears")
	var short: Deck = _deck_of("Short", [bears], 38)
	var legal: Deck = _deck_of("Legal", [bears], 39)
	assert_false(_deckbox.is_legal(short))
	assert_true(_deckbox.is_legal(legal))


func test_there_is_no_active_deck_until_one_is_set() -> void:
	var deck: Deck = _deck_of("One", [])
	assert_null(_deckbox.active())
	_deckbox.set_active(deck)
	assert_eq(_deckbox.active(), deck)
	assert_true(_deckbox.is_active(deck))


func test_only_a_kept_deck_can_be_active() -> void:
	var loose: Deck = Deck.new()
	_deckbox.set_active(loose)
	assert_null(_deckbox.active())


func test_duplicating_a_deck_keeps_the_same_cards_under_a_new_name_after_it() -> void:
	var bears: DeckbuilderCard = _own("grizzly_bears")
	var first: Deck = _deck_of("Bears", [bears], 3)
	var after: Deck = _deck_of("After", [])
	var copy: Deck = _deckbox.duplicate_deck(first)
	assert_eq(copy.name, "Bears (copy)")
	assert_eq(copy.card_ids, first.card_ids)
	assert_eq(copy.basic_lands, first.basic_lands)
	assert_eq(_deckbox.decks(), [first, copy, after] as Array[Deck])
	copy.card_ids.clear()
	assert_eq(first.card_ids.size(), 1, "the copy has a list of its own")


func test_a_duplicate_of_a_duplicate_takes_a_free_name() -> void:
	var first: Deck = _deck_of("Bears", [])
	_deckbox.duplicate_deck(first)
	assert_eq(_deckbox.duplicate_deck(first).name, "Bears (copy 2)")


func test_duplicating_the_active_deck_leaves_the_original_active() -> void:
	var first: Deck = _deck_of("Bears", [])
	_deckbox.set_active(first)
	_deckbox.duplicate_deck(first)
	assert_eq(_deckbox.active(), first)


func test_deleting_a_deck_removes_it_and_leaves_its_cards_in_the_collection() -> void:
	var bears: DeckbuilderCard = _own("grizzly_bears")
	var deck: Deck = _deck_of("Bears", [bears])
	_deckbox.delete(deck)
	assert_true(_deckbox.decks().is_empty())
	assert_true(_collection.owns(bears))


func test_deleting_the_active_deck_leaves_no_active_deck() -> void:
	var first: Deck = _deck_of("One", [])
	var second: Deck = _deck_of("Two", [])
	_deckbox.set_active(first)
	_deckbox.delete(first)
	assert_null(_deckbox.active())
	_deckbox.delete(second)
	assert_null(_deckbox.active())


func test_deleting_another_deck_keeps_the_active_one() -> void:
	var first: Deck = _deck_of("One", [])
	var second: Deck = _deck_of("Two", [])
	_deckbox.set_active(first)
	_deckbox.delete(second)
	assert_eq(_deckbox.active(), first)


func test_a_decks_colors_are_its_cards_colors_in_wubrg_order() -> void:
	var bolt: DeckbuilderCard = _own("lightning_bolt")
	var elves: DeckbuilderCard = _own("llanowar_elves")
	var serra: DeckbuilderCard = _own("serra_angel")
	var deck: Deck = _deck_of("Three", [elves, bolt, serra], 10)
	assert_eq(_deckbox.colors_of(deck, _collection), [MmCardTypes.CardColor.WHITE, MmCardTypes.CardColor.RED, MmCardTypes.CardColor.GREEN] as Array[MmCardTypes.CardColor])


func test_a_deck_of_colorless_cards_and_basic_lands_has_no_colors() -> void:
	var deck: Deck = _deck_of("Lands", [], 40)
	assert_true(_deckbox.colors_of(deck, _collection).is_empty())
