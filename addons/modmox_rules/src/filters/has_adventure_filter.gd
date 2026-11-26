class_name HasAdventureFilter
extends MmFilter
## Matches an Adventurer card (CR 715.2), "that has an Adventure", as in Edgewall
## Innkeeper's "a creature spell that has an Adventure": in a hand, in exile, on the
## battlefield, or on the stack cast as the creature. A spell cast as its Adventure has only
## the Adventure's characteristics (CR 715.3b, engine ADR 0078), so it has none. Never a
## player.


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	return game_object != null and state.characteristics_of(game_object).adventure != null
