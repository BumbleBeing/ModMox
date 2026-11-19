class_name IsPermanentFilter
extends MmFilter
## Matches a permanent card (CR 110.4a): an artifact, creature, enchantment or land card,
## wherever it is, as in "if it was a permanent card". Never a player.


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and state.characteristics_of(game_object).is_permanent()
