class_name PowerValue
extends MmValue
## "Its power": the power of the first object [member selection] finds, from its last-known
## information if it has left the battlefield (CR 608.2h). 0 if it finds none.

@export var selection: MmSelection


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	for found: MmReference in selection.select(state, context):
		var game_object: MmGameObject = state.object_or_last_known(found.id) if found.is_object() else null
		if game_object != null:
			return state.characteristics_of(game_object).power
	return 0
