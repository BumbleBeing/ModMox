class_name CounterEffect
extends MmEffect
## "Counter [selection]" (CR 701.6): each selected spell is put from the stack into its
## owner's graveyard, and each selected ability is removed from the stack, so it never
## resolves and none of its effects happen. Costs paid for it stay paid.
# Later: "unless its controller pays" arrives with its card.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var countered: MmGameObject = state.object(found.id) if found.is_object() else null
		if countered == null or countered.zone() != state.stack:
			continue
		if countered.is_card():
			events.append(ZoneChangeEvent.new(countered, state.player(countered.owner_id).graveyard, MmZone.BOTTOM,
				ZoneChangeEvent.Reason.COUNTER))
		else:
			events.append(AbilityLeftStackEvent.new(countered.id, false, true))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
