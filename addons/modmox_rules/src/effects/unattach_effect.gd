class_name UnattachEffect
extends MmEffect
## "Unattach [selection]" (CR 701.3d): each selected permanent that is attached to
## something becomes attached to nothing, and stays on the battlefield.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent != null and permanent.zone() == state.battlefield and permanent.attached_to_object_id != 0:
			events.append(UnattachedEvent.new(permanent.id))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
