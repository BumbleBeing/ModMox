class_name SourceSelection
extends MmSelection
## "This": the spell's own object, or the permanent or Emblem an ability came from. Selects
## nothing once that object no longer exists.


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	if state.object(context.source_object_id) == null:
		return []
	return [MmReference.to_object(context.source_object_id)]
