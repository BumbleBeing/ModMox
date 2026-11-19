class_name AddPowerToughnessModification
extends MmModification
## Adds to the card's printed power and toughness, such as "+1/+1", or takes from them, such
## as "-1/-1". The card prints the result: it is not an effect, so no layer applies it.

@export var power: int = 0
@export var toughness: int = 0


func apply_to(definition: MmCardDefinition) -> void:
	definition.power += power
	definition.toughness += toughness
