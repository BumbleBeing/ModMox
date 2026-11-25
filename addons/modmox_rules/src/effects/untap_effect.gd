class_name UntapEffect
extends MmEffect
## "Untap [selection]" (CR 701.26b): each selected permanent becomes untapped, all at once.
## Only a tapped permanent can be untapped, so one already untapped is left as it is. The
## counterpart of TapEffect.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent == null or permanent.zone() != state.battlefield or not permanent.is_tapped:
			continue
		events.append(UntapEvent.new(permanent.id))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
