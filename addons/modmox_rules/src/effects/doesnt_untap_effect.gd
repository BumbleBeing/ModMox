class_name DoesntUntapEffect
extends MmEffect
## "[selection] doesn't untap during its controller's next untap step" (CR 502.3), as Niblis
## of Frost's "tap target creature an opponent controls. That creature doesn't untap during
## its controller's next untap step.": each selected permanent is marked, all at once, and the
## next untap step of whoever controls it then leaves it tapped and ends the mark, whether or
## not it was tapped (MmGameObject.skips_next_untap). The other player's untap step leaves it.
## Unlike exert (CR 701.43), it follows the permanent's controller, not a player named as it
## happens. A zone change leaves it behind with the old object (ADR 0008).

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent == null or permanent.zone() != state.battlefield:
			continue
		events.append(NextUntapSkippedEvent.new(permanent.id))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
