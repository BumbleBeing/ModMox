extends GutTest
## An encounter is asked for on the start form or from the command line, until runs exist.


func test_arguments_naming_no_deck_or_seed_ask_for_the_start_form() -> void:
	assert_null(EncounterRequest.from_arguments(PackedStringArray()))
	assert_null(EncounterRequest.from_arguments(PackedStringArray(["--emblems", "--difficulty=hard", "--screenshot=/tmp/x.png"])))


func test_arguments_fill_in_the_request() -> void:
	var request: EncounterRequest = EncounterRequest.from_arguments(PackedStringArray(
		["--hero=blue_red", "--villain=red_green", "--seed=42", "--difficulty=normal", "--emblems"]))

	assert_eq(request.hero_deck, "blue_red")
	assert_eq(request.villain_deck, "red_green")
	assert_eq(request.encounter_seed, 42)
	assert_eq(request.difficulty, "normal")
	assert_true(request.has_sample_emblems)
	assert_eq(request.validate(), "")


func test_a_seed_alone_is_enough_and_the_rest_keeps_its_defaults() -> void:
	var request: EncounterRequest = EncounterRequest.from_arguments(PackedStringArray(["--seed=7"]))

	assert_eq(request.encounter_seed, 7)
	assert_eq(request.hero_deck, "red_green")
	assert_eq(request.difficulty, "easy", "Easy unless asked otherwise (A215).")
	assert_false(request.has_sample_emblems)


func test_the_setup_uses_the_named_decks_and_seed() -> void:
	var request: EncounterRequest = EncounterRequest.new()
	request.hero_deck = "blue_red"
	request.villain_deck = "white_black"
	request.encounter_seed = 9

	var setup: MmEncounterSetup = request.setup()

	assert_eq(setup.validate(), "")
	assert_eq(setup.encounter_seed, 9)
	assert_eq(setup.hero, load("res://content/decks/blue_red.tres"))
	assert_eq(setup.villain, load("res://content/decks/white_black.tres"))
	assert_eq(setup.hero.emblems.size(), 0)


func test_sample_emblems_go_on_copies_and_leave_the_loaded_decks_alone() -> void:
	var request: EncounterRequest = EncounterRequest.new()
	request.has_sample_emblems = true

	var setup: MmEncounterSetup = request.setup()

	assert_eq(_names(setup.hero.emblems), ["Sample Boon: Howling Winds", "Diviner's Boon", "Electromancer's Boon"] as Array[String])
	assert_eq(_names(setup.villain.emblems), ["Sample Hex: Ankh's Curse", "Electromancer's Boon"] as Array[String])
	assert_eq(setup.hero.potions.size(), 0)
	assert_eq(setup.hero.emblems[0].card_types.size(), 0, "An Emblem has abilities and nothing else.")
	assert_gt(setup.hero.emblems[0].abilities.size(), 0)
	assert_eq((load("res://content/decks/red_green.tres") as MmPlayerSetup).emblems.size(), 0)
	assert_eq(setup.validate(), "")


func test_every_deck_in_content_is_offered() -> void:
	assert_eq(EncounterRequest.deck_names(), ["blue_red", "red_green", "white_black"] as Array[String])


func test_an_unknown_deck_or_difficulty_is_refused_with_a_reason() -> void:
	var request: EncounterRequest = EncounterRequest.new()
	request.hero_deck = "purple"
	assert_string_contains(request.validate(), "purple")

	request.hero_deck = "red_green"
	request.difficulty = "impossible"
	assert_string_contains(request.validate(), "impossible")


func test_the_villain_plays_at_the_requested_difficulty() -> void:
	var request: EncounterRequest = EncounterRequest.new()
	assert_false((request.villain_agent() as AiAgent).difficulty.uses_monte_carlo, "Easy has no rollouts.")

	request.difficulty = "hard"
	assert_eq((request.villain_agent() as AiAgent).difficulty.rollout_samples, 12)


func test_a_request_has_the_plain_backdrop_unless_one_is_named() -> void:
	assert_eq(EncounterRequest.new().backdrop, "plain")
	assert_eq(EncounterRequest.from_arguments(PackedStringArray(["--seed=7"])).backdrop, "plain")


func test_the_backdrop_is_named_on_the_command_line() -> void:
	var request: EncounterRequest = EncounterRequest.from_arguments(PackedStringArray(["--seed=7", "--backdrop=red"]))

	assert_eq(request.backdrop, "red")
	assert_eq(request.validate(), "")


func test_a_backdrop_alone_still_asks_for_the_start_form() -> void:
	assert_null(EncounterRequest.from_arguments(PackedStringArray(["--backdrop=red"])))


func test_an_unknown_backdrop_is_refused_with_a_reason() -> void:
	var request: EncounterRequest = EncounterRequest.new()
	request.backdrop = "purple"

	assert_string_contains(request.validate(), "purple")


func test_the_potions_flag_gives_the_hero_one_big_gulp_on_a_copy() -> void:
	var request: EncounterRequest = EncounterRequest.from_arguments(PackedStringArray(["--seed=3", "--potions"]))

	var setup: MmEncounterSetup = request.setup()

	assert_true(request.has_sample_potions)
	assert_false(request.has_sample_emblems)
	assert_eq(_names(setup.hero.potions), ["Big Gulp"] as Array[String])
	assert_eq(setup.villain.potions.size(), 0, "Only the Hero is given Potions (A523).")
	assert_eq((load("res://content/decks/red_green.tres") as MmPlayerSetup).potions.size(), 0)
	assert_eq(setup.validate(), "")


func test_a_request_without_the_flag_holds_no_potion() -> void:
	assert_false(EncounterRequest.from_arguments(PackedStringArray(["--seed=3", "--emblems"])).has_sample_potions)


func _names(definitions: Array[MmCardDefinition]) -> Array[String]:
	var names: Array[String] = []
	for definition: MmCardDefinition in definitions:
		names.append(definition.name)
	return names
