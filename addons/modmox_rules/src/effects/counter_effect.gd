class_name CounterEffect
extends MmEffect
## "Counter [selection]" (CR 701.6): each selected spell is put from the stack into its
## owner's graveyard, so it never resolves and none of its effects happen. Costs paid for
## it stay paid.
# Later: countering abilities, and "unless its controller pays", arrive with their cards.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var spell: MmGameObject = state.object(found.id) if found.is_object() else null
		if spell == null or spell.zone() != state.stack or not spell.is_card():
			continue
		events.append(ZoneChangeEvent.new(spell, state.player(spell.owner_id).graveyard, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.COUNTER))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
