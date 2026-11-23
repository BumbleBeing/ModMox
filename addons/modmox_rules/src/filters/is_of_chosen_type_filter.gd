class_name IsOfChosenTypeFilter
extends MmFilter
## Matches a Game Object that currently has the creature type chosen for the spell or
## ability's source as it entered: "of the chosen type" (ADR 0052). A source with no chosen
## type, or one that has gone, matches nothing.


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var source: MmGameObject = state.object(context.source_object_id)
	if source == null or source.chosen_creature_type == "":
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and state.characteristics_of(game_object).has_subtype(source.chosen_creature_type)
