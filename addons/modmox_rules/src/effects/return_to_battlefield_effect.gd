class_name ReturnToBattlefieldEffect
extends MmEffect
## "Return [selection] to the battlefield under its owner's control": each selected card in
## exile is put onto the battlefield, all at once. It is a new object (ADR 0008), so it
## enters untapped, with summoning sickness, and its own "enters" abilities trigger.
# Later: returning a card from a graveyard arrives with its first card.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var card: MmGameObject = state.object(found.id) if found.is_object() else null
		if card == null or card.zone() != state.exile:
			continue
		# A new object starts under its owner's control (CR 110.2).
		events.append(ZoneChangeEvent.new(card, state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.RETURN_TO_BATTLEFIELD))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
