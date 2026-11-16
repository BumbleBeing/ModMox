extends GutTest
## A Portrait drawn after a Magic character keeps its card's art as a reference, named by
## the card, and credits it in its grid file's header.


func test_a_card_name_becomes_a_snake_case_key() -> void:
	assert_eq(ReferenceArt.key_of("Keldon Warlord"), "keldon_warlord")
	assert_eq(ReferenceArt.key_of("Merfolk of the Pearl Trident"), "merfolk_of_the_pearl_trident")


func test_apostrophes_are_dropped_and_other_marks_split_words() -> void:
	assert_eq(ReferenceArt.key_of("Mishra's Factory"), "mishras_factory")
	assert_eq(ReferenceArt.key_of("Gaea’s Cradle"), "gaeas_cradle")
	assert_eq(ReferenceArt.key_of("Lim-Dul, the Necromancer"), "lim_dul_the_necromancer")
	assert_eq(ReferenceArt.key_of("  Serra  Angel "), "serra_angel")


func test_the_header_credits_the_card_its_printing_and_its_artist() -> void:
	var printing: Dictionary = {
		"name": "Keldon Warlord",
		"set": "lea",
		"set_name": "Limited Edition Alpha",
		"collector_number": "160",
		"artist": "Kev Brockschmidt",
		"id": "0fb4e8a5-0000-0000-0000-000000000000",
	}

	var header: String = "\n".join(ReferenceArt.header(printing))

	assert_string_contains(header, "Keldon Warlord")
	assert_string_contains(header, "Limited Edition Alpha (lea) #160")
	assert_string_contains(header, "Kev Brockschmidt")
	assert_string_contains(header, "0fb4e8a5-0000-0000-0000-000000000000")


func test_every_header_line_is_a_grid_comment() -> void:
	var printing: Dictionary = {"name": "Keldon Warlord", "set": "lea", "collector_number": "160"}

	for line: String in ReferenceArt.header(printing):
		assert_true(line.begins_with("; "), line)


func test_a_card_whose_art_is_on_its_faces_is_told_apart() -> void:
	var double_faced: Dictionary = {"card_faces": [{"image_uris": {"art_crop": "x"}}, {}]}
	var plain: Dictionary = {"image_uris": {"art_crop": "x"}}

	assert_true(ReferenceArt.is_double_faced([double_faced]))
	assert_false(ReferenceArt.is_double_faced([plain]))
