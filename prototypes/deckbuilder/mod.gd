class_name Mod
extends Resource
## An item the Hero holds and can apply to a card in their Collection (ADR 0029). It wraps
## the engine Modification it leaves on the Run Card and decides which cards accept it. A
## Hex is a Mod the Hero never holds: it arrives already on a card.

@export var name: String = ""
@export var description: String = ""
@export var is_hex: bool = false
@export var modification: MmModification = null
## Its rule for which cards accept it: only a card that has a mana cost.
@export var needs_mana_cost: bool = false


## Whether this Mod's own rule accepts a card that reads as [param definition] does now.
func accepts(definition: MmCardDefinition) -> bool:
	return not needs_mana_cost or definition.mana_cost != null


## Applicable means the card has an empty Mod Slot and this Mod's rule accepts it. The same
## rule holds for every card, a basic land included.
func is_applicable_to(card: DeckbuilderCard) -> bool:
	return card.has_empty_mod_slot() and accepts(card.run_card.flatten())
