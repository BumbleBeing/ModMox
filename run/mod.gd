class_name Mod
extends Resource
## An Item the Hero holds and can apply to a card in their Collection (ADR 0029). It wraps
## the engine Modifications it leaves on the Run Card: its Augmentation, what it does to the
## card, then its Mod Cost, what it adds to the card's mana cost. It decides which cards
## accept it. A Hex is a Mod the Hero never holds: it arrives already on a card.

## How scarce a Mod is. A card's Rarity is the engine's and ends in Power-9; a Mod's ends in
## Unique, which is won only from a Unique Villain or a rare Chaos Node event.
enum Rarity { COMMON = 0, UNCOMMON = 1, RARE = 2, MYTHIC = 3, UNIQUE = 4 }

@export var name: String = ""
@export var is_hex: bool = false
@export var rarity: Rarity = Rarity.COMMON
## What the Mod does to the card, such as "+1/+1" and trample: one or more Modifications.
@export var augmentation: Array[MmModification] = []
## What the Mod adds to the card's mana cost, or null for none, as for a Mod that accepts
## lands. Later: additional costs, once the engine casts with them.
@export var mod_cost: AddManaCostModification = null
## The card types a card must have one of, as it reads now, for the Mod to accept it.
@export var card_types: Array[MmCardTypes.CardType] = []
## A rule of the Mod's own as well: only a card that has a mana cost.
@export var needs_mana_cost: bool = false
## Whether a card may hold this Mod only once. Every Unique Mod is.
@export var is_once_per_card: bool = false


## The Modifications applying it leaves on the Run Card, in the order they apply: the
## Augmentation's, then the Mod Cost.
func modifications() -> Array[MmModification]:
	var result: Array[MmModification] = augmentation.duplicate()
	if mod_cost != null:
		result.append(mod_cost)
	return result


## Whether this Mod's own rules accept a card that reads as [param definition] does now: it
## has one of the Mod's card types, and a mana cost if the Mod needs one.
func accepts(definition: MmCardDefinition) -> bool:
	if not card_types.any(func(card_type: MmCardTypes.CardType) -> bool: return definition.card_types.has(card_type)):
		return false
	return not needs_mana_cost or definition.mana_cost != null


## Applicable means the card has an empty Mod Slot, this Mod's rules accept it as it reads
## now, after the Mods already on it, and it does not hold this Mod already if this Mod is
## once per card. The same rules hold for every card, a basic land included.
func is_applicable_to(card: DeckbuilderCard) -> bool:
	if not card.has_empty_mod_slot():
		return false
	if is_once_per_card and card.mods.has(self):
		return false
	return accepts(card.run_card.flatten())


## What is wrong with the Mod's shape, one reason to an entry, or nothing when it is a Mod
## the game can hand out.
func problems() -> Array[String]:
	var found: Array[String] = []
	if name == "":
		found.append("A Mod needs a name.")
	if augmentation.is_empty():
		found.append("A Mod needs an Augmentation.")
	if card_types.is_empty():
		found.append("A Mod needs at least one card type.")
	var accepts_lands: bool = card_types.has(MmCardTypes.CardType.LAND)
	if accepts_lands and card_types.size() > 1:
		found.append("A Mod that accepts lands accepts nothing else.")
	if accepts_lands and mod_cost != null:
		found.append("A Mod that accepts lands has no Mod Cost.")
	if not accepts_lands and not card_types.is_empty() and mod_cost == null:
		found.append("A Mod that does not accept lands needs a Mod Cost.")
	if rarity == Rarity.UNIQUE and not is_once_per_card:
		found.append("A Unique Mod is once per card.")
	if rarity == Rarity.UNIQUE and is_hex:
		found.append("No Hex is Unique.")
	return found
