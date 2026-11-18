class_name IsAttackingFilter
extends MmFilter
## Matches an attacking creature (CR 506.4): one declared as an attacker this combat and not
## removed from combat since. Nothing attacks outside combat.


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	return candidate.is_object() and state.combat.is_attacking(candidate.id)
