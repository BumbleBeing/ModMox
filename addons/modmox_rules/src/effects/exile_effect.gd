class_name ExileEffect
extends MmEffect
## "Exile [selection]" (CR 701.13a): each selected permanent is put into exile, all at once.
## Each card it exiles remembers the ability's source, so a linked ability of that object
## can find "the exiled card" (CR 607.2a, ExiledWithSourceSelection).
# Later: exiling cards from other zones, such as a graveyard, arrives with its first card.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent == null or permanent.zone() != state.battlefield:
			continue
		var move: ZoneChangeEvent = ZoneChangeEvent.new(permanent, state.exile, MmZone.BOTTOM, ZoneChangeEvent.Reason.EXILE)
		move.exiled_with_object_id = context.source_object_id
		events.append(move)
	return events


func selections() -> Array[MmSelection]:
	return [selection]
