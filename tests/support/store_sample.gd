extends RefCounted
## Cards, Mods, Hexes and Potions made in code for milestone 24's tests of the Store: what a
## Store's stock is drawn from, each well shaped and each named for what it is, so a test
## can tell them apart. None of them can be saved, being made in code; a test of saving uses
## Content.

## A creature card of [param rarity] named [param card_name], with a mana cost of {1}.
static func card(card_name: String, rarity: MmCardDefinition.Rarity) -> MmCardDefinition:
	var made: MmCardDefinition = MmCardDefinition.new()
	made.name = card_name
	made.card_types = [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType]
	made.mana_cost = _cost(1)
	made.power = 2
	made.toughness = 2
	made.rarity = rarity
	return made


## [param count] creature cards of each Rarity from Common to Mythic, named after their
## Rarity and a number: "Rare 3".
static func pool(count: int) -> Array[MmCardDefinition]:
	var made: Array[MmCardDefinition] = []
	for rarity: MmCardDefinition.Rarity in [MmCardDefinition.Rarity.COMMON, MmCardDefinition.Rarity.UNCOMMON,
			MmCardDefinition.Rarity.RARE, MmCardDefinition.Rarity.MYTHIC]:
		for index: int in count:
			made.append(card("%s %d" % [Inspector.RARITY_NAMES[rarity], index + 1], rarity))
	return made


## A Mod of [param rarity] named [param mod_name] that accepts creatures: +1/+1 for {1}.
static func mod(mod_name: String, rarity: Mod.Rarity) -> Mod:
	var stronger: AddPowerToughnessModification = AddPowerToughnessModification.new()
	stronger.power = 1
	stronger.toughness = 1
	var made: Mod = Mod.new()
	made.name = mod_name
	made.rarity = rarity
	made.augmentation = [stronger] as Array[MmModification]
	made.mod_cost = AddManaCostModification.new()
	made.mod_cost.cost = _cost(1)
	made.card_types = [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType]
	if rarity == Mod.Rarity.UNIQUE:
		made.is_once_per_card = true
	return made


## A Hex named [param hex_name] that accepts creatures: -1/-1 for {1}.
static func hex(hex_name: String) -> Mod:
	var weaker: AddPowerToughnessModification = AddPowerToughnessModification.new()
	weaker.power = -1
	weaker.toughness = -1
	var made: Mod = Mod.new()
	made.name = hex_name
	made.is_hex = true
	made.augmentation = [weaker] as Array[MmModification]
	made.mod_cost = AddManaCostModification.new()
	made.mod_cost.cost = _cost(1)
	made.card_types = [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType]
	return made


## A Mod named [param mod_name] that accepts only lands, so no creature takes it.
static func land_mod(mod_name: String) -> Mod:
	var made: Mod = mod(mod_name, Mod.Rarity.COMMON)
	made.card_types = [MmCardTypes.CardType.LAND] as Array[MmCardTypes.CardType]
	made.mod_cost = null
	return made


## A Potion of [param rarity] named [param potion_name]. It does nothing: a Store only
## reads its name and Rarity.
static func potion(potion_name: String, rarity: MmCardDefinition.Rarity) -> MmCardDefinition:
	var made: MmCardDefinition = MmCardDefinition.new()
	made.name = potion_name
	made.rarity = rarity
	return made


## A Run Card of [param definition], as a card in the Collection would hold, with each of
## [param mods] attached in order.
static func held(definition: MmCardDefinition, mods: Array[Mod] = []) -> DeckbuilderCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = definition
	var made: DeckbuilderCard = DeckbuilderCard.new(0, run_card)
	for each: Mod in mods:
		made.attach(each)
	return made


static func _cost(generic: int) -> MmManaCost:
	var cost: MmManaCost = MmManaCost.new()
	cost.generic = generic
	return cost
