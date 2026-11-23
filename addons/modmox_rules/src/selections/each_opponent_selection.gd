class_name EachOpponentSelection
extends MmSelection
## "Each opponent": every player other than the controller of the spell or ability, in
## turn order (ADR 0005).


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var opponents: Array[MmReference] = []
	for player: MmPlayer in state.turn_order():
		if player.id != context.controller_id:
			opponents.append(MmReference.to_player(player.id))
	return opponents
