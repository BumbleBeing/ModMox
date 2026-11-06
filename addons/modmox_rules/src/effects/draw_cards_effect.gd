class_name DrawCardsEffect
extends MmEffect
## "[players] draw [amount] cards" (CR 121).

@export var amount: MmValue
@export var players: MmSelection


func resolve(state: MmGameState, context: MmEffectContext) -> void:
	var count: int = amount.evaluate(state, context)
	for drawer: MmReference in players.select(state, context):
		if drawer.is_player():
			state.draw_cards(drawer.id, count)


func selections() -> Array[MmSelection]:
	return [players]
