class_name TriggeringPlayerSelection
extends MmSelection
## "That player": the player a triggered ability's event was about, such as the player
## whose draw step began or who cast the spell.


func select(_state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	if context.triggering_player_id == MmGameState.NO_PLAYER:
		return []
	return [MmReference.to_player(context.triggering_player_id)]
