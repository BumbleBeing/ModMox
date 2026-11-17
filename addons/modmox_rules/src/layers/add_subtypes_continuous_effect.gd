class_name AddSubtypesContinuousEffect
extends MmContinuousEffect
## "[affected] is a [subtypes] in addition to its other types" (layer 4, CR 613.1d). It
## keeps every type it had (CR 205.1b), and a subtype it already has is not added again.

@export var subtypes: Array[String] = []


func layer() -> Layer:
	return Layer.TYPE


func apply_to(characteristics: MmCharacteristics, _amounts: Array[int]) -> void:
	for subtype: String in subtypes:
		if not characteristics.subtypes.has(subtype):
			characteristics.subtypes.append(subtype)
