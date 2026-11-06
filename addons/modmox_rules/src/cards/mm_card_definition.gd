class_name MmCardDefinition
extends Resource
## The base design of a card: its name, types and written abilities, and in later
## milestones its costs and other characteristics.
##
## Loaded definitions are shared by Godot's resource cache and must never be mutated at
## runtime (ADR 0004). Rules code never reads these fields directly; it asks
## MmGameState.characteristics_of() instead (ADR 0009).

@export var name: String = ""
@export var card_types: Array[MmCardTypes.CardType] = []
@export var supertypes: Array[MmCardTypes.Supertype] = []
@export var subtypes: Array[String] = []
## Only the abilities written on the card. Abilities granted by rules, such as a basic
## land's mana ability, are added by the characteristics query.
@export var abilities: Array[MmAbility] = []
