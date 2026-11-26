class_name TriggeringCardSelection
extends MmSelection
## "It", as undying's "return it to the battlefield" says (CR 702.93a, engine ADR 0096): the
## new object a triggered ability's moving object became where it went, as the card in the
## graveyard that a creature that died became (ADR 0008). It finds nothing once that card
## has moved again, since it is then another new object, nor when the object never moved.
## Unlike TriggeringObjectSelection, which finds the object as it last existed, what it
## finds can be moved.


func select(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	if context.triggering_object_id == 0:
		return []
	var moved: MmGameObject = state.object_or_last_known(context.triggering_object_id)
	if moved == null or moved.became_object_id == 0 or state.object(moved.became_object_id) == null:
		return []
	return [MmReference.to_object(moved.became_object_id)]
