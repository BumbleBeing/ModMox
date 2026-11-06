class_name HasSubtypeFilter
extends MmFilter
## Matches a Game Object that currently has the subtype [member subtype], such as "Wall".

@export var subtype: String = ""


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and state.characteristics_of(game_object).subtypes.has(subtype)
