class_name DiscardCardsCost
extends MmCost
## "Discard [count] cards" as a cost (CR 701.9a, 118), as Irreverent Gremlin's "you may
## discard a card. If you do, draw a card.": the payer chooses that many cards of their own
## hand as it is paid, and they go to their graveyard all at once. Payable only while their
## hand holds [member count] cards, so "if you do" never happens with an empty hand
## (CR 118.3). The choice is the ChooseCardsToDiscardDecision a DiscardEffect asks, asked only
## when there is a choice: a hand of exactly that many cards is discarded whole. It needs
## nothing of its source, so it can be paid after the source has left. As part of an
## activated ability's cost, as a Blood token's "{1}, {T}, Discard a card, Sacrifice this
## token: Draw a card." (CR 111.10g), CastProcedure asks it with the ability's other costs,
## before the mana (CR 601.2h).

## How many cards are discarded.
@export var count: int = 1


func can_pay(state: MmGameState, _source: MmGameObject, payer_id: int) -> bool:
	return state.player(payer_id).hand.size() >= count


## Asks which cards to discard, or null when the hand holds just that many.
func choice(state: MmGameState, _source: MmGameObject, payer_id: int) -> MmPendingDecision:
	var hand: Array[int] = state.player(payer_id).hand.object_ids()
	if hand.size() <= count:
		return null
	return ChooseCardsToDiscardDecision.new(payer_id, count, hand)


## Discards the chosen cards, or the whole hand when nothing was chosen.
func pay(state: MmGameState, _source: MmGameObject, payer_id: int, chosen: Array[int]) -> void:
	var payer: MmPlayer = state.player(payer_id)
	var discarded: Array[int] = chosen if not chosen.is_empty() else payer.hand.object_ids()
	var moves: Array[MmEvent] = []
	for id: int in discarded:
		moves.append(ZoneChangeEvent.new(state.object(id), payer.graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.DISCARD))
	state.perform_together(moves)
