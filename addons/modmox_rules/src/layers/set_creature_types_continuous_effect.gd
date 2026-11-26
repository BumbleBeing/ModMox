class_name SetCreatureTypesContinuousEffect
extends MmContinuousEffect
## "[affected] becomes a [creature types]" (layer 4, CR 613.1d), as Mild-Mannered
## Librarian's "This creature becomes a Werewolf". It sets the object's creature types, so
## the new ones replace every creature type it had, changeling's included (CR 205.1a), and
## it keeps its card types and every subtype that is not a creature type, such as
## Equipment. One that says "in addition to its other types" is an
## AddSubtypesContinuousEffect instead.

@export var creature_types: Array[String] = []


func layer() -> Layer:
	return Layer.TYPE


func apply_to(characteristics: MmCharacteristics, _amounts: Array[int]) -> void:
	var kept: Array[String] = []
	for subtype: String in characteristics.subtypes:
		if not CreatureTypes.is_creature_type(subtype):
			kept.append(subtype)
	for creature_type: String in creature_types:
		if not kept.has(creature_type):
			kept.append(creature_type)
	characteristics.subtypes = kept
	characteristics.is_every_creature_type = false
