class_name DeckbuilderSample
extends RefCounted
## The made-up run the prototype opens on: three copies of every Content card, a few
## made-up Mods built from the two Modifications the engine has, cards that arrive Hexed
## or full, and one saved Deck. Nothing here is saved to disk.

const CARDS: String = "res://content/cards/alpha/"
const COPIES: int = 3
const DECK_NAME: String = "Red-Green Stompy"
## The sample Deck: how many copies of each card, and of each basic land.
const DECK_CARDS: Dictionary[String, int] = {
	"Lightning Bolt": 3, "Llanowar Elves": 3, "Grizzly Bears": 3, "Giant Growth": 2, "Elvish Archers": 2,
	"Uthden Troll": 2, "Hurloon Minotaur": 2, "Hill Giant": 2, "Giant Spider": 2, "Shivan Dragon": 1,
	"Craw Wurm": 1,
}
const DECK_LANDS: Dictionary[String, int] = {"Forest": 9, "Mountain": 8}

var collection: Collection = Collection.new()
var deckbox: Deckbox = Deckbox.new()
var held_mods: HeldMods = HeldMods.new()
var basic_lands: Array[MmCardDefinition] = []
var deck: Deck = null


static func make() -> DeckbuilderSample:
	var sample: DeckbuilderSample = DeckbuilderSample.new()
	sample._own_every_card()
	sample._hold_mods()
	sample._save_deck()
	return sample


func working_deck() -> WorkingDeck:
	return WorkingDeck.new(collection, deckbox, basic_lands, deck)


func _own_every_card() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(CARDS)
	files.sort()
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var definition: MmCardDefinition = load(CARDS + file) as MmCardDefinition
		if definition.supertypes.has(MmCardTypes.Supertype.BASIC):
			basic_lands.append(definition)
			continue
		for copy: int in COPIES:
			var run_card: MmRunCard = MmRunCard.new()
			run_card.base = definition
			collection.add(run_card, _arrives_with(definition.name, copy))


## The Mods a copy arrives already carrying, so the prototype has a Hexed card, a full one
## and a multicolor one to show.
func _arrives_with(card_name: String, copy: int) -> Array[Mod]:
	var mods: Array[Mod] = []
	if copy != 0:
		return mods
	match card_name:
		"Craw Wurm":
			mods.append(_add_symbol("Burden", MmMana.Type.COLORLESS, true))
		"Lightning Bolt":
			mods.append(_add_symbol("Ember", MmMana.Type.RED))
			mods.append(_rename("Ember Bolt"))
			mods.append(_add_symbol("Burden", MmMana.Type.COLORLESS, true))
		"Grizzly Bears":
			mods.append(_add_symbol("Ember", MmMana.Type.RED))
	return mods


func _hold_mods() -> void:
	var ember: Mod = _add_symbol("Ember", MmMana.Type.RED)
	var moss: Mod = _add_symbol("Moss", MmMana.Type.GREEN)
	var tide: Mod = _add_symbol("Tide", MmMana.Type.BLUE)
	var title: Mod = _rename("Mox-Touched")
	for mod: Mod in [ember, ember, moss, tide, title]:
		held_mods.add(mod)


func _save_deck() -> void:
	var working: WorkingDeck = WorkingDeck.new(collection, deckbox, basic_lands)
	working.name = DECK_NAME
	var wanted: Dictionary[String, int] = DECK_CARDS.duplicate()
	for card: DeckbuilderCard in collection.cards():
		var base_name: String = card.run_card.base.name
		if wanted.get(base_name, 0) > 0:
			wanted[base_name] -= 1
			working.add_to_own_column(card)
	for land: String in DECK_LANDS:
		for index: int in DECK_LANDS[land]:
			working.add_basic_land(land)
	working.save()
	deck = deckbox.decks()[0]


static func _add_symbol(mod_name: String, symbol: MmMana.Type, is_hex: bool = false) -> Mod:
	var modification: AddManaSymbolModification = AddManaSymbolModification.new()
	modification.symbol = symbol
	var mod: Mod = Mod.new()
	mod.name = mod_name
	mod.description = "This card costs {%s} more to cast." % MmMana.SYMBOLS[symbol]
	mod.is_hex = is_hex
	mod.modification = modification
	mod.needs_mana_cost = true
	return mod


static func _rename(new_name: String) -> Mod:
	var modification: ChangeNameModification = ChangeNameModification.new()
	modification.new_name = new_name
	var mod: Mod = Mod.new()
	mod.name = "New Name"
	mod.description = "This card is named %s." % new_name
	mod.modification = modification
	return mod
