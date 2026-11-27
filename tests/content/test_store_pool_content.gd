extends GutTest
## The Store Pools in Content (milestone 24, ADR 0071): one authored list for each Tier, in
## content/store_pools/, each a card's path under content/cards/ to a line. A Store Pool never
## holds a basic land or a Power-9 card, and holds each card at most once.


func test_every_tier_has_a_store_pool() -> void:
	for tier: int in range(1, Villain.TIERS + 1):
		assert_false(ContentStorePools.pool(tier).is_empty(), "Tier %d" % tier)


func test_every_line_names_a_card_in_content() -> void:
	for tier: int in range(1, Villain.TIERS + 1):
		for line: String in ContentStorePools.lines_of(tier):
			assert_true(ResourceLoader.exists(ContentStorePools.CARDS % line), "Tier %d: %s" % [tier, line])
		assert_eq(ContentStorePools.pool(tier).size(), ContentStorePools.lines_of(tier).size(), "Tier %d" % tier)


func test_a_store_pool_holds_no_basic_land_and_no_power_9_card() -> void:
	for tier: int in range(1, Villain.TIERS + 1):
		for definition: MmCardDefinition in ContentStorePools.pool(tier):
			assert_false(definition.supertypes.has(MmCardTypes.Supertype.BASIC), "Tier %d: %s" % [tier, definition.name])
			assert_ne(definition.rarity, MmCardDefinition.Rarity.POWER_NINE, "Tier %d: %s" % [tier, definition.name])


func test_a_store_pool_holds_each_card_once() -> void:
	for tier: int in range(1, Villain.TIERS + 1):
		var seen: Dictionary[MmCardDefinition, bool] = {}
		for definition: MmCardDefinition in ContentStorePools.pool(tier):
			assert_false(seen.has(definition), "Tier %d: %s twice" % [tier, definition.name])
			seen[definition] = true


## Blank lines and lines that begin with "#" are left for whoever prunes the list.
func test_blank_lines_and_comments_are_skipped() -> void:
	var lines: Array[String] = ContentStorePools.lines_in("# Commons\nalpha/grizzly_bears\n\n  alpha/giant_growth  \n")

	assert_eq(lines, ["alpha/grizzly_bears", "alpha/giant_growth"] as Array[String])
