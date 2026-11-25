class_name PutOnBottomOfLibraryEffect
extends MmEffect
## "Put [selection] on the bottom of its owner's library", as Landscaper Colos's "put target
## card from an opponent's graveyard on the bottom of their library": each selected card in a
## graveyard is put under every card of its owner's library, all at once. It becomes a new
## object there (ADR 0008), hidden as every card in a library is. Several go in the order
## [member selection] finds them, the first highest.
## Later: a permanent, "on top of", and several ordered by their owner (CR 401.4), once a card
## says so.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var card: MmGameObject = state.object(found.id) if found.is_object() else null
		if card == null or card.zone() == null or card.zone().kind != MmZone.Kind.GRAVEYARD:
			continue
		events.append(ZoneChangeEvent.new(card, state.player(card.owner_id).library, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.PUT_ON_BOTTOM))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
