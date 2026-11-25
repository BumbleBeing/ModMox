class_name PutCountersEffect
extends MmEffect
## "Put [amount] [kind] counters on [recipients]" (CR 122.6): each selected permanent gets
## them, all at once. Something that is not on the battlefield gets none.

@export var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
@export var amount: MmValue
@export var recipients: MmSelection


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out[0] <= 0:  # CR 107.1b: a negative amount is treated as 0.
		return events
	for found: MmReference in recipients.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent != null and permanent.zone() == state.battlefield:
			events.append(CountersPutEvent.new(permanent.id, kind, worked_out[0], context.controller_id))
	return events


func selections() -> Array[MmSelection]:
	return [recipients]
