class_name SelectionMatchesCondition
extends MmCondition
## "If [selection] is [filter]": true when the Selection finds something and everything it
## finds matches the Filter, as in "if Howling Mine is untapped".

@export var selection: MmSelection
@export var filter: MmFilter


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	var selected: Array[MmReference] = selection.select(state, context)
	if selected.is_empty():
		return false
	for candidate: MmReference in selected:
		if not filter.matches(state, candidate, context):
			return false
	return true
