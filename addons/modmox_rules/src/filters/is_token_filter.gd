class_name IsTokenFilter
extends MmFilter
## Matches a token (CR 111.1). Wrap it in a NotFilter for "nontoken". A token that has
## left the battlefield is still a token, seen as the object it was.


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and game_object.is_token
