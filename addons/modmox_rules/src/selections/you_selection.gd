class_name YouSelection
extends MmSelection
## "You": the controller of the spell or ability.


func select(_state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	return [MmReference.to_player(context.controller_id)]
