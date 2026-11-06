class_name AllOfFilter
extends MmFilter
## Matches when every one of [member filters] matches ("and"). Matches everything when empty.

@export var filters: Array[MmFilter] = []


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	for filter: MmFilter in filters:
		if not filter.matches(state, candidate, context):
			return false
	return true
