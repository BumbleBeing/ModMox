class_name DeckbuilderSample
extends RefCounted
## A made-up run for looking at the deckbuilder on its own (--deckbuilder) and for its
## tests: three copies of every Content card in every set's folder, a few made-up Mods
## that each give a nonland card cycling for one mana symbol and cost that symbol more, a
## Hex that takes -1/-1 from a creature, cards that arrive Hexed or full, and one saved Deck,
## the Active one. A Mod's name is the word it puts in front of the card's (A559). None of
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
## The card types the sample's Mods accept: every one but Land.
const NONLAND_TYPES: Array[MmCardTypes.CardType] = [
	MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE, MmCardTypes.CardType.ENCHANTMENT,
	MmCardTypes.CardType.INSTANT, MmCardTypes.CardType.SORCERY,
]

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
			mods.append(burden())
		"Lightning Bolt":
			mods.append(cycling_mod("Ember", MmMana.Type.RED))
			mods.append(cycling_mod("Moss", MmMana.Type.GREEN))
			mods.append(cycling_mod("Tide", MmMana.Type.BLUE))
		"Grizzly Bears":
			mods.append(cycling_mod("Ember", MmMana.Type.RED))
	return mods


func _hold_mods() -> void:
	var ember: Mod = cycling_mod("Ember", MmMana.Type.RED)
	var moss: Mod = cycling_mod("Moss", MmMana.Type.GREEN)
	var tide: Mod = cycling_mod("Tide", MmMana.Type.BLUE)
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


## A Mod named [param mod_name] for any nonland card: "Modified card gains cycling
## {[param symbol]}. It costs {[param symbol]} more to cast."
static func cycling_mod(mod_name: String, symbol: MmMana.Type) -> Mod:
	var cycling: CyclingAbility = CyclingAbility.new()
	cycling.mana_cost = _cost(0, [symbol])
	var gains: AddAbilityModification = AddAbilityModification.new()
	gains.ability = cycling
	var mod: Mod = Mod.new()
	mod.name = mod_name
	mod.augmentation = [gains] as Array[MmModification]
	mod.mod_cost = AddManaCostModification.new()
	mod.mod_cost.cost = _cost(0, [symbol])
	mod.card_types = NONLAND_TYPES.duplicate()
	return mod


## The sample's Hex: "Modified card gets -1/-1. It costs {1} more to cast."
static func burden() -> Mod:
	var weaker: AddPowerToughnessModification = AddPowerToughnessModification.new()
	weaker.power = -1
	weaker.toughness = -1
	var mod: Mod = Mod.new()
	mod.name = "Burden"
	mod.is_hex = true
	mod.augmentation = [weaker] as Array[MmModification]
	mod.mod_cost = AddManaCostModification.new()
	mod.mod_cost.cost = _cost(1, [])
	mod.card_types = [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType]
	return mod


static func _cost(generic: int, symbols: Array[MmMana.Type]) -> MmManaCost:
	var cost: MmManaCost = MmManaCost.new()
	cost.generic = generic
	cost.symbols = symbols
	return cost


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
