extends GutTest
## The decks authored in Content, which a debug run is built from and the start form offers.


func test_every_deck_in_content_is_listed_in_order() -> void:
	assert_eq(ContentDecks.names(), ["arahbo_the_first_fang", "blue_red", "charmed_stray", "kemba_kha_enduring", "king_of_the_pride", "red_green", "steppe_lynx", "vanguard_of_brimaz", "white_black", "zar_ojanen_scion_of_efrava"] as Array[String])


func test_a_deck_is_found_by_its_name() -> void:
	assert_true(ContentDecks.has("red_green"))
	assert_false(ContentDecks.has("purple"))
	assert_eq(ContentDecks.load_deck("red_green").resource_path, "res://content/decks/red_green.tres")
