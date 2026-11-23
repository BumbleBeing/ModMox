class_name GainLifeEffect
extends MmEffect
## "[players] gain [amount] life" (CR 119.3). A player found more than once, as an
## overloaded "its controller" finds them once for each of their objects, gains the amount
## that many times over, as one life gain.

@export var amount: MmValue
@export var players: MmSelection


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out[0] <= 0:  # CR 107.1b: a negative amount is treated as 0.
		return events
	var gainer_ids: Array[int] = []
	var times: Dictionary[int, int] = {}
	for gainer: MmReference in players.select(state, context):
		if gainer.is_player():
			if not times.has(gainer.id):
				gainer_ids.append(gainer.id)
			times[gainer.id] = times.get(gainer.id, 0) + 1
	for gainer_id: int in gainer_ids:
		events.append(LifeGainedEvent.new(gainer_id, worked_out[0] * times[gainer_id]))
	return events


func selections() -> Array[MmSelection]:
	return [players]
