class_name LoseLifeEffect
extends MmEffect
## "[players] lose [amount] life" (CR 119.3). Not damage, so nothing that prevents or
## reacts to damage applies to it.

@export var amount: MmValue
@export var players: MmSelection


func resolve(state: MmGameState, context: MmEffectContext) -> void:
	var life: int = amount.evaluate(state, context)
	if life <= 0:  # CR 107.1b: a negative amount is treated as 0.
		return
	for loser: MmReference in players.select(state, context):
		if loser.is_player():
			state.perform(LifeLostEvent.new(loser.id, life))


func selections() -> Array[MmSelection]:
	return [players]
