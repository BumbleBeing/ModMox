class_name IsPlayerFilter
extends MmFilter
## Matches any player.


func matches(_state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	return candidate.is_player()
