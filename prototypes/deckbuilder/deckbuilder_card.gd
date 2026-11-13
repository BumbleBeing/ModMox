class_name DeckbuilderCard
extends RefCounted
## One card as the deckbuilder handles it: a Run Card, the identity that lasts the run, and
## the Mods in its Mod Slots (ADR 0028). Every card is its own; nothing is stacked. Each
## Mod's name goes in front of the card's own, in slot order (A559).

## How many Mod Slots a card has, Hexes included. A basic land has them too (A558).
const MOD_SLOTS: int = 3
## Where a card sorts by color: white to green, then multicolor, then colorless.
const MULTICOLOR_RANK: int = 5
const COLORLESS_RANK: int = 6

var id: int = 0
var run_card: MmRunCard = null
## The Mods on the card, in the order earned. Each one's Modification is on the Run Card.
var mods: Array[Mod] = []

var _look: CardLook = null
var _original_look: CardLook = null


func _init(card_id: int, card: MmRunCard) -> void:
	id = card_id
	run_card = card


## The card as it reads now, with every Mod applied.
func look() -> CardLook:
	if _look == null:
		_look = CardLook.of_characteristics(MmCharacteristics.printed(run_card.flatten()), _art_key())
		_look.name = _modded_name(_look.name)
		_look.rules_text = AbilityText.of_card(_look.abilities, _look.card_types, _look.supertypes, _look.name)
	return _look


## The card as its Card Definition has it: no Mods and no Hexes.
func original_look() -> CardLook:
	if _original_look == null:
		_original_look = CardLook.of_characteristics(MmCharacteristics.printed(run_card.base), _art_key())
	return _original_look


## Whether it has a Mod or a Hex, and so differs from its Original.
func is_modified() -> bool:
	return not mods.is_empty()


func is_land() -> bool:
	return look().has_card_type(MmCardTypes.CardType.LAND)


func is_basic_land() -> bool:
	return is_land() and run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC)


func mana_value() -> int:
	return 0 if look().mana_cost == null else look().mana_cost.mana_value()


func color_rank() -> int:
	var colors: Array[MmCardTypes.CardColor] = look().colors
	if colors.is_empty():
		return COLORLESS_RANK
	return MULTICOLOR_RANK if colors.size() > 1 else colors[0] as int


func mod_slots() -> int:
	return MOD_SLOTS


func has_empty_mod_slot() -> bool:
	return mods.size() < mod_slots()


## Puts [param mod] in the next Mod Slot. Whether it may go there is the caller's question
## (Mod.is_applicable_to): a Hex arrives without being asked.
func attach(mod: Mod) -> void:
	mods.append(mod)
	run_card.modifications.append(mod.modification)
	_look = null


## A throwaway copy of this card as it would be with [param mod] in its next Mod Slot,
## for showing before it is applied. This card is not changed.
func with_mod(mod: Mod) -> DeckbuilderCard:
	var copy_card: MmRunCard = MmRunCard.new()
	copy_card.base = run_card.base
	copy_card.modifications = run_card.modifications.duplicate()
	var copy: DeckbuilderCard = DeckbuilderCard.new(id, copy_card)
	copy.mods = mods.duplicate()
	copy.attach(mod)
	return copy


func _art_key() -> String:
	return run_card.base.resource_path.get_file().get_basename()


## [param own_name] with the name of each Mod and Hex in front of it, in slot order. A Mod
## with no name adds no word.
func _modded_name(own_name: String) -> String:
	var words: PackedStringArray = []
	for mod: Mod in mods:
		if mod.name != "":
			words.append(mod.name)
	words.append(own_name)
	return " ".join(words)


## Whether this card comes before [param other] in a column: color, then name.
func sorts_before(other: DeckbuilderCard) -> bool:
	if color_rank() != other.color_rank():
		return color_rank() < other.color_rank()
	return comes_before_by_name(other)


func comes_before_by_name(other: DeckbuilderCard) -> bool:
	var order: int = look().name.naturalnocasecmp_to(other.look().name)
	return id < other.id if order == 0 else order < 0
