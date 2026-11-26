class_name SacrificedSelection
extends MmSelection
## "The sacrificed creature", as Bushmeat Poacher's cost names it, or "that creature" after
## a sacrifice, as Disciple of Bolas's effect does (engine ADR 0098): each permanent this
## spell or ability sacrificed, to pay its cost or by an earlier effect of its own, in the
## order sacrificed. It finds the object as it last existed on the battlefield (CR 608.2h),
## so a Value reads its power or toughness as they were, a token's too once it has ceased to
## exist; nothing it finds can be changed or moved.


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var found: Array[MmReference] = []
	for id: int in context.sacrificed_ids:
		if state.object_or_last_known(id) != null:
			found.append(MmReference.to_object(id))
	return found
