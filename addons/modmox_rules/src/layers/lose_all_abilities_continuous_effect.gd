class_name LoseAllAbilitiesContinuousEffect
extends MmContinuousEffect
## "[affected] lose(s) all abilities" (layer 6, CR 613.1f).


func layer() -> Layer:
	return Layer.ABILITY


func apply_to(characteristics: MmCharacteristics, _amounts: Array[int]) -> void:
	characteristics.abilities.clear()
