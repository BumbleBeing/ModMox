class_name MillEffect
extends MmEffect
## "[players] mill [amount] cards" (CR 701.17a): each selected player puts the top [amount]
## cards of their library into their graveyard, all at once, top card first; every card
## when the library holds fewer (CR 701.17b), which loses nothing, since it is not drawing.
## The spell or ability remembers the cards milled, so a later effect of it can choose
## "from among them" (MovedCardsSelection, engine ADR 0080).
# Later: "whenever you mill", once a card needs it.

@export var amount: MmValue
@export var players: MmSelection


## How many cards each player mills, worked out once as the effect begins.
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	return [maxi(0, amount.evaluate(state, context)) if amount != null else 1]


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out.is_empty():
		return events
	for found: MmReference in players.select(state, context):
		var player: MmPlayer = state.player(found.id) if found.is_player() else null
		if player == null:
			continue
		for id: int in player.library.object_ids().slice(0, worked_out[0]):
			events.append(ZoneChangeEvent.new(state.object(id), player.graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.MILL))
	return events


func remembers_moved_cards() -> bool:
	return true


func selections() -> Array[MmSelection]:
	return [players]
