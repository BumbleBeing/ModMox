extends RefCounted
## Shared setup for the deckbuilder tests: a Collection of real Content cards, an empty
## Deckbox and a Working Deck over them. Preloaded, never class_name'd.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const NoChange: GDScript = preload("res://tests/ui/deckbuilder/support/no_change_modification.gd")
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


## A Mod that adds one mana symbol, which only a card with a mana cost accepts. It has no
## name, so it puts no word in front of the card's.
static func add_symbol_mod(symbol: MmMana.Type, is_hex: bool = false) -> Mod:
	var mod: Mod = any_card_mod()
	mod.is_hex = is_hex
	mod.mod_cost = mana_cost(0, [symbol])
	mod.needs_mana_cost = true
	return mod


## A Mod that renames the card, which any card accepts. It has no name of its own.
static func rename_mod(new_name: String) -> Mod:
	var modification: ChangeNameModification = ChangeNameModification.new()
	modification.new_name = new_name
	var mod: Mod = any_card_mod()
	mod.augmentation = [modification] as Array[MmModification]
	return mod


## A Mod named [param word] that changes nothing but the card's name, which any card accepts.
static func word_mod(word: String, is_hex: bool = false) -> Mod:
	var mod: Mod = any_card_mod()
	mod.name = word
	mod.is_hex = is_hex
	mod.augmentation = [NoChange.new() as MmModification] as Array[MmModification]
	return mod


## A Mod with nothing in it that accepts a card of any card type.
static func any_card_mod() -> Mod:
	var mod: Mod = Mod.new()
	for card_type: MmCardTypes.CardType in MmCardTypes.CardType.values():
		mod.card_types.append(card_type)
	return mod


## A Mod Cost of [param generic] generic mana and [param symbols].
static func mana_cost(generic: int, symbols: Array[MmMana.Type] = []) -> AddManaCostModification:
	var modification: AddManaCostModification = AddManaCostModification.new()
	modification.cost = MmManaCost.new()
	modification.cost.generic = generic
	modification.cost.symbols = symbols
	return modification


## Violent, the example Mod: a creature gets +1/+1 and gains trample, and costs {1} more.
static func violent() -> Mod:
	var plus_one: AddPowerToughnessModification = AddPowerToughnessModification.new()
	plus_one.power = 1
	plus_one.toughness = 1
	var trample: AddAbilityModification = AddAbilityModification.new()
	trample.ability = TrampleAbility.new()
	var mod: Mod = Mod.new()
	mod.name = "Violent"
	mod.augmentation = [plus_one, trample] as Array[MmModification]
	mod.mod_cost = mana_cost(1)
	mod.card_types = [MmCardTypes.CardType.CREATURE] as Array[MmCardTypes.CardType]
	return mod


static func names(cards: Array[DeckbuilderCard]) -> Array[String]:
	var result: Array[String] = []
	for card: DeckbuilderCard in cards:
		result.append(DeckbuilderLooks.look_of(card).name)
	return result


## Scrolls the Collection pane of [param screen] until [param card]'s face is in view, as a
## player would before pointing at it, and returns that face. The sample owns every Content
## card, so where a card falls in the pane moves as Content grows.
static func scroll_to(screen: DeckbuilderScreen, card: DeckbuilderCard) -> CardFace:
	var face: CardFace = screen.collection_face(card)
	var scroll: ScrollContainer = screen.collection_scroll()
	scroll.ensure_control_visible(face)
	# The scroll moves its grid on the next sort; sort now, so the face is where it shows.
	scroll.notification(Container.NOTIFICATION_SORT_CHILDREN)
	return face
