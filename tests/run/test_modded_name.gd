extends GutTest
## ADR 0029: a Modded Name is the names of the Mods and Hexes on a card in alphabetical
## order, in front of the card's own, with Very for a Mod held twice and Extremely for one
## held three times.

const Fixture: GDScript = preload("res://tests/ui/deckbuilder/support/deckbuilder_fixture.gd")


func test_a_card_with_no_mods_keeps_its_own_name() -> void:
	assert_eq(ModdedName.of("Grizzly Bears", []), "Grizzly Bears")


func test_a_mods_name_goes_in_front_of_the_cards() -> void:
	assert_eq(ModdedName.of("Grizzly Bears", _mods(["Violent"])), "Violent Grizzly Bears")


func test_the_cards_own_capitalization_never_changes() -> void:
	assert_eq(ModdedName.of("Arahbo, the First Fang", _mods(["Violent"])), "Violent Arahbo, the First Fang")
	assert_eq(ModdedName.of("Will-o'-the-Wisp", _mods(["Ancient"])), "Ancient Will-o'-the-Wisp")


func test_mods_and_hexes_go_in_alphabetical_order_whatever_order_they_were_applied() -> void:
	var mods: Array[Mod] = [Fixture.word_mod("Violent"), Fixture.word_mod("Burdened", true), Fixture.word_mod("Ancient")]

	assert_eq(ModdedName.of("Grizzly Bears", mods), "Ancient Burdened Violent Grizzly Bears")


func test_a_mod_held_twice_is_named_once_with_very() -> void:
	var violent: Mod = Fixture.word_mod("Violent")

	assert_eq(ModdedName.of("Grizzly Bears", [violent, violent]), "Very Violent Grizzly Bears")


func test_a_mod_held_three_times_is_named_once_with_extremely() -> void:
	var violent: Mod = Fixture.word_mod("Violent")

	assert_eq(ModdedName.of("Grizzly Bears", [violent, violent, violent]), "Extremely Violent Grizzly Bears")


func test_very_plays_no_part_in_the_order() -> void:
	var violent: Mod = Fixture.word_mod("Violent")
	var hoary: Mod = Fixture.word_mod("Hoary")

	assert_eq(ModdedName.of("Plains", [violent, Fixture.word_mod("Ancient"), violent]), "Ancient Very Violent Plains")
	assert_eq(ModdedName.of("Plains", [violent, violent, hoary]), "Hoary Very Violent Plains")


func test_a_mod_with_no_name_adds_no_word() -> void:
	assert_eq(ModdedName.of("Lightning Bolt", [Fixture.rename_mod("Zap")]), "Lightning Bolt")


func _mods(mod_names: Array[String]) -> Array[Mod]:
	var result: Array[Mod] = []
	for mod_name: String in mod_names:
		result.append(Fixture.word_mod(mod_name))
	return result
