class_name HasAbilityFilter
extends MmFilter
## Matches a Game Object that currently has an ability of [member ability_kind], such as
## "creatures with flying".

@export var ability_kind: Script


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and state.characteristics_of(game_object).has_ability(ability_kind)
