class_name GainLifeEffect
extends MmEffect
## "[players] gain [amount] life" (CR 119.3).

@export var amount: MmValue
@export var players: MmSelection


func resolve(state: MmGameState, context: MmEffectContext) -> void:
	var life: int = amount.evaluate(state, context)
	if life <= 0:  # CR 107.1b: a negative amount is treated as 0.
		return
	for gainer: MmReference in players.select(state, context):
		if gainer.is_player():
			state.perform(LifeGainedEvent.new(gainer.id, life))


func selections() -> Array[MmSelection]:
	return [players]
