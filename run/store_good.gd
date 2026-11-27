class_name StoreGood
extends RefCounted
## One of the nine things a Store has for sale (milestone 24, ADR 0071): a card, with any Mods
## and Hexes it carries, a Potion or an Armor. Bought, it is Sold and leaves its place empty
## for the rest of the visit.

## What kind of good it is. Saved by name.
enum Kind { CARD, POTION, ARMOR }

var kind: Kind = Kind.CARD
## A card for sale, as it reads with its Mods and Hexes. It is no card of the Collection:
## buying it gives the Collection a Run Card of its own.
var card: DeckbuilderCard = null
var potion: MmCardDefinition = null
var armor: Armor = null
var is_sold: bool = false


static func of_card(definition: MmCardDefinition) -> StoreGood:
	var made: StoreGood = StoreGood.new()
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = definition
	made.card = DeckbuilderCard.new(0, run_card)
	return made


static func of_potion(definition: MmCardDefinition) -> StoreGood:
	var made: StoreGood = StoreGood.new()
	made.kind = Kind.POTION
	made.potion = definition
	return made


static func of_armor(definition: Armor) -> StoreGood:
	var made: StoreGood = StoreGood.new()
	made.kind = Kind.ARMOR
	made.armor = definition
	return made


## Its name: a card's Modded Name, as it reads.
func name() -> String:
	match kind:
		Kind.CARD:
			return card.card_name()
		Kind.POTION:
			return potion.name
	return armor.name


## What the Store asks for it (ADR 0070).
func price() -> int:
	match kind:
		Kind.CARD:
			return Prices.of_card(card)
		Kind.POTION:
			return Prices.of_potion(potion)
	return Prices.of_armor(armor)


## The good as plain data, for a saved run (ADR 0074): its kind, what it is by path, a card's
## Mods by path in the order they are on it, and whether it is Sold.
func to_data() -> Dictionary:
	var data: Dictionary = {"kind": Kind.keys()[kind], "is_sold": is_sold}
	match kind:
		Kind.CARD:
			data["base"] = SavedRun.path_of(card.run_card.base)
			data["mods"] = SavedRun.paths_of(card.mods)
		Kind.POTION:
			data["potion"] = SavedRun.path_of(potion)
		Kind.ARMOR:
			data["armor"] = SavedRun.path_of(armor)
	return data


## The good [param data] holds, as to_data() made it.
static func from_data(data: Dictionary) -> StoreGood:
	var made: StoreGood = null
	match Kind.get(str(data["kind"]), Kind.CARD) as Kind:
		Kind.CARD:
			made = of_card(load(str(data["base"])) as MmCardDefinition)
			for path: Variant in data["mods"]:
				made.card.attach(load(str(path)) as Mod)
		Kind.POTION:
			made = of_potion(load(str(data["potion"])) as MmCardDefinition)
		Kind.ARMOR:
			made = of_armor(load(str(data["armor"])) as Armor)
	made.is_sold = bool(data["is_sold"])
	return made
