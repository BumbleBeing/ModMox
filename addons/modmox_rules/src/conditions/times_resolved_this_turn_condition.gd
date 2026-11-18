class_name TimesResolvedThisTurnCondition
extends MmCondition
## "This is the [times]th time this ability has resolved this turn" (ADR 0056): true while
## the ability resolving is doing so for the [member times]th time this turn, counting
## itself. An ability counts for its own source object and its own place among that
## object's abilities, so one that leaves and returns starts again (ADR 0008). Off the
## stack, as when something triggers, nothing is resolving and it is false.

## Which time: 1 for the first, 2 for the second.
@export var times: int = 1


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	var resolving: MmGameObject = state.object(context.own_object_id) if context.own_object_id != 0 else null
	if resolving == null or resolving.ability == null:
		return false
	# ADR 0056: an ability is counted as it leaves the stack, so this one is not counted yet.
	return state.times_resolved_this_turn(resolving.source_object_id, resolving.source_ability_index) + 1 == times
