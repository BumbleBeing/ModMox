extends GutTest
## SR1 to SR3 (milestone 24, ADR 0071): a Store's stock, rolled on arrival from a stream of
## its own of the Run Seed. Nine goods, each a card 75%, a Potion 20% or an Armor 5%. A card
## rolls its Rarity from the Tier's odds and is drawn from the Tier's Store Pool, falling back
## to the nearest lower Rarity the pool holds (and, agreed at the milestone's start, the
## nearest higher when it holds none lower), never twice in one Store and never a Power-9
## card. Each card then rolls a Mod 15%, a Hex 10% or nothing 75%, again after each Mod or Hex
## until a roll comes up nothing or its Mod Slots are full; a Mod is drawn with the Tier's
## odds from those that accept the card as it reads then, never a Unique one, and a Hex evenly
## from those that accept it. A roll with nothing to draw counts as nothing. Potions are drawn
## with the Tier's odds and Armor evenly, and either may come up twice. Every number here is
## the spec's, written out, never worked out the way the roll works it out.

const Sample := preload("res://tests/support/store_sample.gd")
const CARD: StoreGood.Kind = StoreGood.Kind.CARD
const POTION: StoreGood.Kind = StoreGood.Kind.POTION
const ARMOR: StoreGood.Kind = StoreGood.Kind.ARMOR
const COMMON: MmCardDefinition.Rarity = MmCardDefinition.Rarity.COMMON
const UNCOMMON: MmCardDefinition.Rarity = MmCardDefinition.Rarity.UNCOMMON
const RARE: MmCardDefinition.Rarity = MmCardDefinition.Rarity.RARE
const MYTHIC: MmCardDefinition.Rarity = MmCardDefinition.Rarity.MYTHIC
const SEERS_CUIRASS: String = "res://content/armor/seers_cuirass.tres"
const ANCESTRAL_RECALL: String = "res://content/cards/alpha/ancestral_recall.tres"
## Enough Stores that a share is within a couple of points of its odds.
const MANY: int = 800
const TOLERANCE: float = 0.02

var _pool: Array[MmCardDefinition] = Sample.pool(30)
var _potions: Array[MmCardDefinition] = [
	Sample.potion("Common Potion", COMMON), Sample.potion("Uncommon Potion", UNCOMMON),
	Sample.potion("Rare Potion", RARE), Sample.potion("Mythic Potion", MYTHIC),
]
var _armor: Array[Armor] = [load(SEERS_CUIRASS) as Armor]
var _no_mods: Array[Mod] = []


## SR1: the same Run Seed gives the same nine goods, Mods and Hexes included.
func test_the_same_run_seed_gives_the_same_stock() -> void:
	var mods: Array[Mod] = [Sample.mod("Strong", Mod.Rarity.COMMON), Sample.hex("Burden")]

	var first: StoreStock = StoreStock.roll(1, RunRandom.new(7), _pool, _potions, _armor, mods)
	var second: StoreStock = StoreStock.roll(1, RunRandom.new(7), _pool, _potions, _armor, mods)

	assert_eq(first.goods().size(), StoreStock.GOODS)
	assert_eq(_described(first), _described(second))
	assert_ne(_described(first), _described(StoreStock.roll(1, RunRandom.new(8), _pool, _potions, _armor, mods)))


## SR1: the stock draws from a stream of its own, so rolling one leaves every other stream
## where it was.
func test_rolling_a_stock_leaves_the_other_streams_alone() -> void:
	var rolled: RunRandom = RunRandom.new(7)
	var untouched: RunRandom = RunRandom.new(7)

	StoreStock.roll(1, rolled, _pool, _potions, _armor, _no_mods)

	for stream: String in [RunRandom.VILLAINS, RunRandom.SPOILS_GOLD, RunRandom.SPOILS_CARDS, RunRandom.ENCOUNTER_SEEDS]:
		assert_eq(rolled.pick(stream, 1000000), untouched.pick(stream, 1000000), stream)


## SR2: each good is a card 75% of the time, a Potion 20% and an Armor 5%.
func test_each_good_is_a_card_a_potion_or_an_armor() -> void:
	var counts: Dictionary = {}
	for run_seed: int in MANY:
		for good: StoreGood in _roll(run_seed, 1).goods():
			counts[good.kind] = counts.get(good.kind, 0) + 1

	_assert_shares(counts, {CARD: 0.75, POTION: 0.2, ARMOR: 0.05})


## SR2: with no Potion or no Armor to draw, the good is a card.
func test_with_no_potions_or_armor_every_good_is_a_card() -> void:
	var none: Array[MmCardDefinition] = []
	var no_armor: Array[Armor] = []

	for run_seed: int in 40:
		for good: StoreGood in StoreStock.roll(1, RunRandom.new(run_seed), _pool, none, no_armor, _no_mods).goods():
			assert_eq(good.kind, CARD)


## SR2: at Tier 1 a card is Common 55%, Uncommon 30%, Rare 12% and Mythic 3%.
func test_cards_roll_their_rarity_from_tier_1s_odds() -> void:
	_assert_shares(_card_rarities(1, _pool), {COMMON: 0.55, UNCOMMON: 0.3, RARE: 0.12, MYTHIC: 0.03})


## SR2: at Tier 5, 20%, 38%, 32% and 10%.
func test_cards_roll_their_rarity_from_tier_5s_odds() -> void:
	_assert_shares(_card_rarities(5, _pool), {COMMON: 0.2, UNCOMMON: 0.38, RARE: 0.32, MYTHIC: 0.1})


## SR2: with no Uncommon or Mythic in the pool, a rolled Uncommon is Common and a rolled
## Mythic is Rare, the nearest lower Rarity held.
func test_a_rarity_the_pool_lacks_falls_back_to_the_nearest_lower() -> void:
	var pool: Array[MmCardDefinition] = _of_rarities([COMMON, RARE])

	_assert_shares(_card_rarities(1, pool), {COMMON: 0.85, RARE: 0.15})


## SR2: with only Rares in the pool, a rolled Common or Uncommon, having nothing lower, is
## the nearest higher.
func test_with_nothing_lower_it_falls_back_to_the_nearest_higher() -> void:
	var pool: Array[MmCardDefinition] = _of_rarities([RARE])

	_assert_shares(_card_rarities(1, pool), {RARE: 1.0})


## SR2: no card is stocked twice in one Store; with fewer cards in the pool than come up,
## the Store has fewer goods.
func test_no_card_comes_up_twice_in_one_store() -> void:
	var pool: Array[MmCardDefinition] = [Sample.card("One", COMMON), Sample.card("Two", COMMON),
		Sample.card("Three", RARE)]
	var none: Array[MmCardDefinition] = []
	var no_armor: Array[Armor] = []

	for run_seed: int in 60:
		var names: Array[String] = []
		for good: StoreGood in StoreStock.roll(1, RunRandom.new(run_seed), pool, none, no_armor, _no_mods).goods():
			assert_false(names.has(good.name()), "%s twice, seed %d" % [good.name(), run_seed])
			names.append(good.name())
		assert_eq(names.size(), 3)


## SR2: a Power-9 card is never for sale, even when the pool holds one.
func test_a_power_9_card_is_never_stocked() -> void:
	var pool: Array[MmCardDefinition] = [load(ANCESTRAL_RECALL) as MmCardDefinition]
	pool.append_array(_of_rarities([COMMON]))

	for run_seed: int in 100:
		for good: StoreGood in _roll(run_seed, 5, pool).goods():
			if good.kind == CARD:
				assert_ne(good.card.run_card.base.rarity, MmCardDefinition.Rarity.POWER_NINE)


## SR2: Potions are drawn with the Tier's Rarity odds.
func test_potions_roll_their_rarity_from_the_tiers_odds() -> void:
	var counts: Dictionary = {}
	for run_seed: int in MANY * 3:
		for good: StoreGood in _roll(run_seed, 1).goods():
			if good.kind == POTION:
				counts[good.potion.rarity] = counts.get(good.potion.rarity, 0) + 1

	_assert_shares(counts, {COMMON: 0.55, UNCOMMON: 0.3, RARE: 0.12, MYTHIC: 0.03})


## SR2, agreed at the milestone's start: one Store may stock the same Potion twice, and the
## same Armor.
func test_a_potion_and_an_armor_may_come_up_twice() -> void:
	var potions: Array[MmCardDefinition] = [Sample.potion("Only Potion", COMMON)]
	var most_potions: int = 0
	var most_armor: int = 0
	for run_seed: int in 300:
		var stock: StoreStock = StoreStock.roll(1, RunRandom.new(run_seed), _pool, potions, _armor, _no_mods)
		most_potions = maxi(most_potions, _count_of(stock, POTION))
		most_armor = maxi(most_armor, _count_of(stock, ARMOR))

	assert_gt(most_potions, 1, "some Store has the one Potion twice")
	assert_gt(most_armor, 1, "some Store has the one Armor twice")


## SR2: Armor is drawn evenly from every Armor.
func test_armor_is_drawn_evenly() -> void:
	var second: Armor = (load(SEERS_CUIRASS) as Armor).duplicate() as Armor
	second.name = "Second Cuirass"
	var armor: Array[Armor] = [_armor[0], second]
	var counts: Dictionary = {}
	for run_seed: int in MANY * 4:
		for good: StoreGood in StoreStock.roll(1, RunRandom.new(run_seed), _pool, _potions, armor, _no_mods).goods():
			if good.kind == ARMOR:
				counts[good.armor.name] = counts.get(good.armor.name, 0) + 1

	_assert_shares(counts, {"Seer's Cuirass": 0.5, "Second Cuirass": 0.5}, 0.05)


## SR3: a card's first roll is a Mod 15%, a Hex 10% or nothing 75%.
func test_a_cards_first_roll_is_a_mod_a_hex_or_nothing() -> void:
	var mods: Array[Mod] = [Sample.mod("Strong", Mod.Rarity.COMMON), Sample.hex("Burden")]
	var counts: Dictionary = {}
	for good: StoreGood in _cards_of(MANY, 1, mods):
		var first: String = "nothing"
		if not good.card.mods.is_empty():
			first = "hex" if good.card.mods[0].is_hex else "mod"
		counts[first] = counts.get(first, 0) + 1

	_assert_shares(counts, {"mod": 0.15, "hex": 0.1, "nothing": 0.75})


## SR3: after a Mod or a Hex it rolls again at the same odds, so a card carries none 75% of
## the time, one 18.75%, two 4.69% and three 1.56%, never more, and may carry both.
func test_a_card_rolls_again_after_each_mod_or_hex_until_its_slots_are_full() -> void:
	var mods: Array[Mod] = [Sample.mod("Strong", Mod.Rarity.COMMON), Sample.hex("Burden")]
	var counts: Dictionary = {}
	var has_both: bool = false
	for good: StoreGood in _cards_of(MANY * 2, 1, mods):
		assert_lte(good.card.mods.size(), DeckbuilderCard.MOD_SLOTS)
		counts[good.card.mods.size()] = counts.get(good.card.mods.size(), 0) + 1
		var hexes: int = good.card.mods.filter(func(mod: Mod) -> bool: return mod.is_hex).size()
		has_both = has_both or (hexes > 0 and hexes < good.card.mods.size())

	_assert_shares(counts, {0: 0.75, 1: 0.1875, 2: 0.0469, 3: 0.0156}, 0.01)
	assert_true(has_both, "some card carries both a Mod and a Hex")


## SR3: Mods are drawn with the Tier's Rarity odds, and a Unique Mod never is.
func test_mods_roll_their_rarity_and_are_never_unique() -> void:
	var mods: Array[Mod] = [
		Sample.mod("Common Mod", Mod.Rarity.COMMON), Sample.mod("Uncommon Mod", Mod.Rarity.UNCOMMON),
		Sample.mod("Rare Mod", Mod.Rarity.RARE), Sample.mod("Mythic Mod", Mod.Rarity.MYTHIC),
		Sample.mod("Unique Mod", Mod.Rarity.UNIQUE),
	]
	var counts: Dictionary = {}
	for good: StoreGood in _cards_of(MANY * 4, 1, mods):
		for mod: Mod in good.card.mods:
			counts[mod.rarity] = counts.get(mod.rarity, 0) + 1

	assert_false(counts.has(Mod.Rarity.UNIQUE), "no Unique Mod")
	_assert_shares(counts, {Mod.Rarity.COMMON: 0.55, Mod.Rarity.UNCOMMON: 0.3, Mod.Rarity.RARE: 0.12,
		Mod.Rarity.MYTHIC: 0.03}, 0.03)


## SR3: a Mod is drawn only from those that accept the card as it reads then: one that
## accepts no creature is never on one, and a Mod a card may hold once is never on it twice.
func test_a_mod_is_drawn_only_from_those_that_accept_the_card() -> void:
	var once: Mod = Sample.mod("Once", Mod.Rarity.COMMON)
	once.is_once_per_card = true
	var mods: Array[Mod] = [Sample.land_mod("Land Mod"), once]

	for good: StoreGood in _cards_of(MANY, 1, mods):
		assert_false(good.card.mods.any(func(mod: Mod) -> bool: return mod.name == "Land Mod"), good.name())
		assert_lte(good.card.mods.size(), 1, good.name())


## SR3, agreed at the milestone's start: a roll with nothing to draw counts as nothing, so
## with no Hex that accepts the card, a card only ever carries Mods, and with no Mod at all
## it carries none.
func test_a_roll_with_nothing_to_draw_counts_as_nothing() -> void:
	var mods: Array[Mod] = [Sample.mod("Strong", Mod.Rarity.COMMON)]
	var modded: int = 0
	var cards: Array[StoreGood] = _cards_of(MANY, 1, mods)
	for good: StoreGood in cards:
		assert_false(good.card.mods.any(func(mod: Mod) -> bool: return mod.is_hex))
		if not good.card.mods.is_empty():
			modded += 1

	assert_almost_eq(modded / float(cards.size()), 0.15, TOLERANCE, "a Mod 15%, and nothing else")
	for good: StoreGood in _cards_of(40, 1, _no_mods):
		assert_true(good.card.mods.is_empty())


## SR3: a Hex is drawn evenly from those that accept the card.
func test_hexes_are_drawn_evenly() -> void:
	var mods: Array[Mod] = [Sample.hex("Burden"), Sample.hex("Blight")]
	var counts: Dictionary = {}
	for good: StoreGood in _cards_of(MANY * 3, 1, mods):
		for mod: Mod in good.card.mods:
			counts[mod.name] = counts.get(mod.name, 0) + 1

	_assert_shares(counts, {"Burden": 0.5, "Blight": 0.5}, 0.04)


## A card in stock reads with its Mods and Hexes, under its Modded Name, at its Store price as
## it is.
func test_a_modded_card_in_stock_reads_and_costs_as_it_is() -> void:
	var mods: Array[Mod] = [Sample.mod("Strong", Mod.Rarity.COMMON)]
	var modded: StoreGood = null
	for good: StoreGood in _cards_of(MANY, 1, mods):
		if not good.card.mods.is_empty():
			modded = good
			break

	assert_not_null(modded)
	assert_string_contains(modded.name(), "Strong ")
	assert_string_ends_with(modded.name(), modded.card.run_card.base.name)
	assert_eq(modded.price(), Prices.of_card(modded.card))


func _roll(run_seed: int, tier: int, pool: Array[MmCardDefinition] = _pool) -> StoreStock:
	return StoreStock.roll(tier, RunRandom.new(run_seed), pool, _potions, _armor, _no_mods)


## Every card stocked in [param stores] Stores of [param tier] rolled with [param mods].
func _cards_of(stores: int, tier: int, mods: Array[Mod]) -> Array[StoreGood]:
	var cards: Array[StoreGood] = []
	for run_seed: int in stores:
		for good: StoreGood in StoreStock.roll(tier, RunRandom.new(run_seed), _pool, _potions, _armor, mods).goods():
			if good.kind == CARD:
				cards.append(good)
	return cards


func _card_rarities(tier: int, pool: Array[MmCardDefinition]) -> Dictionary:
	var counts: Dictionary = {}
	for run_seed: int in MANY:
		for good: StoreGood in _roll(run_seed, tier, pool).goods():
			if good.kind == CARD:
				var rarity: MmCardDefinition.Rarity = good.card.run_card.base.rarity
				counts[rarity] = counts.get(rarity, 0) + 1
	return counts


## The sample pool's cards of [param rarities] alone.
func _of_rarities(rarities: Array[MmCardDefinition.Rarity]) -> Array[MmCardDefinition]:
	return _pool.filter(func(definition: MmCardDefinition) -> bool: return rarities.has(definition.rarity))


func _count_of(stock: StoreStock, kind: StoreGood.Kind) -> int:
	return stock.goods().filter(func(good: StoreGood) -> bool: return good.kind == kind).size()


## Each good of [param stock] as words, in its order: what it is, its name, and its price.
func _described(stock: StoreStock) -> Array[String]:
	var described: Array[String] = []
	for good: StoreGood in stock.goods():
		described.append("%s %s %d" % [StoreGood.Kind.keys()[good.kind], good.name(), good.price()])
	return described


func _assert_shares(counts: Dictionary, expected: Dictionary, tolerance: float = TOLERANCE) -> void:
	var total: int = 0
	for key: Variant in counts:
		total += counts[key]
	assert_eq(counts.keys().size(), expected.keys().size(), "only %s come up: %s" % [expected.keys(), counts])
	for key: Variant in expected:
		assert_almost_eq(counts.get(key, 0) / float(total), float(expected[key]), tolerance, "the share of %s" % [key])
