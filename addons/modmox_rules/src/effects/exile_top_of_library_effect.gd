class_name ExileTopOfLibraryEffect
extends MmEffect
## "Exile the top [amount] cards of your library" (CR 701.13a), as Clockwork Percussionist's
## "exile the top card of your library": each selected player puts the top [amount] cards of
## their library into exile face up, all at once, top card first; every card when the library
## holds fewer, which loses nothing, since it is not drawing. The spell or ability remembers
## the cards exiled, so a later effect of it can say "it" (MovedCardsSelection, engine ADR
## 0080), as MayPlayExiledEffect does.

@export var amount: MmValue
@export var players: MmSelection


## How many cards each player exiles, worked out once as the effect begins.
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
			events.append(ZoneChangeEvent.new(state.object(id), state.exile, MmZone.BOTTOM, ZoneChangeEvent.Reason.EXILE))
	return events


func remembers_moved_cards() -> bool:
	return true


func selections() -> Array[MmSelection]:
	return [players]
