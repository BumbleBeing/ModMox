class_name PowerFilter
extends MmFilter
## Matches a creature, or a creature card in any zone, whose power is [member amount] or
## less, or [member amount] or greater (CR 208.1), such as "creature spell with power 2 or
## less". Power is read from the object's characteristics, so a characteristic-defining
## ability counts in every zone (CR 604.3). Anything that is not a creature has no power
## and never matches; nor does a player.

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
	var characteristics: MmCharacteristics = state.characteristics_of(game_object)
	if not characteristics.has_card_type(MmCardTypes.CardType.CREATURE):
		return false
	var power: int = characteristics.power
	return power <= amount if comparison == Comparison.OR_LESS else power >= amount
