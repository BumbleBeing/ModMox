class_name ReturnPermanentsCost
extends MmCost
## "Return [count] [filter] to its owner's hand", as Fear of Isolation's additional cost
## "return a permanent you control to its owner's hand" (CR 601.2h): the payer chooses which,
## from the permanents matching [member filter], and they are returned all at once. Each
## becomes a new object in its owner's hand (ADR 0008). The filter is authored with "you
## control" in it, as the words say.

@export var count: int = 1
@export var filter: MmFilter


func can_pay(state: MmGameState, source: MmGameObject, payer_id: int) -> bool:
	return candidates(state, source, payer_id).size() >= count


## Asks which [member count] of the candidates to return.
func choice(state: MmGameState, source: MmGameObject, payer_id: int) -> MmPendingDecision:
	var decision: ChoosePermanentsDecision = ChoosePermanentsDecision.new(payer_id, source.id, count,
		candidates(state, source, payer_id), filter)
	decision.purpose = ChoosePermanentsDecision.Purpose.RETURN_TO_HAND
	return decision


## Returns the chosen permanents to their owners' hands, all at once.
func pay(state: MmGameState, _source: MmGameObject, _payer_id: int, chosen: Array[int]) -> void:
	assert(chosen.size() == count, "Return exactly %d, not %d." % [count, chosen.size()])
	var returns: Array[MmEvent] = []
	for id: int in chosen:
		var permanent: MmGameObject = state.object(id)
		returns.append(ZoneChangeEvent.new(permanent, state.player(permanent.owner_id).hand, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.RETURN_TO_HAND))
	state.perform_together(returns)


## The permanents that may be returned for it, in ID order.
func candidates(state: MmGameState, source: MmGameObject, payer_id: int) -> Array[int]:
	var context: MmEffectContext = MmEffectContext.new(payer_id, source.id)
	var found: Array[int] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if filter.matches(state, MmReference.to_object(permanent.id), context):
			found.append(permanent.id)
	found.sort()
	return found
