class_name EachSelection
extends MmSelection
## Each player and permanent matching [member filter] when the effect resolves. Does not
## target, so it ignores hexproof and never makes a spell fail to resolve.

@export var filter: MmFilter


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var result: Array[MmReference] = []
	for candidate: MmReference in TargetSpec.candidates(state):
		if filter.matches(state, candidate, context):
			result.append(candidate)
	return result
