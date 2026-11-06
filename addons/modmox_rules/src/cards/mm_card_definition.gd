class_name MmCardDefinition
extends Resource
## The base design of a card: its name and, in later milestones, its costs, types,
## characteristics and abilities.
##
## Loaded definitions are shared by Godot's resource cache and must never be mutated at
## runtime (ADR 0004). Rules code never reads these fields directly; it asks
## MmGameState.characteristics_of() instead (ADR 0009).

@export var name: String = ""
