class_name AttachedToSelection
extends MmSelection
## "Equipped creature": the permanent this ability's source is attached to (CR 301.5).
## Selects nothing while the source is attached to nothing, or to something that has left
## the battlefield.


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var source: MmGameObject = state.object(context.source_object_id)
	if source == null or source.attached_to_object_id == 0:
		return []
	var attached_to: MmGameObject = state.object(source.attached_to_object_id)
	if attached_to == null or attached_to.zone() != state.battlefield:
		return []
	return [MmReference.to_object(attached_to.id)]
