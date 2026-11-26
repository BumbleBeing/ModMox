class_name SacrificePermanentsCost
extends MmCost
## "Sacrifice [count] [filter]" (CR 701.21a), as Selfcraft Mechan's "you may sacrifice an
## artifact": the payer chooses which of the permanents they control that match [member
## filter], and they move to their owners' graveyards all at once. A player can sacrifice
## only a permanent they control, so the filter is authored without "you control", which
## "sacrifice" says; the source itself may be chosen when it matches. It is not destruction,
## so indestructible and regeneration never stop it. The choice is a ChoosePermanentsDecision
## whose purpose is SACRIFICE.

@export var count: int = 1
@export var filter: MmFilter


func can_pay(state: MmGameState, source: MmGameObject, payer_id: int) -> bool:
	return candidates(state, source, payer_id).size() >= count


## Asks which [member count] of the candidates to sacrifice. Its stack object is the source's
## ID here; a resolution asking it names the ability resolving instead.
func choice(state: MmGameState, source: MmGameObject, payer_id: int) -> MmPendingDecision:
	var decision: ChoosePermanentsDecision = ChoosePermanentsDecision.new(payer_id, 0 if source == null else source.id,
		count, candidates(state, source, payer_id), filter)
	decision.purpose = ChoosePermanentsDecision.Purpose.SACRIFICE
	return decision


## Sacrifices the chosen permanents, all at once. ADR 0008: each is a new object in its
## owner's graveyard.
func pay(state: MmGameState, _source: MmGameObject, _payer_id: int, chosen: Array[int]) -> void:
	assert(chosen.size() == count, "Sacrifice exactly %d, not %d." % [count, chosen.size()])
	var sacrifices: Array[MmEvent] = []
	for id: int in chosen:
		var permanent: MmGameObject = state.object(id)
		sacrifices.append(ZoneChangeEvent.new(permanent, state.player(permanent.owner_id).graveyard, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.SACRIFICE))
	state.perform_together(sacrifices)


## The permanents the payer controls that may be sacrificed for it, in ID order.
func candidates(state: MmGameState, source: MmGameObject, payer_id: int) -> Array[int]:
	var context: MmEffectContext = MmEffectContext.new(payer_id, 0 if source == null else source.id)
	var found: Array[int] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.controller_id != payer_id:
			continue  # CR 701.21a: only a permanent its player controls.
		if filter == null or filter.matches(state, MmReference.to_object(permanent.id), context):
			found.append(permanent.id)
	found.sort()
	return found
