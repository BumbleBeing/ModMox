class_name CastAnotherSpellThisTurnCondition
extends MmCondition
## "If you've cast another spell this turn", as Sage of the Skies's intervening "if" says
## (CR 603.4): true while the controller has cast a spell this turn besides the ability's
## source. Counted from MmPlayer.spells_cast_this_turn, which holds a spell as soon as it
## becomes cast (CR 601.2i), so a source that is a card they cast, still on the stack, is
## taken out of the count. A copy of a spell was never cast (CR 707.10), so nothing is taken
## out for one.
## Later: a permanent cast this turn with this condition would count itself, once a card
## puts it on a permanent's ability.


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	var you: MmPlayer = state.player(context.controller_id)
	if you == null:
		return false
	var others: int = you.spells_cast_this_turn
	var source: MmGameObject = state.object(context.source_object_id)
	if source != null and source.zone() == state.stack and source.is_card() and source.controller_id == you.id:
		others -= 1
	return others >= 1
