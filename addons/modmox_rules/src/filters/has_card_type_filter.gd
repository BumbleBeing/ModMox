class_name HasCardTypeFilter
extends MmFilter
## Matches a Game Object that currently has [member card_type].

@export var card_type: MmCardTypes.CardType = MmCardTypes.CardType.CREATURE


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and state.characteristics_of(game_object).has_card_type(card_type)
