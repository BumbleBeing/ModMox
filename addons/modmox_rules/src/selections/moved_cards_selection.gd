class_name MovedCardsSelection
extends MmSelection
## "Them": the cards an earlier effect of the same spell or ability moved and remembers, such
## as the cards a MillEffect milled, in the order they moved (engine ADR 0080). A card that
## has since moved again is a new object and is not among them (ADR 0008).


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var found: Array[MmReference] = []
	for id: int in context.moved_ids:
		if state.object(id) != null:
			found.append(MmReference.to_object(id))
	return found
