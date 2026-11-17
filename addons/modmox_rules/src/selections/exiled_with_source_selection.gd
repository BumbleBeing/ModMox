class_name ExiledWithSourceSelection
extends MmSelection
## "The exiled card": each card in exile that an ability of this source exiled, in the
## zone's order (CR 607.2a). A "leaves the battlefield" ability's source is the object as it
## last existed on the battlefield, the same object that exiled the card, so it still finds
## it; a source that left and came back is a new object with nothing exiled (ADR 0008).
# Later: an object with two pairs of linked abilities, each finding only its own cards.


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var found: Array[MmReference] = []
	if context.source_object_id == 0:
		return found
	for card: MmGameObject in state.exile.objects():
		if card.exiled_with_object_id == context.source_object_id:
			found.append(MmReference.to_object(card.id))
	return found
