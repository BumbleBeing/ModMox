extends GutTest
## SR4 (milestone 24, ADR 0070): everything a Store sells or buys is priced from one short
## list by one formula. A card starts from its Rarity's price, each Hex takes 40% off what is
## left, then half of each Mod's Workshop price is added, rounded to the nearest 5 and never
## below 5. A Potion is priced by its Rarity, an Armor by its own price, and a Store buys at a
## third of what it sells for, rounded down. Every number here is the spec's, written out.

const Sample := preload("res://tests/support/store_sample.gd")
const COMMON: MmCardDefinition.Rarity = MmCardDefinition.Rarity.COMMON
const UNCOMMON: MmCardDefinition.Rarity = MmCardDefinition.Rarity.UNCOMMON
const RARE: MmCardDefinition.Rarity = MmCardDefinition.Rarity.RARE
const MYTHIC: MmCardDefinition.Rarity = MmCardDefinition.Rarity.MYTHIC
const ANCESTRAL_RECALL: String = "res://content/cards/alpha/ancestral_recall.tres"
const FOREST: String = "res://content/cards/alpha/forest.tres"
const SEERS_CUIRASS: String = "res://content/armor/seers_cuirass.tres"
const BIG_GULP: String = "res://content/potions/big_gulp.tres"


func test_a_plain_card_costs_its_raritys_price() -> void:
	assert_eq(_price_of(COMMON, []), 25)
	assert_eq(_price_of(UNCOMMON, []), 50)
	assert_eq(_price_of(RARE, []), 100)
	assert_eq(_price_of(MYTHIC, []), 150)


## Half of a Mod's Workshop price is added: a Common Mod's 40 adds 20, a Mythic's 160 adds 80.
func test_a_mod_adds_half_its_workshop_price() -> void:
	assert_eq(_price_of(RARE, [Sample.mod("Common Mod", Mod.Rarity.COMMON)]), 120)
	assert_eq(_price_of(COMMON, [Sample.mod("Mythic Mod", Mod.Rarity.MYTHIC)]), 105)


## 25 and half of an Uncommon Mod's 75 is 62.5, which rounds to the nearest 5, up.
func test_the_price_is_rounded_to_the_nearest_5() -> void:
	assert_eq(_price_of(COMMON, [Sample.mod("Uncommon Mod", Mod.Rarity.UNCOMMON)]), 65)


## 150, half of a Rare Mod's 125 and half of a Mythic Mod's 160: 292.5, which is 295.
func test_each_mod_adds_its_own_half() -> void:
	var mods: Array[Mod] = [Sample.mod("Rare Mod", Mod.Rarity.RARE), Sample.mod("Mythic Mod", Mod.Rarity.MYTHIC)]

	assert_eq(_price_of(MYTHIC, mods), 295)


## Each Hex takes 40% off what is left: 100, then 60, then 36, which is 35.
func test_each_hex_takes_40_percent_off_compounding() -> void:
	assert_eq(_price_of(RARE, [Sample.hex("Hex")]), 60)
	assert_eq(_price_of(RARE, [Sample.hex("Hex"), Sample.hex("Other Hex")]), 35)


## Three Hexes on a Common leave 5.4, which is 5; nothing is ever priced below 5.
func test_a_price_is_never_below_5() -> void:
	assert_eq(_price_of(COMMON, [Sample.hex("Hex"), Sample.hex("Other Hex"), Sample.hex("Third Hex")]), 5)


## The Hexes discount the card before any Mod is added, whichever came first: 100 less 40%
## is 60, and a Mythic Mod adds 80.
func test_a_hex_discounts_the_card_and_never_its_mod() -> void:
	var hex: Mod = Sample.hex("Hex")
	var mythic: Mod = Sample.mod("Mythic Mod", Mod.Rarity.MYTHIC)

	assert_eq(_price_of(RARE, [hex, mythic]), 140)
	assert_eq(_price_of(RARE, [mythic, hex]), 140)


func test_a_potion_costs_its_raritys_price() -> void:
	assert_eq(Prices.of_potion(Sample.potion("Common Potion", COMMON)), 20)
	assert_eq(Prices.of_potion(Sample.potion("Uncommon Potion", UNCOMMON)), 35)
	assert_eq(Prices.of_potion(Sample.potion("Rare Potion", RARE)), 60)
	assert_eq(Prices.of_potion(Sample.potion("Mythic Potion", MYTHIC)), 100)
	assert_eq(Prices.of_potion(load(BIG_GULP) as MmCardDefinition), 20, "Big Gulp is Common")


func test_an_armor_costs_its_own_price() -> void:
	assert_eq(Prices.of_armor(load(SEERS_CUIRASS) as Armor), 200)


## A Store buys at a third of what it sells for, rounded down: 65 is 21, 100 is 33.
func test_a_store_buys_at_a_third_rounded_down() -> void:
	assert_eq(Prices.sale_of(65), 21)
	assert_eq(Prices.sale_of(100), 33)
	assert_eq(Prices.sale_of(200), 66)
	assert_eq(Prices.sale_of(20), 6)


## A card is sold for a third of its Store price as it is, its Mods with it: 120 is 40.
func test_a_card_sells_for_a_third_of_its_price_as_it_is() -> void:
	var card: DeckbuilderCard = Sample.held(Sample.card("Rare", RARE), [Sample.mod("Common Mod", Mod.Rarity.COMMON)])

	assert_eq(Prices.sale_of_card(card), 40)


## Agreed at the milestone's start: a Power-9 card and a basic land, with or without a Mod,
## cannot be sold; every other card can.
func test_neither_a_power_9_card_nor_a_basic_land_can_be_sold() -> void:
	var forest: MmCardDefinition = load(FOREST) as MmCardDefinition
	var land_mod: Mod = Sample.land_mod("Land Mod")

	assert_false(Prices.can_be_sold(Sample.held(load(ANCESTRAL_RECALL) as MmCardDefinition)), "Power-9")
	assert_false(Prices.can_be_sold(Sample.held(forest)), "a basic land")
	assert_false(Prices.can_be_sold(Sample.held(forest, [land_mod])), "a basic land with a Mod")
	assert_true(Prices.can_be_sold(Sample.held(Sample.card("Mythic", MYTHIC))))


func _price_of(rarity: MmCardDefinition.Rarity, mods: Array[Mod]) -> int:
	return Prices.of_card(Sample.held(Sample.card("Card", rarity), mods))
