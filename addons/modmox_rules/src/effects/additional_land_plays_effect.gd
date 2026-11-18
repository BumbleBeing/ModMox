class_name AdditionalLandPlaysEffect
extends MmEffect
## "[players] may play [count] additional lands this turn" (CR 305.2, 505.6b): more land
## plays for the rest of this turn, beside any from AdditionalLandPlaysAbility.

@export var count: MmValue
@export var players: MmSelection


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [count.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out[0] <= 0:  # CR 107.1b: a negative amount is treated as 0.
		return events
	for player: MmReference in players.select(state, context):
		if player.is_player():
			events.append(LandPlaysGrantedEvent.new(player.id, worked_out[0]))
	return events


func selections() -> Array[MmSelection]:
	return [players]
