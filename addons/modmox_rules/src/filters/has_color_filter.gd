class_name HasColorFilter
extends MmFilter
## Matches a Game Object that currently has [member color], such as "white creatures".

@export var color: MmCardTypes.CardColor = MmCardTypes.CardColor.WHITE


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and state.characteristics_of(game_object).colors.has(color)
