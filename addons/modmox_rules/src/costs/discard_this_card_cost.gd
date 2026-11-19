class_name DiscardThisCardCost
extends MmCost
## "Discard this card" (CR 701.9a), as cycling's cost has it (CR 702.29a, ADR 0059): the
## ability's source moves from its owner's hand to their graveyard. Payable only while the
## source is in the payer's hand.


## Only a card still in the payer's hand can be discarded.
func can_pay(state: MmGameState, source: MmGameObject, payer_id: int) -> bool:
	return source.zone() == state.player(payer_id).hand


## Discards the card. ADR 0008: it is a new object in the graveyard.
func pay(state: MmGameState, source: MmGameObject, _payer_id: int, _chosen: Array[int]) -> void:
	state.perform(ZoneChangeEvent.new(source, state.player(source.owner_id).graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.DISCARD))
