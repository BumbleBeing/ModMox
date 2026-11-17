class_name ReturnToHandEffect
extends MmEffect
## "Return [selection] to its owner's hand": each selected card in a graveyard and each
## selected permanent is put into its owner's hand, all at once. A permanent becomes a new
## object there, with none of its counters or damage (ADR 0008).

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var card: MmGameObject = state.object(found.id) if found.is_object() else null
		if card == null or card.zone() == null or not card.zone().kind in [MmZone.Kind.GRAVEYARD, MmZone.Kind.BATTLEFIELD]:
			continue
		events.append(ZoneChangeEvent.new(card, state.player(card.owner_id).hand, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.RETURN_TO_HAND))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
