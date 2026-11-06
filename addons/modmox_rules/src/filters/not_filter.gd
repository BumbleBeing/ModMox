class_name NotFilter
extends MmFilter
## Matches exactly when [member filter] does not.

@export var filter: MmFilter


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	return not filter.matches(state, candidate, context)
