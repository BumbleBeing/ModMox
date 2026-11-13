extends GutTest
## Every authored card has a Rarity on its Card Definition (ADR 0033).

const CARDS: String = "res://content/cards/"


func test_a_card_definition_is_common_until_it_says_otherwise() -> void:
	assert_eq(MmCardDefinition.new().rarity, MmCardDefinition.Rarity.COMMON)


func test_the_rarities_are_in_order_of_scarcity() -> void:
	assert_eq(MmCardDefinition.Rarity.keys(), ["COMMON", "UNCOMMON", "RARE", "MYTHIC", "POWER_NINE"])


func test_authored_cards_have_the_rarity_they_were_given() -> void:
	var expected: Dictionary[String, MmCardDefinition.Rarity] = {
		"alpha/grizzly_bears": MmCardDefinition.Rarity.COMMON,
		"alpha/forest": MmCardDefinition.Rarity.COMMON,
		"alpha/lightning_bolt": MmCardDefinition.Rarity.COMMON,
		"alpha/serra_angel": MmCardDefinition.Rarity.UNCOMMON,
		"alpha/counterspell": MmCardDefinition.Rarity.UNCOMMON,
		"alpha/white_knight": MmCardDefinition.Rarity.UNCOMMON,
		"alpha/shivan_dragon": MmCardDefinition.Rarity.RARE,
		"alpha/howling_mine": MmCardDefinition.Rarity.RARE,
		"scourge/stifle": MmCardDefinition.Rarity.RARE,
		"alpha/ancestral_recall": MmCardDefinition.Rarity.POWER_NINE,
	}
	for card: String in expected:
		var definition: MmCardDefinition = load(CARDS + card + ".tres") as MmCardDefinition
		assert_eq(definition.rarity, expected[card], card)


func test_a_run_card_keeps_its_rarity_when_it_is_flattened() -> void:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = load(CARDS + "alpha/shivan_dragon.tres") as MmCardDefinition

	assert_eq(run_card.flatten().rarity, MmCardDefinition.Rarity.RARE)
