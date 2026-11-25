class_name ExileFromGraveyardCost
extends MmCost
## "Exile a [filter] card from your graveyard" (CR 701.13a), as Kishla Trawlers's "you may
## exile a creature card from your graveyard": the payer chooses one card of their own
## graveyard matching [member filter] as it is paid, and it is exiled. Payable only while
## their graveyard holds one. The choice is a ChooseObjectDecision whose purpose is
## EXILE_FROM_GRAVEYARD. The filter is authored without "from your graveyard", which the
## cost says. It needs nothing of its source, so it can be paid after the source has left.
# Later: more than one card, once a card says so.

@export var filter: MmFilter


func can_pay(state: MmGameState, source: MmGameObject, payer_id: int) -> bool:
	return not candidates(state, source, payer_id).is_empty()


## Asks which card to exile. Its stack object is the source's ID here; a resolution asking
## it names the ability resolving instead.
func choice(state: MmGameState, source: MmGameObject, payer_id: int) -> MmPendingDecision:
	var decision: ChooseObjectDecision = ChooseObjectDecision.new(payer_id, 0 if source == null else source.id,
		ChooseObjectDecision.NO_CHOICE_INDEX, filter, candidates(state, source, payer_id))
	decision.purpose = ChooseObjectDecision.Purpose.EXILE_FROM_GRAVEYARD
	return decision


## Exiles the chosen card.
func pay(state: MmGameState, _source: MmGameObject, _payer_id: int, chosen: Array[int]) -> void:
	assert(chosen.size() == 1, "Exile exactly one card, not %d." % chosen.size())
	state.perform(ZoneChangeEvent.new(state.object(chosen[0]), state.exile, MmZone.BOTTOM, ZoneChangeEvent.Reason.EXILE))


## The cards of the payer's graveyard that may be exiled for it, in their zone's order.
func candidates(state: MmGameState, source: MmGameObject, payer_id: int) -> Array[MmReference]:
	var context: MmEffectContext = MmEffectContext.new(payer_id, 0 if source == null else source.id)
	var found: Array[MmReference] = []
	for card: MmGameObject in state.player(payer_id).graveyard.objects():
		var reference: MmReference = MmReference.to_object(card.id)
		if filter == null or filter.matches(state, reference, context):
			found.append(reference)
	return found
