class_name TargetsFilter
extends MmFilter
## A spell or ability on the stack that targets [filter] (CR 115.1, 601.2c), as Heroic's
## "whenever you cast a spell that targets this creature" names the spell. The inner filter
## is asked in the same context, so IsSourceFilter there is "this creature".

## What one of its chosen targets must be.
@export var filter: MmFilter = null


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var stacked: MmGameObject = state.object(candidate.id)
	if stacked == null:
		return false
	for target: MmReference in stacked.targets:
		# An entry is null until its target is chosen.
		if target != null and filter.matches(state, target, context):
			return true
	return false
