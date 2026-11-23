extends GutTest
## A card's printed characteristics are held to its Oracle Data, but for its Rebalances
## (ADR 0040).


func test_an_entry_holds_the_cards_oracle_data_with_its_first_printings_set_and_rarity() -> void:
	var card: Dictionary = {
		"oracle_id": "abc", "name": "Test Bears", "mana_cost": "{1}{G}", "type_line": "Creature — Bear",
		"power": "2", "toughness": "2", "oracle_text": "", "rarity": "rare",
		"set_name": "Masters 25", "layout": "normal",
	}
	var first_printing: Dictionary = {"rarity": "common", "set_name": "Limited Edition Alpha"}

	var entry: Dictionary = OracleData.entry_of(card, first_printing)

	assert_eq(entry, {
		"oracle_id": "abc", "name": "Test Bears", "mana_cost": "{1}{G}", "type_line": "Creature — Bear",
		"power": "2", "toughness": "2", "oracle_text": "", "rarity": "common",
		"set_name": "Limited Edition Alpha",
	})


func test_an_entry_of_a_card_with_no_power_has_none() -> void:
	var card: Dictionary = {"name": "Test Bolt", "mana_cost": "{R}", "type_line": "Instant", "oracle_text": "Boom."}

	var entry: Dictionary = OracleData.entry_of(card, {"rarity": "common", "set_name": "Limited Edition Alpha"})

	assert_false(entry.has("power"))
	assert_false(entry.has("toughness"))


func test_a_card_that_matches_its_oracle_data_has_no_mismatches() -> void:
	assert_eq(OracleData.mismatches(_bears(), _entry()), PackedStringArray())


func test_the_check_catches_a_card_that_differs_from_its_oracle_data() -> void:
	var renamed: MmCardDefinition = _bears()
	renamed.name = "Test Bear"
	var cheaper: MmCardDefinition = _bears()
	cheaper.mana_cost.generic = 0
	var retyped: MmCardDefinition = _bears()
	retyped.subtypes = ["Cat"]
	var stronger: MmCardDefinition = _bears()
	stronger.power = 3
	var tougher: MmCardDefinition = _bears()
	tougher.toughness = 3

	assert_eq(OracleData.mismatches(renamed, _entry()), PackedStringArray(["name"]))
	assert_eq(OracleData.mismatches(cheaper, _entry()), PackedStringArray(["mana_cost"]))
	assert_eq(OracleData.mismatches(retyped, _entry()), PackedStringArray(["type_line"]))
	assert_eq(OracleData.mismatches(stronger, _entry()), PackedStringArray(["power"]))
	assert_eq(OracleData.mismatches(tougher, _entry()), PackedStringArray(["toughness"]))


func test_a_plain_symbol_differs_from_a_hybrid_one() -> void:
	var hybrid: Dictionary = _entry()
	hybrid["mana_cost"] = "{1}{G/W}"
	var plain: MmCardDefinition = _bears()
	plain.mana_cost.symbols = [] as Array[MmMana.Type]
	plain.mana_cost.hybrid_symbols = [Vector2i(MmMana.Type.GREEN, MmMana.Type.WHITE)] as Array[Vector2i]

	assert_eq(OracleData.mismatches(_bears(), hybrid), PackedStringArray(["mana_cost"]), "{G} is not {G/W}.")
	assert_eq(OracleData.mismatches(plain, hybrid), PackedStringArray())


func test_a_card_with_a_cost_differs_from_oracle_data_with_none() -> void:
	var land: Dictionary = _entry()
	land["mana_cost"] = ""

	assert_eq(OracleData.mismatches(_bears(), land), PackedStringArray(["mana_cost"]))


func test_a_rebalanced_field_is_let_through() -> void:
	var cheaper: MmCardDefinition = _bears()
	cheaper.mana_cost.generic = 0
	var entry: Dictionary = _entry()
	entry["rebalanced"] = ["mana_cost"]

	assert_eq(OracleData.mismatches(cheaper, entry), PackedStringArray())


func test_rarity_is_never_checked() -> void:
	# A3: Rarity is the field most often rebalanced, so it is not held to its first printing.
	var rarer: MmCardDefinition = _bears()
	rarer.rarity = MmCardDefinition.Rarity.RARE

	assert_eq(OracleData.mismatches(rarer, _entry()), PackedStringArray())


func test_a_rebalance_of_a_field_that_is_not_checked_is_reported() -> void:
	var entry: Dictionary = _entry()
	entry["rebalanced"] = ["rarity"]

	assert_eq(OracleData.mismatches(_bears(), entry), PackedStringArray(["rebalanced: rarity"]))


func _bears() -> MmCardDefinition:
	return OracleReading.of(_entry()).definition


func _entry() -> Dictionary:
	return {
		"name": "Test Bears", "mana_cost": "{1}{G}", "type_line": "Creature — Bear",
		"power": "2", "toughness": "2", "oracle_text": "", "rarity": "common",
		"set_name": "Limited Edition Alpha",
	}
