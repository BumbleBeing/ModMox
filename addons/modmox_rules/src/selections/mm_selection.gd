class_name MmSelection
extends Resource
## Who or what an effect applies to (ADR 0014). Effects never hold targets themselves;
## they ask a Selection, so "target creature" and "each creature" differ only in which
## Selection the effect uses, and a Modification can swap one for the other.


## The players and Game Objects this effect applies to, at the moment it resolves.
func select(_state: MmGameState, _context: MmEffectContext) -> Array[MmReference]:
	assert(false, "%s must override select()." % get_script().resource_path)
	return []


## Whether this Selection uses a target (CR 115). Only TargetSelection does.
func is_targeted() -> bool:
	return false
