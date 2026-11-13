extends GutTest
## A Mod is a game-side item that leaves an engine Modification on a Run Card (ADR 0029).
## Every card has three Mod Slots, Hexes included. A basic land is free until its first Mod,
## which makes it a Run Card of the Collection's (A558). A Mod's name goes in front of the
## card's (A559).

const Fixture: GDScript = preload("res://tests/prototypes/deckbuilder/deckbuilder_fixture.gd")

var _fixture: Fixture


func before_each() -> void:
	_fixture = Fixture.new()


func test_a_mod_is_applicable_to_a_card_with_an_empty_mod_slot_that_its_rule_accepts() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")

	assert_true(Fixture.add_symbol_mod(MmMana.Type.RED).is_applicable_to(bolt))
	assert_eq(bolt.mod_slots(), 3)
	assert_true(bolt.has_empty_mod_slot())


func test_a_mod_is_not_applicable_to_a_card_its_rule_refuses() -> void:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = MmCardDefinition.new()
	run_card.base.name = "Costless Relic"
	run_card.base.card_types = [MmCardTypes.CardType.ARTIFACT]
	var relic: DeckbuilderCard = _fixture.collection.add(run_card)

	assert_false(Fixture.add_symbol_mod(MmMana.Type.RED).is_applicable_to(relic), "It has no mana cost.")
	assert_true(Fixture.rename_mod("Relic").is_applicable_to(relic))


func test_a_card_with_three_mods_takes_no_more() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	for index: int in 3:
		bolt.attach(Fixture.add_symbol_mod(MmMana.Type.RED))

	assert_false(bolt.has_empty_mod_slot())
	assert_false(Fixture.rename_mod("Bolt").is_applicable_to(bolt))


func test_a_hex_takes_a_mod_slot() -> void:
	var hex: Mod = Fixture.add_symbol_mod(MmMana.Type.COLORLESS, true)
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt", [hex, hex])

	assert_eq(bolt.mods.size(), 2)
	assert_eq(bolt.mana_value(), 3)
	bolt.attach(Fixture.rename_mod("Bolt"))
	assert_false(bolt.has_empty_mod_slot())


func test_a_basic_land_has_three_mod_slots_like_any_card() -> void:
	var forest: DeckbuilderCard = _fixture.working_deck().add_basic_land("Forest")

	assert_eq(forest.mod_slots(), 3)
	assert_true(Fixture.word_mod("Ancient").is_applicable_to(forest))
	assert_false(Fixture.add_symbol_mod(MmMana.Type.RED).is_applicable_to(forest), "It has no mana cost.")


func test_a_basic_lands_first_mod_makes_it_a_run_card_of_the_collections() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	deck.add_basic_land("Plains")
	var plains: DeckbuilderCard = deck.add_basic_land("Plains")
	var ancient: Mod = Fixture.word_mod("Ancient")
	_fixture.held_mods.add(ancient)
	assert_false(_fixture.collection.owns(plains))

	assert_true(_fixture.held_mods.apply(ancient, plains, _fixture.collection))

	assert_true(_fixture.collection.owns(plains))
	assert_gt(plains.id, 0, "The Collection gave it an identity that lasts the run.")
	assert_eq(_fixture.collection.card(plains.id), plains)
	assert_true(deck.contains(plains), "It stays in the Deck, where it was.")
	assert_eq(plains.look().name, "Ancient Plains")
	assert_eq(deck.basic_land_count("Plains"), 1, "Only a card named exactly Plains counts.")


func test_a_modified_basic_land_is_saved_as_a_card_and_stays_owned_when_taken_out() -> void:
	var deck: WorkingDeck = _fixture.working_deck()
	deck.name = "Lands"
	var plains: DeckbuilderCard = deck.add_basic_land("Plains")
	deck.add_basic_land("Plains")
	var ancient: Mod = Fixture.word_mod("Ancient")
	_fixture.held_mods.add(ancient)
	_fixture.held_mods.apply(ancient, plains, _fixture.collection)

	assert_eq(deck.save(), "")
	var saved: Deck = _fixture.deckbox.decks()[0]
	assert_eq(saved.card_ids, [plains.id] as Array[int])
	assert_eq(saved.basic_lands, {"Plains": 1} as Dictionary[String, int])

	assert_true(deck.remove(plains))
	assert_true(_fixture.collection.owns(plains), "It is not thrown away like a free basic land.")
	assert_true(deck.add_to_own_column(plains))
	assert_eq(deck.column_of(plains), WorkingDeck.LANDS_COLUMN)
	assert_true(_fixture.working_deck(saved).contains(plains), "And the saved Deck reopens with it.")


func test_each_mods_name_goes_in_front_of_the_cards_in_slot_order() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears")

	assert_false(bears.is_modified())
	bears.attach(Fixture.word_mod("Violent"))
	assert_eq(bears.look().name, "Violent Grizzly Bears")
	bears.attach(Fixture.word_mod("Burdened", true))
	assert_eq(bears.look().name, "Violent Burdened Grizzly Bears", "A Hex's name too.")

	assert_true(bears.is_modified())
	assert_eq(bears.original_look().name, "Grizzly Bears")
	assert_eq(bears.with_mod(Fixture.word_mod("Mossy")).look().name, "Violent Burdened Mossy Grizzly Bears")
	assert_eq(bears.look().name, "Violent Burdened Grizzly Bears", "Looking ahead changes nothing.")


func test_the_original_is_the_card_with_no_mods_or_hexes() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt", [Fixture.add_symbol_mod(MmMana.Type.RED)])

	assert_eq(bolt.look().mana_cost.describe(), "{R}{R}")
	assert_eq(bolt.original_look().mana_cost.describe(), "{R}")
	assert_eq(bolt.original_look().art_key, "lightning_bolt")


func test_applying_a_held_mod_changes_the_card_and_uses_the_mod_up() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var mod: Mod = Fixture.add_symbol_mod(MmMana.Type.RED)
	_fixture.held_mods.add(mod)
	_fixture.held_mods.add(mod)

	assert_true(_fixture.held_mods.apply(mod, bolt, _fixture.collection))

	assert_eq(bolt.mods, [mod] as Array[Mod])
	assert_eq(bolt.run_card.modifications.size(), 1)
	assert_eq(bolt.look().mana_cost.describe(), "{R}{R}")
	assert_eq(_fixture.held_mods.count_of(mod), 1)


func test_a_mod_that_is_not_held_or_not_applicable_is_not_applied() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var forest: DeckbuilderCard = _fixture.working_deck().add_basic_land("Forest")
	var mod: Mod = Fixture.rename_mod("Zap")

	assert_false(_fixture.held_mods.apply(mod, bolt, _fixture.collection), "It is not held.")
	_fixture.held_mods.add(mod)
	var full: DeckbuilderCard = _fixture.own("grizzly_bears", [mod, mod, mod])
	assert_false(_fixture.held_mods.apply(mod, full, _fixture.collection), "Its Mod Slots are full.")
	assert_false(_fixture.held_mods.apply(Fixture.add_symbol_mod(MmMana.Type.RED), forest, _fixture.collection))
	assert_false(_fixture.collection.owns(forest), "A basic land that took no Mod is still free.")

	assert_eq(_fixture.held_mods.count_of(mod), 1)
	assert_eq(bolt.look().name, "Lightning Bolt")


func test_held_mods_are_listed_by_kind_in_the_order_first_held() -> void:
	var red: Mod = Fixture.add_symbol_mod(MmMana.Type.RED)
	var rename: Mod = Fixture.rename_mod("Zap")
	for mod: Mod in [red, rename, red]:
		_fixture.held_mods.add(mod)

	assert_eq(_fixture.held_mods.kinds(), [red, rename] as Array[Mod])
	assert_eq(_fixture.held_mods.count_of(red), 2)
	assert_eq(_fixture.held_mods.count_of(rename), 1)


func test_applying_a_mod_never_changes_the_base_card_definition() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var other: DeckbuilderCard = _fixture.own("lightning_bolt")

	bolt.attach(Fixture.rename_mod("Zap"))

	assert_eq(bolt.look().name, "Zap")
	assert_eq(other.look().name, "Lightning Bolt")
	assert_eq(Fixture.definition("lightning_bolt").name, "Lightning Bolt")
	assert_eq(bolt.look().art_key, "lightning_bolt", "A renamed card keeps its art.")


func test_a_mod_survives_leaving_without_saving_and_shows_in_every_deck_with_the_card() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var first: WorkingDeck = _fixture.working_deck()
	first.add_to_own_column(bolt)
	first.name = "First"
	first.save()
	var mod: Mod = Fixture.rename_mod("Zap")
	_fixture.held_mods.add(mod)
	var abandoned: WorkingDeck = _fixture.working_deck()
	abandoned.add_to_own_column(bolt)

	_fixture.held_mods.apply(mod, bolt, _fixture.collection)
	abandoned = null

	var reopened: WorkingDeck = _fixture.working_deck(_fixture.deckbox.decks()[0])
	assert_eq(Fixture.names(reopened.cards_in(1)), ["Zap"] as Array[String])
	assert_false(reopened.has_unsaved_changes(), "A Mod is not part of the Working Deck.")
