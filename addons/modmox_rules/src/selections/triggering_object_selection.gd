class_name TriggeringObjectSelection
extends MmSelection
## "That creature", "that land", "that spell": the object a triggered ability's event was
## about. If it has since left the battlefield, its last-known information still answers
## questions about it (CR 608.2h), but effects that change objects find nothing to change.


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	if context.triggering_object_id == 0 or state.object_or_last_known(context.triggering_object_id) == null:
		return []
	return [MmReference.to_object(context.triggering_object_id)]
