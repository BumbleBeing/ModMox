class_name GainLifeEffect
extends MmEffect
## "[players] gain [amount] life" (CR 119.3).

@export var amount: MmValue
@export var players: MmSelection


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out[0] <= 0:  # CR 107.1b: a negative amount is treated as 0.
		return events
	for gainer: MmReference in players.select(state, context):
		if gainer.is_player():
			events.append(LifeGainedEvent.new(gainer.id, worked_out[0]))
	return events


func selections() -> Array[MmSelection]:
	return [players]
