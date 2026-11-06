class_name ControllerOfSelection
extends MmSelection
## "Its controller": the controller of each object [member selection] finds, each player
## once, using last-known information for an object that has left the battlefield.

@export var selection: MmSelection


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var result: Array[MmReference] = []
	for found: MmReference in selection.select(state, context):
		var controller_id: int = found.id if found.is_player() else MmGameState.NO_PLAYER
		if found.is_object():
			var game_object: MmGameObject = state.object_or_last_known(found.id)
			if game_object != null:
				controller_id = game_object.controller_id
		var already: bool = false
		for each: MmReference in result:
			already = already or each.id == controller_id
		if controller_id != MmGameState.NO_PLAYER and not already:
			result.append(MmReference.to_player(controller_id))
	return result


func is_targeted() -> bool:
	return selection.is_targeted()
