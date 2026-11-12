extends GutTest
## The Collection pane's search, filters and sort order. Colors combine as "any of these".

const Fixture: GDScript = preload("res://tests/prototypes/deckbuilder/deckbuilder_fixture.gd")

var _fixture: Fixture
var _filter: CollectionFilter


func before_each() -> void:
	_fixture = Fixture.new()
	_filter = CollectionFilter.new()
	for card: String in ["serra_angel", "savannah_lions", "counterspell", "lightning_bolt", "grizzly_bears",
			"craw_wurm", "ivory_tower", "black_knight", "giant_growth"]:
		_fixture.own(card)
	_fixture.own("grizzly_bears").attach(Fixture.add_symbol_mod(MmMana.Type.RED))
	_fixture.collection.cards()[-1].attach(Fixture.rename_mod("Ember Bears"))


func test_no_filter_shows_everything_by_color_then_mana_value_then_name() -> void:
	assert_eq(_shown(), [
		"Savannah Lions", "Serra Angel", "Counterspell", "Black Knight", "Lightning Bolt",
		"Giant Growth", "Grizzly Bears", "Craw Wurm", "Ember Bears", "Ivory Tower",
	] as Array[String])


func test_search_matches_name_type_line_and_rules_text() -> void:
	_filter.search = "KNIGHT"
	assert_eq(_shown(), ["Black Knight"] as Array[String], "A name, whatever its capitals.")

	_filter.search = "instant"
	assert_eq(_shown(), ["Counterspell", "Lightning Bolt", "Giant Growth"] as Array[String], "A type line.")

	_filter.search = "flying"
	assert_eq(_shown(), ["Serra Angel"] as Array[String], "Rules text.")


func test_every_word_searched_for_must_be_found() -> void:
	_filter.search = "creature bear"

	assert_eq(_shown(), ["Grizzly Bears", "Ember Bears"] as Array[String])


func test_colors_combine_as_any_of_these() -> void:
	_filter.colors = [MmCardTypes.CardColor.WHITE, MmCardTypes.CardColor.RED]

	assert_eq(_shown(), ["Savannah Lions", "Serra Angel", "Lightning Bolt", "Ember Bears"] as Array[String],
			"A red-green card is red.")


func test_multicolor_and_colorless_are_filters_of_their_own() -> void:
	_filter.multicolor = true
	assert_eq(_shown(), ["Ember Bears"] as Array[String])

	_filter.colorless = true
	assert_eq(_shown(), ["Ember Bears", "Ivory Tower"] as Array[String])

	_filter.multicolor = false
	_filter.colors = [MmCardTypes.CardColor.BLUE]
	assert_eq(_shown(), ["Counterspell", "Ivory Tower"] as Array[String])


func test_card_types_combine_as_any_of_these() -> void:
	_filter.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.INSTANT]

	assert_eq(_shown(), ["Counterspell", "Lightning Bolt", "Giant Growth", "Ivory Tower"] as Array[String])


func test_mana_values_filter_with_six_meaning_six_or_more() -> void:
	_filter.mana_values = [1]
	assert_eq(_shown(), ["Savannah Lions", "Lightning Bolt", "Giant Growth", "Ivory Tower"] as Array[String])

	_filter.mana_values = [5, 6]
	assert_eq(_shown(), ["Serra Angel", "Craw Wurm"] as Array[String])


func test_filters_of_different_kinds_must_all_hold() -> void:
	_filter.colors = [MmCardTypes.CardColor.GREEN]
	_filter.card_types = [MmCardTypes.CardType.CREATURE]
	_filter.mana_values = [2, 3]
	_filter.search = "bears"

	assert_eq(_shown(), ["Grizzly Bears", "Ember Bears"] as Array[String])


func test_sorting_by_mana_value_name_and_type() -> void:
	_filter.colors = [MmCardTypes.CardColor.WHITE, MmCardTypes.CardColor.BLUE, MmCardTypes.CardColor.RED]

	_filter.sort_key = CollectionFilter.SortKey.MANA_VALUE
	assert_eq(_shown(), ["Savannah Lions", "Lightning Bolt", "Counterspell", "Ember Bears", "Serra Angel"] as Array[String])

	_filter.sort_key = CollectionFilter.SortKey.NAME
	assert_eq(_shown(), ["Counterspell", "Ember Bears", "Lightning Bolt", "Savannah Lions", "Serra Angel"] as Array[String])

	_filter.sort_key = CollectionFilter.SortKey.TYPE
	assert_eq(_shown(), ["Ember Bears", "Savannah Lions", "Serra Angel", "Counterspell", "Lightning Bolt"] as Array[String],
			"Creatures, then instants, each by name.")


func test_an_active_filter_is_reported_and_can_be_cleared() -> void:
	assert_false(_filter.is_active())
	_filter.search = "x"
	_filter.colorless = true
	assert_true(_filter.is_active())

	_filter.clear()

	assert_false(_filter.is_active())
	assert_eq(_shown().size(), 10)


func _shown() -> Array[String]:
	return Fixture.names(_filter.apply(_fixture.collection.cards()))
