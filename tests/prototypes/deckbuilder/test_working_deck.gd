extends GutTest
## The Working Deck is the unsaved copy of a Deck being edited: which Run Cards are in it,
## which column each was put in, whether it is legal, and whether it differs from what was
## saved (ADR 0028).

const Fixture: GDScript = preload("res://tests/prototypes/deckbuilder/deckbuilder_fixture.gd")

var _fixture: Fixture


func before_each() -> void:
	_fixture = Fixture.new()


func test_adding_a_card_puts_it_in_the_column_asked_for() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()

	assert_true(deck.add(bolt, 4))

	assert_true(deck.contains(bolt))
	assert_eq(deck.column_of(bolt), 4)
	assert_eq(deck.cards_in(4), [bolt] as Array[DeckbuilderCard])
	assert_eq(deck.size(), 1)


func test_adding_a_card_twice_does_nothing() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()
	deck.add(bolt, 4)

	assert_false(deck.add(bolt, 2))

	assert_eq(deck.column_of(bolt), 4)
	assert_eq(deck.size(), 1)


func test_two_copies_of_a_card_are_two_cards() -> void:
	var first: DeckbuilderCard = _fixture.own("lightning_bolt")
	var second: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()

	deck.add_to_own_column(first)
	deck.add_to_own_column(second)

	assert_eq(deck.cards_in(1).size(), 2, "Nothing is stacked.")
	assert_ne(first.id, second.id)


func test_a_card_added_to_its_own_column_goes_by_mana_value() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	var tower: DeckbuilderCard = _fixture.own("ivory_tower")
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")
	var angel: DeckbuilderCard = _fixture.own("serra_angel")

	for card: DeckbuilderCard in [tower, bears, angel]:
		deck.add_to_own_column(card)

	assert_eq(deck.column_of(tower), 1)
	assert_eq(deck.column_of(bears), 2)
	assert_eq(deck.column_of(angel), 5)


func test_six_and_above_share_the_last_mana_value_column() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	var wurm: DeckbuilderCard = _fixture.own("craw_wurm")
	wurm.attach(Fixture.add_symbol_mod(MmMana.Type.GREEN))

	deck.add_to_own_column(wurm)

	assert_eq(wurm.mana_value(), 7)
	assert_eq(deck.column_of(wurm), WorkingDeck.SIX_PLUS_COLUMN)


func test_a_land_goes_to_the_lands_column() -> void:
	var deck: WorkingDeck = _fixture.working_deck()

	var forest: DeckbuilderCard = deck.add_basic_land("Forest")

	assert_eq(deck.column_of(forest), WorkingDeck.LANDS_COLUMN)
	assert_eq(deck.own_column_of(forest), WorkingDeck.LANDS_COLUMN)


func test_moving_a_card_changes_its_column_and_nothing_else() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")
	var deck: WorkingDeck = _fixture.working_deck()
	deck.add_to_own_column(bolt)
	deck.add_to_own_column(bears)

	assert_true(deck.move(bolt, 5))

	assert_eq(deck.column_of(bolt), 5)
	assert_eq(deck.column_of(bears), 2)
	assert_eq(deck.size(), 2)
	assert_eq(deck.cards_in(1).size(), 0)


func test_a_card_that_is_not_in_the_deck_cannot_be_moved() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()

	assert_false(deck.move(bolt, 5))

	assert_false(deck.contains(bolt))


func test_a_column_outside_the_eight_is_refused() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()

	assert_false(deck.add(bolt, WorkingDeck.COLUMN_COUNT))
	assert_false(deck.add(bolt, -1))

	assert_false(deck.contains(bolt))


func test_removing_a_card_leaves_it_in_the_collection_but_not_the_deck() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()
	deck.add_to_own_column(bolt)

	assert_true(deck.remove(bolt))

	assert_false(deck.contains(bolt))
	assert_eq(deck.column_of(bolt), WorkingDeck.NO_COLUMN)
	assert_eq(deck.size(), 0)
	assert_true(_fixture.collection.cards().has(bolt))
	assert_true(deck.add_to_own_column(bolt), "It can go back in.")


func test_a_basic_land_is_never_in_the_collection_and_is_discarded_when_removed() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	var first: DeckbuilderCard = deck.add_basic_land("Mountain")
	var second: DeckbuilderCard = deck.add_basic_land("Mountain")

	assert_eq(deck.size(), 2)
	assert_ne(first.id, second.id, "Each basic land is its own card.")
	assert_eq(_fixture.collection.cards().size(), 0)

	deck.remove(first)

	assert_eq(deck.size(), 1)
	assert_eq(deck.cards_in(WorkingDeck.LANDS_COLUMN), [second] as Array[DeckbuilderCard])
	assert_false(deck.add(first, WorkingDeck.LANDS_COLUMN), "A discarded basic land is gone.")


func test_an_unknown_basic_land_is_not_added() -> void:
	var deck: WorkingDeck = _fixture.working_deck()

	assert_null(deck.add_basic_land("Wastes"))

	assert_eq(deck.size(), 0)


func test_a_column_lists_colors_in_wubrg_order_then_multicolor_then_colorless_then_by_name() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	var gold: DeckbuilderCard = _fixture.own("grizzly_bears")
	gold.attach(Fixture.add_symbol_mod(MmMana.Type.RED))
	var order_added: Array[DeckbuilderCard] = [
		_fixture.own("ivory_tower"), gold, _fixture.own("llanowar_elves"), _fixture.own("lightning_bolt"),
		_fixture.own("black_knight"), _fixture.own("counterspell"), _fixture.own("white_knight"),
		_fixture.own("savannah_lions"), _fixture.own("giant_growth"),
	]
	for card: DeckbuilderCard in order_added:
		deck.add(card, 3)

	assert_eq(Fixture.names(deck.cards_in(3)), [
		"Savannah Lions", "White Knight", "Counterspell", "Black Knight", "Lightning Bolt",
		"Giant Growth", "Llanowar Elves", "Grizzly Bears", "Ivory Tower",
	] as Array[String])


func test_sorting_puts_every_card_back_in_its_own_column() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var angel: DeckbuilderCard = _fixture.own("serra_angel")
	var deck: WorkingDeck = _fixture.working_deck()
	deck.add(bolt, 6)
	deck.add(angel, 0)
	var forest: DeckbuilderCard = deck.add_basic_land("Forest")
	deck.move(forest, 2)

	deck.sort()

	assert_eq(deck.column_of(bolt), 1)
	assert_eq(deck.column_of(angel), 5)
	assert_eq(deck.column_of(forest), WorkingDeck.LANDS_COLUMN)


func test_a_mod_that_changes_a_cards_cost_does_not_move_it_until_it_is_sorted() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")
	var deck: WorkingDeck = _fixture.working_deck()
	deck.add_to_own_column(bears)

	bears.attach(Fixture.add_symbol_mod(MmMana.Type.GREEN))

	assert_eq(deck.column_of(bears), 2, "It stays where it was put.")
	assert_eq(deck.own_column_of(bears), 3)
	deck.sort()
	assert_eq(deck.column_of(bears), 3)


func test_a_deck_is_legal_at_forty_cards_with_basic_lands_counted() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	for index: int in 22:
		deck.add_to_own_column(_fixture.own("grizzly_bears"))
	for index: int in 17:
		deck.add_basic_land("Forest")

	assert_eq(deck.size(), 39)
	assert_false(deck.is_legal())

	deck.add_basic_land("Forest")

	assert_eq(deck.size(), WorkingDeck.MINIMUM_SIZE)
	assert_true(deck.is_legal())

	deck.add_basic_land("Forest")

	assert_true(deck.is_legal(), "There is no upper limit.")


func test_adding_removing_and_renaming_are_unsaved_changes() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()
	assert_false(deck.has_unsaved_changes(), "A new Working Deck has nothing to lose.")

	deck.add_to_own_column(bolt)
	assert_true(deck.has_unsaved_changes())

	deck.name = "Burn"
	assert_eq(deck.save(), "")
	assert_false(deck.has_unsaved_changes())

	deck.remove(bolt)
	assert_true(deck.has_unsaved_changes())

	deck.add_to_own_column(bolt)
	assert_false(deck.has_unsaved_changes(), "It is back to what was saved.")

	deck.name = "Burn 2"
	assert_true(deck.has_unsaved_changes())

	deck.name = "Burn"
	deck.add_basic_land("Mountain")
	assert_true(deck.has_unsaved_changes())


func test_moving_a_card_between_columns_is_not_an_unsaved_change() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()
	deck.add_to_own_column(bolt)
	deck.name = "Burn"
	deck.save()

	deck.move(bolt, 6)

	assert_false(deck.has_unsaved_changes())


func test_saving_writes_the_deck_to_the_deckbox() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var deck: WorkingDeck = _fixture.working_deck()
	deck.add_to_own_column(bolt)
	deck.add_basic_land("Mountain")
	deck.add_basic_land("Mountain")
	deck.add_basic_land("Forest")
	deck.name = "  Burn  "

	assert_eq(deck.save(), "")

	assert_eq(_fixture.deckbox.decks().size(), 1)
	var saved: Deck = _fixture.deckbox.decks()[0]
	assert_eq(saved.name, "Burn", "The name is trimmed.")
	assert_eq(saved.card_ids, [bolt.id] as Array[int])
	assert_eq(saved.basic_lands, {"Mountain": 2, "Forest": 1} as Dictionary[String, int])
	assert_eq(saved.size(), 4)


func test_saving_twice_replaces_the_deck_rather_than_adding_another() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	deck.name = "Burn"
	deck.save()
	deck.add_to_own_column(_fixture.own("lightning_bolt"))

	assert_eq(deck.save(), "")

	assert_eq(_fixture.deckbox.decks().size(), 1)
	assert_eq(_fixture.deckbox.decks()[0].size(), 1)


func test_saving_refuses_an_empty_name() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	deck.name = "   "

	assert_ne(deck.save(), "")

	assert_eq(_fixture.deckbox.decks().size(), 0)


func test_saving_refuses_a_name_another_deck_has() -> void:
	var first: WorkingDeck = _fixture.working_deck()
	first.name = "Burn"
	first.save()
	var second: WorkingDeck = _fixture.working_deck()
	second.name = "burn"

	assert_ne(second.save(), "", "Names differing only in capitals count as the same.")

	assert_eq(_fixture.deckbox.decks().size(), 1)
	second.name = "Stompy"
	assert_eq(second.save(), "")
	assert_eq(_fixture.deckbox.decks().size(), 2)


func test_an_illegal_deck_can_be_saved() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	deck.name = "One card"
	deck.add_to_own_column(_fixture.own("lightning_bolt"))

	assert_eq(deck.save(), "")

	assert_false(deck.is_legal())


func test_opening_a_saved_deck_puts_every_card_in_its_own_column() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var angel: DeckbuilderCard = _fixture.own("serra_angel")
	var first: WorkingDeck = _fixture.working_deck()
	first.add(bolt, 6)
	first.add(angel, 0)
	first.move(first.add_basic_land("Plains"), 3)
	first.name = "Piles"
	first.save()

	var reopened: WorkingDeck = _fixture.working_deck(_fixture.deckbox.decks()[0])

	assert_eq(reopened.name, "Piles")
	assert_eq(reopened.size(), 3)
	assert_eq(reopened.column_of(bolt), 1)
	assert_eq(reopened.column_of(angel), 5)
	assert_eq(Fixture.names(reopened.cards_in(WorkingDeck.LANDS_COLUMN)), ["Plains"] as Array[String])
	assert_false(reopened.has_unsaved_changes())


func test_one_run_card_can_be_in_several_decks() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var first: WorkingDeck = _fixture.working_deck()
	first.add_to_own_column(bolt)
	first.name = "First"
	first.save()
	var second: WorkingDeck = _fixture.working_deck()

	assert_true(second.add_to_own_column(bolt))
	second.name = "Second"

	assert_eq(second.save(), "")
	assert_eq(_fixture.deckbox.decks()[0].card_ids, _fixture.deckbox.decks()[1].card_ids)
