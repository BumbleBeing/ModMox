extends GutTest
## A Mod is a game-side item that leaves an engine Modification on a Run Card (ADR 0029).
## A card has three Mod Slots, Hexes included, and a basic land has none.

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


func test_a_basic_land_has_no_mod_slots() -> void:
	var forest: DeckbuilderCard = _fixture.working_deck().add_basic_land("Forest")

	assert_eq(forest.mod_slots(), 0)
	assert_false(Fixture.rename_mod("Grove").is_applicable_to(forest))


func test_applying_a_held_mod_changes_the_card_and_uses_the_mod_up() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var mod: Mod = Fixture.add_symbol_mod(MmMana.Type.RED)
	_fixture.held_mods.add(mod)
	_fixture.held_mods.add(mod)

	assert_true(_fixture.held_mods.apply(mod, bolt))

	assert_eq(bolt.mods, [mod] as Array[Mod])
	assert_eq(bolt.run_card.modifications.size(), 1)
	assert_eq(bolt.look().mana_cost.describe(), "{R}{R}")
	assert_eq(_fixture.held_mods.count_of(mod), 1)


func test_a_mod_that_is_not_held_or_not_applicable_is_not_applied() -> void:
	var bolt: DeckbuilderCard = _fixture.own("lightning_bolt")
	var forest: DeckbuilderCard = _fixture.working_deck().add_basic_land("Forest")
	var mod: Mod = Fixture.rename_mod("Zap")

	assert_false(_fixture.held_mods.apply(mod, bolt), "It is not held.")
	_fixture.held_mods.add(mod)
	assert_false(_fixture.held_mods.apply(mod, forest), "A basic land takes no Mod.")

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

	_fixture.held_mods.apply(mod, bolt)
	abandoned = null

	var reopened: WorkingDeck = _fixture.working_deck(_fixture.deckbox.decks()[0])
	assert_eq(Fixture.names(reopened.cards_in(1)), ["Zap"] as Array[String])
	assert_false(reopened.has_unsaved_changes(), "A Mod is not part of the Working Deck.")
