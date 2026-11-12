extends RefCounted
## Shared setup for the deckbuilder tests: a Collection of real Content cards, an empty
## Deckbox and a Working Deck over them. Preloaded, never class_name'd.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const BASIC_LANDS: Array[String] = ["plains", "island", "swamp", "mountain", "forest"]

var collection: Collection = Collection.new()
var deckbox: Deckbox = Deckbox.new()
var held_mods: HeldMods = HeldMods.new()


static func definition(card: String) -> MmCardDefinition:
	return load(ALPHA % card) as MmCardDefinition


static func basic_lands() -> Array[MmCardDefinition]:
	var result: Array[MmCardDefinition] = []
	for land: String in BASIC_LANDS:
		result.append(definition(land))
	return result


## Adds a fresh copy of [param card] to the Collection.
func own(card: String, mods: Array[Mod] = []) -> DeckbuilderCard:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = definition(card)
	return collection.add(run_card, mods)


func working_deck(deck: Deck = null) -> WorkingDeck:
	return WorkingDeck.new(collection, deckbox, basic_lands(), deck)


## A Mod that adds one mana symbol, which only a card with a mana cost accepts.
static func add_symbol_mod(symbol: MmMana.Type, is_hex: bool = false) -> Mod:
	var modification: AddManaSymbolModification = AddManaSymbolModification.new()
	modification.symbol = symbol
	var mod: Mod = Mod.new()
	mod.name = "Add {%s}" % MmMana.SYMBOLS[symbol]
	mod.is_hex = is_hex
	mod.modification = modification
	mod.needs_mana_cost = true
	return mod


## A Mod that renames the card, which any card accepts.
static func rename_mod(new_name: String) -> Mod:
	var modification: ChangeNameModification = ChangeNameModification.new()
	modification.new_name = new_name
	var mod: Mod = Mod.new()
	mod.name = "Rename"
	mod.modification = modification
	return mod


static func names(cards: Array[DeckbuilderCard]) -> Array[String]:
	var result: Array[String] = []
	for card: DeckbuilderCard in cards:
		result.append(card.look().name)
	return result
