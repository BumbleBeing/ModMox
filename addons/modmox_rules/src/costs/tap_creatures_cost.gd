class_name TapCreaturesCost
extends MmCost
## "Tap [count] untapped creatures you control": the payer chooses which, from the
## permanents matching [member filter] (CR 601.2h). It is not the {T} of any of them, so a
## creature with summoning sickness may be tapped for it (CR 302.6). The filter is authored
## with "untapped" and "you control" in it, as the words say.

@export var count: int = 1
@export var filter: MmFilter


func can_pay(state: MmGameState, source: MmGameObject, payer_id: int) -> bool:
	return candidates(state, source, payer_id).size() >= count


## Asks which [member count] of the candidates to tap.
func choice(state: MmGameState, source: MmGameObject, payer_id: int) -> MmPendingDecision:
	return ChoosePermanentsDecision.new(payer_id, source.id, count, candidates(state, source, payer_id), filter)


## Taps the chosen permanents, all at once.
func pay(state: MmGameState, _source: MmGameObject, _payer_id: int, chosen: Array[int]) -> void:
	assert(chosen.size() == count, "Tap exactly %d, not %d." % [count, chosen.size()])
	var taps: Array[MmEvent] = []
	for id: int in chosen:
		taps.append(TapEvent.new(id))
	state.perform_together(taps)


## The permanents that may be tapped for it, in ID order.
func candidates(state: MmGameState, source: MmGameObject, payer_id: int) -> Array[int]:
	var context: MmEffectContext = MmEffectContext.new(payer_id, source.id)
	var found: Array[int] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if filter.matches(state, MmReference.to_object(permanent.id), context):
			found.append(permanent.id)
	found.sort()
	return found
