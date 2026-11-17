class_name HasCountersFilter
extends MmFilter
## Matches a permanent with at least [member at_least] counters of [member kind] on it
## (CR 122), such as "with three or more +1/+1 counters on it". A card in any other zone
## has no counters (CR 122.2).

@export var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
@export var at_least: int = 1


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and game_object.counters_of(kind) >= at_least
