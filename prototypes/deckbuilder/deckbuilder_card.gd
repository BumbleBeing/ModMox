class_name DeckbuilderCard
extends RefCounted
## One card as the deckbuilder handles it: a Run Card, the identity that lasts the run, and
## the Mods in its Mod Slots (ADR 0028). Every card is its own; nothing is stacked.

## How many Mod Slots a card has, Hexes included. A basic land has none.
const MOD_SLOTS: int = 3
## Where a card sorts by color: white to green, then multicolor, then colorless.
const MULTICOLOR_RANK: int = 5
const COLORLESS_RANK: int = 6

var id: int = 0
var run_card: MmRunCard = null
## The Mods on the card, in the order earned. Each one's Modification is on the Run Card.
var mods: Array[Mod] = []

var _look: CardLook = null


func _init(card_id: int, card: MmRunCard) -> void:
	id = card_id
	run_card = card


## The card as it reads now, with every Mod applied.
func look() -> CardLook:
	if _look == null:
		_look = CardLook.of_characteristics(
				MmCharacteristics.printed(run_card.flatten()),
				run_card.base.resource_path.get_file().get_basename())
	return _look


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
	return 0 if is_basic_land() else MOD_SLOTS


func has_empty_mod_slot() -> bool:
	return mods.size() < mod_slots()


## Puts [param mod] in the next Mod Slot. Whether it may go there is the caller's question
## (Mod.is_applicable_to): a Hex arrives without being asked.
func attach(mod: Mod) -> void:
	mods.append(mod)
	run_card.modifications.append(mod.modification)
	_look = null


## Whether this card comes before [param other] in a column: color, then name.
func sorts_before(other: DeckbuilderCard) -> bool:
	if color_rank() != other.color_rank():
		return color_rank() < other.color_rank()
	return comes_before_by_name(other)


func comes_before_by_name(other: DeckbuilderCard) -> bool:
	var order: int = look().name.naturalnocasecmp_to(other.look().name)
	return id < other.id if order == 0 else order < 0
