class_name ControlledByFilter
extends MmFilter
## Matches a Game Object controlled by [member whose], relative to the controller of the
## spell or ability: "you control" or "an opponent controls".

@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and MmTrigger.is_whose(whose, game_object.controller_id, context)
