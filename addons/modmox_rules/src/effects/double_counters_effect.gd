class_name DoubleCountersEffect
extends MmEffect
## "Double the number of [kind] counters on [recipients]" (CR 701.10e): each selected
## permanent gets as many more counters of that kind as it already has, all at once. They
## are put on as any counters are (CR 122.6). A permanent with none gets none.

@export var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
@export var recipients: MmSelection


## Each selected permanent's ID followed by how many counters of [member kind] it has, as
## the effect begins (CR 608.2h).
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = []
	for found: MmReference in recipients.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent != null and permanent.zone() == state.battlefield:
			worked_out.append(permanent.id)
			worked_out.append(permanent.counters_of(kind))
	return worked_out


func next_batch(state: MmGameState, _context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for index: int in range(0, worked_out.size(), 2):
		var permanent: MmGameObject = state.object(worked_out[index])
		if permanent != null and permanent.zone() == state.battlefield and worked_out[index + 1] > 0:
			events.append(CountersPutEvent.new(permanent.id, kind, worked_out[index + 1]))
	return events


func selections() -> Array[MmSelection]:
	return [recipients]
