class_name HasSupertypeFilter
extends MmFilter
## Matches a Game Object that currently has [member supertype] (CR 205.4), such as the
## "basic" of "basic land card" (ADR 0057).

@export var supertype: MmCardTypes.Supertype = MmCardTypes.Supertype.BASIC


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and state.characteristics_of(game_object).has_supertype(supertype)
