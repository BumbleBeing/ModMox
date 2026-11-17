extends GutTest
## The card tool reads a card's printed characteristics from its Oracle Data, and names what
## it cannot read rather than guessing (ADR 0040).

const CardType := MmCardTypes.CardType
const Supertype := MmCardTypes.Supertype
const Rarity := MmCardDefinition.Rarity


func test_a_mana_cost_is_its_generic_amount_and_its_colored_symbols() -> void:
	var reading: OracleReading = _reading({"mana_cost": "{2}{U}{U}"})

	assert_eq(reading.definition.mana_cost.generic, 2)
	assert_eq(reading.definition.mana_cost.symbols, [MmMana.Type.BLUE, MmMana.Type.BLUE] as Array[MmMana.Type])
	assert_eq(reading.refusals, PackedStringArray())


func test_c_is_the_colorless_symbol() -> void:
	var reading: OracleReading = _reading({"mana_cost": "{C}"})

	assert_eq(reading.definition.mana_cost.generic, 0)
	assert_eq(reading.definition.mana_cost.symbols, [MmMana.Type.COLORLESS] as Array[MmMana.Type])


func test_a_cost_of_zero_is_not_no_cost() -> void:
	# CR 202.1b: a card with no mana cost is different from one that costs {0}.
	var reading: OracleReading = _reading({"mana_cost": "{0}"})

	assert_not_null(reading.definition.mana_cost)
	assert_eq(reading.definition.mana_cost.mana_value(), 0)


func test_a_card_with_no_mana_cost_has_none() -> void:
	var reading: OracleReading = _reading({"mana_cost": "", "type_line": "Land"})

	assert_null(reading.definition.mana_cost)
	assert_eq(reading.refusals, PackedStringArray())


func test_symbols_the_engine_lacks_are_refused_by_name() -> void:
	for symbol: String in ["{X}", "{W/U}", "{G/P}", "{S}"]:
		var reading: OracleReading = _reading({"mana_cost": symbol + "{R}"})

		assert_eq(reading.refusals.size(), 1, symbol)
		assert_string_contains(reading.refusals[0] if not reading.refusals.is_empty() else "", symbol)


func test_a_type_line_gives_supertypes_card_types_and_subtypes() -> void:
	var definition: MmCardDefinition = _reading({"type_line": "Legendary Creature — Human Wizard"}).definition

	assert_eq(definition.supertypes, [Supertype.LEGENDARY])
	assert_eq(definition.card_types, [CardType.CREATURE])
	assert_eq(definition.subtypes, ["Human", "Wizard"])


func test_a_card_may_have_two_card_types() -> void:
	var definition: MmCardDefinition = _reading({"type_line": "Artifact Creature — Golem"}).definition

	assert_eq(definition.card_types, [CardType.ARTIFACT, CardType.CREATURE])
	assert_eq(definition.subtypes, ["Golem"])


func test_a_basic_land_is_basic_and_of_its_land_type() -> void:
	var reading: OracleReading = _reading({"name": "Forest", "type_line": "Basic Land — Forest", "mana_cost": ""})

	assert_eq(reading.definition.supertypes, [Supertype.BASIC])
	assert_eq(reading.definition.card_types, [CardType.LAND])
	assert_eq(reading.definition.subtypes, ["Forest"])


func test_a_card_with_no_subtypes_has_none() -> void:
	var definition: MmCardDefinition = _reading({"type_line": "Instant"}).definition

	assert_eq(definition.card_types, [CardType.INSTANT])
	assert_eq(definition.subtypes, [])


func test_a_type_the_engine_lacks_is_refused_by_name() -> void:
	var lacking: Dictionary[String, String] = {
		"Legendary Planeswalker — Jace": "Planeswalker",
		"Battle — Siege": "Battle",
		"Kindred Instant — Goblin": "Kindred",
		"Snow Creature — Bear": "Snow",
	}
	for type_line: String in lacking:
		var reading: OracleReading = _reading({"type_line": type_line})

		assert_eq(reading.refusals.size(), 1, type_line)
		assert_string_contains(reading.refusals[0] if not reading.refusals.is_empty() else "", lacking[type_line])


func test_power_and_toughness_are_read_as_numbers() -> void:
	var definition: MmCardDefinition = _reading({"power": "4", "toughness": "5"}).definition

	assert_eq([definition.power, definition.toughness], [4, 5])


func test_a_star_power_is_left_to_a_characteristic_defining_ability() -> void:
	# CR 604.3: a "*" power or toughness is defined by an ability, which is written in the
	# session that adds the card.
	var reading: OracleReading = _reading({"power": "*", "toughness": "1+*"})

	assert_eq([reading.definition.power, reading.definition.toughness], [0, 0])
	assert_eq(reading.refusals.size(), 2, "One for each.")


func test_a_card_with_no_power_has_none() -> void:
	var source: Dictionary = _vanilla()
	source.erase("power")
	source.erase("toughness")
	source["type_line"] = "Instant"

	var reading: OracleReading = OracleReading.of(source)

	assert_eq([reading.definition.power, reading.definition.toughness], [0, 0])
	assert_eq(reading.refusals, PackedStringArray())


func test_a_set_folder_is_its_name_in_snake_case() -> void:
	assert_eq(OracleReading.folder_of("Scourge"), "scourge")
	assert_eq(OracleReading.folder_of("Urza's Saga"), "urzas_saga")
	assert_eq(OracleReading.folder_of("Fifth Edition"), "fifth_edition")


func test_the_early_sets_go_by_their_nicknames() -> void:
	assert_eq(OracleReading.folder_of("Limited Edition Alpha"), "alpha")
	assert_eq(OracleReading.folder_of("Limited Edition Beta"), "beta")
	assert_eq(OracleReading.folder_of("Unlimited Edition"), "unlimited")
	assert_eq(OracleReading.folder_of("Revised Edition"), "revised")


func test_a_card_file_is_named_for_the_card_in_snake_case() -> void:
	assert_eq(OracleReading.file_name_of("Serra Angel"), "serra_angel")
	assert_eq(OracleReading.file_name_of("Merfolk of the Pearl Trident"), "merfolk_of_the_pearl_trident")
	assert_eq(OracleReading.file_name_of("Will-o'-the-Wisp"), "will_o_the_wisp")
	assert_eq(OracleReading.file_name_of("Lim-Dûl's Hex"), "lim_duls_hex")


func test_a_printings_rarity_is_the_cards_rarity() -> void:
	var expected: Dictionary[String, Rarity] = {
		"common": Rarity.COMMON, "uncommon": Rarity.UNCOMMON, "rare": Rarity.RARE, "mythic": Rarity.MYTHIC,
	}
	for rarity: String in expected:
		assert_eq(_reading({"rarity": rarity}).definition.rarity, expected[rarity], rarity)


func test_the_power_nine_are_power_nine_whatever_their_printing_says() -> void:
	for card_name: String in OracleReading.POWER_NINE:
		var reading: OracleReading = _reading({"name": card_name, "rarity": "rare"})

		assert_eq(reading.definition.rarity, Rarity.POWER_NINE, card_name)
	assert_eq(OracleReading.POWER_NINE.size(), 9)


func test_a_special_or_bonus_rarity_is_put_to_the_designer() -> void:
	for rarity: String in ["special", "bonus"]:
		var reading: OracleReading = _reading({"rarity": rarity})

		assert_eq(reading.refusals.size(), 1, rarity)
		assert_string_contains(reading.refusals[0] if not reading.refusals.is_empty() else "", rarity)


func test_a_card_with_two_faces_is_refused() -> void:
	var split: Dictionary = {
		"name": "Fire // Ice", "layout": "split", "type_line": "Instant // Instant",
		"card_faces": [{"name": "Fire"}, {"name": "Ice"}], "rarity": "uncommon", "set_name": "Apocalypse",
	}

	var reading: OracleReading = OracleReading.of(split)

	assert_eq(reading.refusals.size(), 1)
	assert_string_contains(reading.refusals[0] if not reading.refusals.is_empty() else "", "two faces")


func test_a_card_read_from_oracle_data_has_its_characteristics_and_no_abilities() -> void:
	var reading: OracleReading = OracleReading.of({
		"name": "Serra Angel", "mana_cost": "{3}{W}{W}", "type_line": "Creature — Angel",
		"power": "4", "toughness": "4", "oracle_text": "Flying, vigilance",
		"rarity": "uncommon", "set_name": "Limited Edition Alpha",
	})

	assert_eq(reading.definition.name, "Serra Angel")
	assert_eq(reading.definition.mana_cost.generic, 3)
	assert_eq(reading.definition.mana_cost.symbols, [MmMana.Type.WHITE, MmMana.Type.WHITE] as Array[MmMana.Type])
	assert_eq(reading.definition.card_types, [CardType.CREATURE])
	assert_eq(reading.definition.subtypes, ["Angel"])
	assert_eq([reading.definition.power, reading.definition.toughness], [4, 4])
	assert_eq(reading.definition.rarity, Rarity.UNCOMMON)
	assert_eq(reading.definition.abilities, [], "Abilities are composed in the session.")
	assert_eq(reading.folder, "alpha")
	assert_eq(reading.file_name, "serra_angel")
	assert_eq(reading.refusals, PackedStringArray())


func test_a_card_read_from_oracle_data_loads_back_the_same_once_saved() -> void:
	var path: String = "user://test_oracle_reading_card.tres"
	var definition: MmCardDefinition = _reading({"type_line": "Legendary Artifact Creature — Golem"}).definition

	assert_eq(ResourceSaver.save(definition, path), OK)
	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition
	DirAccess.remove_absolute(path)

	assert_eq(loaded.name, definition.name)
	assert_eq(loaded.mana_cost.generic, definition.mana_cost.generic)
	assert_eq(loaded.mana_cost.symbols, definition.mana_cost.symbols)
	assert_eq(loaded.supertypes, definition.supertypes)
	assert_eq(loaded.card_types, definition.card_types)
	assert_eq(loaded.subtypes, definition.subtypes)
	assert_eq([loaded.power, loaded.toughness], [definition.power, definition.toughness])
	assert_eq(loaded.rarity, definition.rarity)


## A vanilla 2/2 Bear's Oracle Data with [param changes] made to it.
func _reading(changes: Dictionary) -> OracleReading:
	var source: Dictionary = _vanilla()
	source.merge(changes, true)
	return OracleReading.of(source)


func _vanilla() -> Dictionary:
	return {
		"name": "Test Bears", "mana_cost": "{1}{G}", "type_line": "Creature — Bear",
		"power": "2", "toughness": "2", "oracle_text": "", "rarity": "common",
		"set_name": "Limited Edition Alpha",
	}
