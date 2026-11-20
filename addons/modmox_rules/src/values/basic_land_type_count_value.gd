class_name BasicLandTypeCountValue
extends MmValue
## "The number of basic land types among [selection]" (CR 205.3i), each of Plains, Island,
## Swamp, Mountain and Forest counted once, from the current characteristics, whether or not
## the land is basic. Over the lands you control it is Domain (CR 207.2c), as in Gaea's
## Might: a number from 0 to 5.

@export var selection: MmSelection


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	var found_types: Array[String] = []
	for found: MmReference in selection.select(state, context):
		var game_object: MmGameObject = state.object_or_last_known(found.id) if found.is_object() else null
		if game_object == null:
			continue
		for subtype: String in state.characteristics_of(game_object).subtypes:
			if MmCardTypes.BASIC_LAND_TYPES.has(subtype) and not found_types.has(subtype):
				found_types.append(subtype)
	return found_types.size()
