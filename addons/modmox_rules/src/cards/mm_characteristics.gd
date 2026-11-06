class_name MmCharacteristics
extends RefCounted
## A Game Object's current characteristics (CR 109.3), after every effect that applies.
## Produced only by MmGameState.characteristics_of() (ADR 0009). Treat it as read-only.

var name: String = ""
var card_types: Array[MmCardTypes.CardType] = []
var supertypes: Array[MmCardTypes.Supertype] = []
var subtypes: Array[String] = []
## Written abilities first, then abilities granted by rules, in a fixed order.
var abilities: Array[MmAbility] = []


func has_card_type(card_type: MmCardTypes.CardType) -> bool:
	return card_types.has(card_type)
