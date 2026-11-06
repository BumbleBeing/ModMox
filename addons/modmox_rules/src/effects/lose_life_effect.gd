class_name LoseLifeEffect
extends MmEffect
## "[players] lose [amount] life" (CR 119.3). Not damage, so nothing that prevents or
## reacts to damage applies to it.

@export var amount: MmValue
@export var players: MmSelection


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out[0] <= 0:  # CR 107.1b: a negative amount is treated as 0.
		return events
	for loser: MmReference in players.select(state, context):
		if loser.is_player():
			events.append(LifeLostEvent.new(loser.id, worked_out[0]))
	return events


func selections() -> Array[MmSelection]:
	return [players]
