class_name HexproofRules
extends RefCounted
## Whether a permanent has hexproof against a player (CR 702.11). Asked here, not by
## HexproofAbility, which may not use its own class as a value (conventions, "The run ends
## clean").


## Whether [param permanent] can't be the target of a spell or ability [param controller_id]
## controls: it has hexproof and that player is an opponent of its controller (CR 702.11b).
static func shields(state: MmGameState, permanent: MmGameObject, controller_id: int) -> bool:
	if permanent.controller_id == controller_id:
		return false
	for ability: MmAbility in state.characteristics_of(permanent).abilities:
		if ability is HexproofAbility:
			return true
	return false
