class_name ManaValueFilter
extends MmFilter
## Matches a Game Object whose mana value is [member amount] or less, or [member amount] or
## greater (CR 202.3), such as "creature card with mana value 3 or less". It is read from
## the object's characteristics in any zone, so a card in a graveyard has one; a land has
## none, which is 0 (CR 202.3a). A player never matches.

## Saved in Content, so values are explicit and only ever added.
enum Comparison { OR_LESS = 0, OR_GREATER = 1 }

@export var comparison: Comparison = Comparison.OR_LESS
@export var amount: int = 0


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	if game_object == null:
		return false
	var mana_value: int = state.characteristics_of(game_object).mana_value()
	return mana_value <= amount if comparison == Comparison.OR_LESS else mana_value >= amount
