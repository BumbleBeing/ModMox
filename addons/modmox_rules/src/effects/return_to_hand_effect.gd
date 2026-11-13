class_name ReturnToHandEffect
extends MmEffect
## "Return [selection] to its owner's hand": each selected card in a graveyard is put into
## its owner's hand, all at once.
# Later: returning a permanent to its owner's hand arrives with its first card.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var card: MmGameObject = state.object(found.id) if found.is_object() else null
		if card == null or card.zone() == null or card.zone().kind != MmZone.Kind.GRAVEYARD:
			continue
		events.append(ZoneChangeEvent.new(card, state.player(card.owner_id).hand, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.RETURN_TO_HAND))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
