class_name HasOriginalNameFilter
extends MmFilter
## Matches a Game Object originally named [member original_name]: "originally named Charmed
## Stray", this game's reading of a printed "named Charmed Stray". A card goes by the name of
## its Original (ADR 0004), whatever Modifications have made of its own name. An object with
## no Original goes by its current name, matched exactly.

@export var original_name: String = ""


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	if game_object == null:
		return false
	# The Original is not a characteristic: nothing in an encounter changes it.
	var original: MmCardDefinition = game_object.definition.original if game_object.definition != null else null
	if original != null:
		return original.name == original_name
	return state.characteristics_of(game_object).name == original_name
