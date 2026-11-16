class_name DeckbuilderSample
extends RefCounted
## A made-up run for looking at the deckbuilder on its own (--deckbuilder) and for its
## tests: three copies of every Content card in every set's folder, a few made-up Mods
## that each add a mana symbol, cards that arrive Hexed or full, and one saved Deck, the
## Active one. A Mod's name is the word it puts in front of the card's (A559). None of
## these Mods fits a land, so no basic land can be modified here (A560). Nothing is saved
## to disk.

const CARDS: String = "res://content/cards/"
const COPIES: int = 3
const DECK_NAME: String = "Red-Green Stompy"
## The sample Deck: how many copies of each card, and of each basic land.
const DECK_CARDS: Dictionary[String, int] = {
	"Lightning Bolt": 3, "Llanowar Elves": 3, "Grizzly Bears": 3, "Giant Growth": 2, "Elvish Archers": 2,
	"Uthden Troll": 2, "Hurloon Minotaur": 2, "Hill Giant": 2, "Giant Spider": 2, "Shivan Dragon": 1,
	"Craw Wurm": 1,
}
const DECK_LANDS: Dictionary[String, int] = {"Forest": 9, "Mountain": 8}

var _run: Run = Run.new(1)


static func make() -> Run:
	var sample: DeckbuilderSample = DeckbuilderSample.new()
	sample._own_every_card()
	sample._hold_mods()
	sample._save_deck()
	return sample._run


func _own_every_card() -> void:
	for path: String in _card_files(CARDS):
		var definition: MmCardDefinition = load(path) as MmCardDefinition
		if definition.supertypes.has(MmCardTypes.Supertype.BASIC):
			continue
		for copy: int in COPIES:
			var run_card: MmRunCard = MmRunCard.new()
			run_card.base = definition
			_run.collection.add(run_card, _arrives_with(definition.name, copy))


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
			mods.append(_add_symbol("Moss", MmMana.Type.GREEN))
			mods.append(_add_symbol("Burden", MmMana.Type.COLORLESS, true))
		"Grizzly Bears":
			mods.append(_add_symbol("Ember", MmMana.Type.RED))
	return mods


func _hold_mods() -> void:
	var ember: Mod = _add_symbol("Ember", MmMana.Type.RED)
	var moss: Mod = _add_symbol("Moss", MmMana.Type.GREEN)
	var tide: Mod = _add_symbol("Tide", MmMana.Type.BLUE)
	for mod: Mod in [ember, ember, moss, tide]:
		_run.held_mods.add(mod)


func _save_deck() -> void:
	var working: WorkingDeck = WorkingDeck.new(_run.collection, _run.deckbox, _run.basic_lands)
	working.name = DECK_NAME
	var wanted: Dictionary[String, int] = DECK_CARDS.duplicate()
	for card: DeckbuilderCard in _run.collection.cards():
		var base_name: String = card.run_card.base.name
		if wanted.get(base_name, 0) > 0:
			wanted[base_name] -= 1
			working.add_to_own_column(card)
	for land: String in DECK_LANDS:
		for index: int in DECK_LANDS[land]:
			working.add_basic_land(land)
	working.save()
	_run.deckbox.set_active(_run.deckbox.decks()[0])


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


## Every Card Definition under [param folder], a set's folder at a time, each in name order.
static func _card_files(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var sets: PackedStringArray = DirAccess.get_directories_at(folder)
	sets.sort()
	for card_set: String in sets:
		found.append_array(_card_files(folder + card_set + "/"))
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			found.append(folder + file)
	return found
