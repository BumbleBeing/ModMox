class_name ReturnToBattlefieldEffect
extends MmEffect
## "Return [selection] to the battlefield under its owner's control": each selected card in
## exile is put onto the battlefield, all at once. It is a new object (ADR 0008), so it
## enters untapped, with summoning sickness, and its own "enters" abilities trigger. With
## [member counters] it reads "... with [counters] [counter_kind] counters on it": it enters
## with them (CR 122.6), so its "enters" abilities see them. A token that left the
## battlefield never comes back (CR 111.8).
# Later: returning a card from a graveyard arrives with its first card.

@export var selection: MmSelection
## How many counters it enters with. Null for none.
@export var counters: MmValue = null
@export var counter_kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [0 if counters == null else counters.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var card: MmGameObject = state.object(found.id) if found.is_object() else null
		if card == null or card.zone() != state.exile or card.is_token:
			continue
		# A new object starts under its owner's control (CR 110.2).
		var move: ZoneChangeEvent = ZoneChangeEvent.new(card, state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.RETURN_TO_BATTLEFIELD)
		if worked_out[0] > 0:  # CR 107.1b: a negative number is treated as 0.
			move.counters_on_arrival[counter_kind] = worked_out[0]
		events.append(move)
	return events


func selections() -> Array[MmSelection]:
	return [selection]
