class_name OwnedByFilter
extends MmFilter
## Matches a Game Object owned by [member whose], relative to the controller of the spell
## or ability: "in your graveyard" or "in an opponent's graveyard". A card that is not on
## the battlefield or the stack has an owner and no controller (CR 108.4).

@export var whose: MmTrigger.Whose = MmTrigger.Whose.YOU


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and MmTrigger.is_whose(whose, game_object.owner_id, context)
