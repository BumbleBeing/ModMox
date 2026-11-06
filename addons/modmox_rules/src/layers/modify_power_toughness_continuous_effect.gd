class_name ModifyPowerToughnessContinuousEffect
extends MmContinuousEffect
## "[affected] get(s) +[power]/+[toughness]" (layer 7c, CR 613.4c).

@export var power: MmValue
@export var toughness: MmValue


func layer() -> Layer:
	return Layer.MODIFYING_POWER_TOUGHNESS


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	return [power.evaluate(state, context), toughness.evaluate(state, context)]


func apply_to(characteristics: MmCharacteristics, amounts: Array[int]) -> void:
	characteristics.power += amounts[0]
	characteristics.toughness += amounts[1]
