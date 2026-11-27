class_name StoreStock
extends RefCounted
## What a Store has for sale (milestone 24, ADR 0071): nine goods, rolled as the Hero arrives
## from a stream of its own of the Run Seed (ADR 0025) and never restocked. While the Hero
## stands on the Store's Node it is run state, what has been bought there included, so a
## saved run comes back to the Store exactly as it was left.
##
## Each good rolls its kind on its own: a card 75%, a Potion 20% or an Armor 5%, with no cap
## on any kind. A card rolls its Rarity from the Tier's odds (RarityOdds) and is drawn from the
## Tier's Store Pool, falling back to the nearest lower Rarity the pool holds, or with none
## lower to the nearest higher; no card comes up twice in one Store, and a Power-9 card never
## does. Each card then rolls a Mod 15%, a Hex 10% or nothing 75%, and again after each Mod or
## Hex until a roll comes up nothing or its Mod Slots are full: a Mod is drawn with the Tier's
## odds from those that accept the card as it reads then, never a Unique one, and a Hex evenly
## from those that accept it. Potions are drawn with the Tier's odds, Armor evenly, and either
## may come up twice. A roll with nothing to draw counts as nothing, and a good that would be a
## Potion or an Armor when there are none is a card.

const GOODS: int = 9
## Out of a hundred: below CARD_CHANCE a good is a card, then below POTION_CHANCE a Potion,
## and otherwise an Armor.
const CARD_CHANCE: int = 75
const POTION_CHANCE: int = 95
## Out of a hundred: below MOD_CHANCE a card's roll is a Mod, then below HEX_CHANCE a Hex,
## and otherwise nothing.
const MOD_CHANCE: int = 15
const HEX_CHANCE: int = 25

var _goods: Array[StoreGood] = []


## The stock a Store of [param tier] rolls from Content: the Tier's Store Pool, every Potion
## and Armor, and every Mod and Hex, drawn from [param random].
static func of_content(tier: int, random: RunRandom) -> StoreStock:
	return roll(tier, random, ContentStorePools.pool(tier), ContentPotions.all(), ContentArmor.all(), ContentMods.all())


## The stock of a Store of [param tier] drawn from [param random]: its cards from [param pool],
## its Potions from [param potions], its Armor from [param armor], and the Mods and Hexes its
## cards carry from [param mods], which holds both.
static func roll(tier: int, random: RunRandom, pool: Array[MmCardDefinition], potions: Array[MmCardDefinition],
		armor: Array[Armor], mods: Array[Mod]) -> StoreStock:
	var stock: StoreStock = StoreStock.new()
	var cards: Array[MmCardDefinition] = pool.filter(func(definition: MmCardDefinition) -> bool:
		return definition.rarity != MmCardDefinition.Rarity.POWER_NINE)
	for index: int in GOODS:
		var chance: int = random.pick(RunRandom.STORE_STOCK, 100)
		var good: StoreGood = null
		if chance >= CARD_CHANCE and chance < POTION_CHANCE and not potions.is_empty():
			good = StoreGood.of_potion(_by_rarity(potions, tier, random) as MmCardDefinition)
		elif chance >= POTION_CHANCE and not armor.is_empty():
			good = StoreGood.of_armor(armor[random.pick(RunRandom.STORE_STOCK, armor.size())])
		else:
			var drawn: MmCardDefinition = _by_rarity(cards, tier, random) as MmCardDefinition
			if drawn == null:
				continue
			# ADR 0071: no card appears twice in one Store.
			cards = cards.filter(func(definition: MmCardDefinition) -> bool: return definition != drawn)
			good = StoreGood.of_card(drawn)
			_roll_mods(good.card, tier, random, mods)
		stock._goods.append(good)
	return stock


## Every good, in the order rolled, Sold ones included.
func goods() -> Array[StoreGood]:
	return _goods.duplicate()


func has(good: StoreGood) -> bool:
	return _goods.has(good)


## The stock as plain data, for a saved run (ADR 0074): each good in the order rolled.
func to_data() -> Dictionary:
	var saved: Array = []
	for good: StoreGood in _goods:
		saved.append(good.to_data())
	return {"goods": saved}


## The stock [param data] holds, as to_data() made it.
static func from_data(data: Dictionary) -> StoreStock:
	var stock: StoreStock = StoreStock.new()
	for good: Dictionary in data["goods"]:
		stock._goods.append(StoreGood.from_data(good))
	return stock


## Rolls the Mods and Hexes [param card] carries, one at a time until a roll comes up nothing
## or its Mod Slots are full.
static func _roll_mods(card: DeckbuilderCard, tier: int, random: RunRandom, mods: Array[Mod]) -> void:
	while card.has_empty_mod_slot():
		var chance: int = random.pick(RunRandom.STORE_STOCK, 100)
		if chance >= HEX_CHANCE:
			return
		var is_hex: bool = chance >= MOD_CHANCE
		var fitting: Array[Mod] = mods.filter(func(mod: Mod) -> bool:
			return mod.is_hex == is_hex and mod.rarity != Mod.Rarity.UNIQUE and mod.is_applicable_to(card))
		if fitting.is_empty():
			return
		var drawn: Mod = fitting[random.pick(RunRandom.STORE_STOCK, fitting.size())] if is_hex \
				else _by_rarity(fitting, tier, random) as Mod
		card.attach(drawn)


## One of [param things], Card Definitions or Mods, drawn at [param tier]'s Rarity odds: its
## Rarity rolled, then one of that Rarity, or of the nearest Rarity held, drawn evenly. Null
## when there is nothing to draw.
static func _by_rarity(things: Array, tier: int, random: RunRandom) -> Resource:
	if things.is_empty():
		return null
	var held: Array[int] = []
	for thing: Resource in things:
		if not held.has(_rarity_of(thing)):
			held.append(_rarity_of(thing))
	var rarity: int = RarityOdds.nearest(RarityOdds.roll(tier, random, RunRandom.STORE_STOCK), held)
	var of_rarity: Array = things.filter(func(thing: Resource) -> bool: return _rarity_of(thing) == rarity)
	return of_rarity[random.pick(RunRandom.STORE_STOCK, of_rarity.size())] as Resource


static func _rarity_of(thing: Resource) -> int:
	return (thing as Mod).rarity if thing is Mod else (thing as MmCardDefinition).rarity
