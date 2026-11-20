class_name ControlsMoreFilter
extends MmFilter
## Matches a player who controls more permanents matching [member filter] than the
## controller of the spell or ability does: "players who control more lands than you", as
## Oreskos Explorer counts them. Strictly more, so the controller never matches, and one on
## one it matches the opponent or no one. Anything that is not a player never matches.

## What is counted on each side, such as "land".
@export var filter: MmFilter


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if not candidate.is_player():
		return false
	return _count_controlled_by(state, candidate.id, context) > _count_controlled_by(state, context.controller_id, context)


## How many permanents [param player_id] controls that match [member filter].
func _count_controlled_by(state: MmGameState, player_id: int, context: MmEffectContext) -> int:
	var count: int = 0
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.controller_id == player_id \
				and (filter == null or filter.matches(state, MmReference.to_object(permanent.id), context)):
			count += 1
	return count
