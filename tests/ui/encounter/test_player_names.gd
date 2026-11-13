extends GutTest
## What each player is called (A445, ADR 0032): their own name when they have one,
## and their part when they do not.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_a_player_with_no_name_goes_by_their_part() -> void:
	var names: PlayerNames = PlayerNames.new()

	assert_eq(names.of(HERO), "Hero")
	assert_eq(names.of(VILLAIN), "Villain")
	assert_false(names.is_named(HERO))
	assert_eq(names.the(VILLAIN), "the Villain", "A part takes an article in a sentence.")
	assert_eq(names.starting(VILLAIN), "The Villain")
	assert_eq(PlayerNames.new("", "mishra").starting(VILLAIN), "Mishra")
	assert_eq(names.possessive(VILLAIN), "Villain's")
	assert_eq(names.the_possessive(HERO), "the Hero's")


func test_a_named_player_goes_by_their_name_without_an_article() -> void:
	var names: PlayerNames = PlayerNames.new("Jackson", "Mishra")

	assert_eq(names.of(HERO), "Jackson")
	assert_eq(names.of(VILLAIN), "Mishra")
	assert_true(names.is_named(VILLAIN))
	assert_eq(names.the(VILLAIN), "Mishra")
	assert_eq(names.possessive(HERO), "Jackson's")
	assert_eq(names.the_possessive(VILLAIN), "Mishra's")


func test_a_name_ending_in_s_takes_only_an_apostrophe() -> void:
	assert_eq(PlayerNames.new("Chris").possessive(HERO), "Chris'")


func test_a_blank_name_is_no_name() -> void:
	var names: PlayerNames = PlayerNames.new("   ", "")

	assert_eq(names.of(HERO), "Hero")
	assert_false(names.is_named(HERO))
	assert_eq(PlayerNames.new("  Jackson ").of(HERO), "Jackson", "Spaces around a name are dropped.")


func test_one_player_may_be_named_and_not_the_other() -> void:
	var names: PlayerNames = PlayerNames.new("Jackson")

	assert_eq(names.the(HERO), "Jackson")
	assert_eq(names.the(VILLAIN), "the Villain")


func test_a_request_carries_the_names_given_on_the_command_line() -> void:
	var request: EncounterRequest = EncounterRequest.from_arguments(
		["--seed=3", "--hero-name=Jackson", "--villain-name=Mishra"] as PackedStringArray)

	assert_eq(request.hero_name, "Jackson")
	assert_eq(request.names().of(HERO), "Jackson")
	assert_eq(request.names().of(VILLAIN), "Mishra")
	assert_eq(EncounterRequest.new().names().of(VILLAIN), "Villain", "No name given.")
	assert_null(EncounterRequest.from_arguments(["--hero-name=Jackson"] as PackedStringArray),
		"A name alone still means the start form.")


func test_the_start_form_asks_for_both_names() -> void:
	var form: StartForm = StartForm.new()
	add_child_autofree(form)
	form.hero_name_box().text = "Jackson"

	assert_eq(form.request().hero_name, "Jackson")
	assert_eq(form.request().villain_name, "")
	var wanted: EncounterRequest = EncounterRequest.new()
	wanted.villain_name = "Mishra"
	form.fill_in(wanted)
	assert_eq(form.villain_name_box().text, "Mishra")
	assert_eq(form.hero_name_box().text, "")
	assert_eq(form.villain_name_box().placeholder_text, "Villain")
