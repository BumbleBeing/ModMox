class_name GainAbilitiesContinuousEffect
extends MmContinuousEffect
## "[affected] gain(s) [abilities]" (layer 6, CR 613.1f).

@export var abilities: Array[MmAbility] = []


func layer() -> Layer:
	return Layer.ABILITY


func apply_to(characteristics: MmCharacteristics, _amounts: Array[int]) -> void:
	characteristics.abilities.append_array(abilities)
