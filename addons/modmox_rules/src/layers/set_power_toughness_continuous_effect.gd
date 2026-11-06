class_name SetPowerToughnessContinuousEffect
extends MmContinuousEffect
## "[affected] has base power and toughness [power]/[toughness]" (layer 7b, CR 613.4b).

@export var power: MmValue
@export var toughness: MmValue


func layer() -> Layer:
	return Layer.SETTING_POWER_TOUGHNESS


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	return [power.evaluate(state, context), toughness.evaluate(state, context)]


func apply_to(characteristics: MmCharacteristics, amounts: Array[int]) -> void:
	characteristics.power = amounts[0]
	characteristics.toughness = amounts[1]
