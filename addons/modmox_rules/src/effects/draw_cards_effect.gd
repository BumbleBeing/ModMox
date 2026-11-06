class_name DrawCardsEffect
extends MmEffect
## "[players] draw [amount] cards" (CR 121). Each draw is its own step, one card at a time
## from the top (CR 121.2), each player in turn drawing all of theirs.

@export var amount: MmValue
@export var players: MmSelection


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var count: int = worked_out[0]
	var drawers: Array[int] = []
	for drawer: MmReference in players.select(state, context):
		if drawer.is_player():
			drawers.append(drawer.id)
	if count <= 0 or step >= drawers.size() * count:
		return []
	return [state.draw_event(drawers[step / count])]


func selections() -> Array[MmSelection]:
	return [players]
