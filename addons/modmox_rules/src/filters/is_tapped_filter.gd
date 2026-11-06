class_name IsTappedFilter
extends MmFilter
## Matches a tapped permanent. Wrap it in a NotFilter for "untapped".


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and game_object.is_tapped
