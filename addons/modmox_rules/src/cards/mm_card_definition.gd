class_name MmCardDefinition
extends Resource
## The base design of a card: its name, types, mana cost, power and toughness, and written
## abilities.
##
## Loaded definitions are shared by Godot's resource cache and must never be mutated at
## runtime (ADR 0004). Rules code never reads these fields directly; it asks
## MmGameState.characteristics_of() instead (ADR 0009).

@export var name: String = ""
@export var card_types: Array[MmCardTypes.CardType] = []
@export var supertypes: Array[MmCardTypes.Supertype] = []
@export var subtypes: Array[String] = []
## Null for a card with no mana cost, such as a land (CR 202.1b). That is different from a
## cost of {0}.
@export var mana_cost: MmManaCost = null
## Printed power and toughness (CR 208). Only meaningful while the object is a creature
## (CR 208.3), so a Modification that makes a noncreature card a creature fills these in.
## A "*" power or toughness is a characteristic-defining ability instead (CR 604.3).
@export var power: int = 0
@export var toughness: int = 0
## Only the abilities written on the card. Abilities granted by rules, such as a basic
## land's mana ability, are added by the characteristics query.
@export var abilities: Array[MmAbility] = []
