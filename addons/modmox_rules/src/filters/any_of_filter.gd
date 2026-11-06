class_name AnyOfFilter
extends MmFilter
## Matches when at least one of [member filters] matches ("or"). Matches nothing when empty.

@export var filters: Array[MmFilter] = []


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	for filter: MmFilter in filters:
		if filter.matches(state, candidate, context):
			return true
	return false
