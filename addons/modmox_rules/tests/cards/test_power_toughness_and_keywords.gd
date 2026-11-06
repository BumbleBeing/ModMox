extends GutTest
## ADR 0009: power and toughness, and keyword abilities, are read through the
## characteristics query, which starts from the printed characteristics.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_printed_power_and_toughness_come_from_the_card_definition() -> void:
	var printed: MmCharacteristics = MmCharacteristics.printed(Scenario.creature("Giant", 3, 4))

	assert_eq(printed.base_power, 3)
	assert_eq(printed.base_toughness, 4)
	assert_eq(printed.power, 3, "Nothing changes it yet, so it equals the base value.")
	assert_eq(printed.toughness, 4)


func test_a_modified_card_has_its_new_power_and_toughness() -> void:
	var run_card: MmRunCard = Scenario.run_cards([Scenario.creature("Giant", 3, 3)])[0]
	var flattened: MmCardDefinition = run_card.flatten()
	flattened.power = 5

	assert_eq(MmCharacteristics.printed(flattened).power, 5)
	assert_eq(MmCharacteristics.printed(run_card.base).power, 3, "The base definition is untouched.")


func test_keywords_are_abilities_found_by_kind() -> void:
	var printed: MmCharacteristics = MmCharacteristics.printed(
		Scenario.creature("Knight", 2, 2, [FirstStrikeAbility.new(), TrampleAbility.new()]))

	assert_true(printed.has_ability(FirstStrikeAbility))
	assert_true(printed.has_ability(TrampleAbility))
	assert_false(printed.has_ability(DoubleStrikeAbility))
	assert_false(printed.has_ability(FlashAbility))
	assert_true(printed.has_ability(StaticAbility), "Every keyword is a static ability.")


func test_permanent_cards_are_recognized_by_type() -> void:
	assert_true(MmCharacteristics.printed(Scenario.creature("Bear", 2, 2)).is_permanent())
	assert_true(MmCharacteristics.printed(Scenario.basic_land("Forest")).is_permanent())
	assert_false(MmCharacteristics.printed(Scenario.bolt()).is_permanent())
