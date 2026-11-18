class_name IsBlockingFilter
extends MmFilter
## Matches a blocking creature (CR 509.1g): one declared as a blocker this combat and not
## removed from combat since (CR 506.4). Nothing blocks outside combat.


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	return candidate.is_object() and state.combat.is_blocking(candidate.id)
