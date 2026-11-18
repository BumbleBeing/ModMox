class_name AttachEffect
extends MmEffect
## "Attach [attachment] to [to]" (CR 701.3): each selected permanent becomes attached to
## the one permanent [member to] finds, and stays on the battlefield. Nothing happens to
## one that may not be attached to it (CR 701.3a) or is attached to it already (CR 701.3b).

@export var attachment: MmSelection
@export var to: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	var found_to: Array[MmReference] = to.select(state, context)
	if found_to.size() != 1 or not found_to[0].is_object():
		return events
	var attached_to: MmGameObject = state.object(found_to[0].id)
	for found: MmReference in attachment.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent != null and permanent.attached_to_object_id != found_to[0].id \
				and AttachmentRules.can_be_attached(state, permanent, attached_to):
			events.append(AttachedEvent.new(permanent.id, attached_to.id))
	return events


func selections() -> Array[MmSelection]:
	return [attachment, to]
