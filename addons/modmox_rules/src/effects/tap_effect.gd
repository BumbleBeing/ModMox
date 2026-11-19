class_name TapEffect
extends MmEffect
## "Tap [selection]" (CR 701.26a): each selected permanent becomes tapped, all at once. Only
## an untapped permanent can be tapped, so one already tapped is left as it is.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent == null or permanent.zone() != state.battlefield or permanent.is_tapped:
			continue
		events.append(TapEvent.new(permanent.id))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
