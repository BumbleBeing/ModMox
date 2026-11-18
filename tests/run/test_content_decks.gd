extends GutTest
## The decks authored in Content, which a debug run is built from and the start form offers.


func test_every_deck_in_content_is_listed_in_order() -> void:
	assert_eq(ContentDecks.names(), ["blue_red", "charmed_stray", "red_green", "white_black"] as Array[String])


func test_a_deck_is_found_by_its_name() -> void:
	assert_true(ContentDecks.has("red_green"))
	assert_false(ContentDecks.has("purple"))
	assert_eq(ContentDecks.load_deck("red_green").resource_path, "res://content/decks/red_green.tres")
