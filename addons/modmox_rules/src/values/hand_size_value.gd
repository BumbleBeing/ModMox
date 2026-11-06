class_name HandSizeValue
extends MmValue
## "The number of cards in [players]'s hand", added up over every player selected.

@export var players: MmSelection


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	var total: int = 0
	for found: MmReference in players.select(state, context):
		if found.is_player():
			total += state.player(found.id).hand.size()
	return total
