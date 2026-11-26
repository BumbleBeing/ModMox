class_name DiedThisTurnCondition
extends MmCondition
## "A [filter] died [under whose control] this turn", as Cult Conscript's "Activate only if a
## non-Skeleton creature died under your control this turn" says (CR 700.4, ADR 0095): true
## while some permanent put into a graveyard from the battlefield this turn matches
## [member filter] and was controlled by [member whose], each seen as it last existed on the
## battlefield (CR 608.2h). "Died" is said of creatures, so the filter names a creature.
## Read from MmGameState.died_this_turn(), which a new turn clears.

## What died, as it last existed. Null for any permanent.
@export var filter: MmFilter = null
## Whose control it died under, relative to the controller of the ability that asks: YOU is
## "under your control".
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	for object_id: int in state.died_this_turn():
		var seen: MmGameObject = state.object_or_last_known(object_id)
		if seen == null or not MmTrigger.is_whose(whose, seen.controller_id, context):
			continue
		if filter == null or filter.matches(state, MmReference.to_object(object_id), context):
			return true
	return false
