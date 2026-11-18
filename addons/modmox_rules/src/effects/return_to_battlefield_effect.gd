class_name ReturnToBattlefieldEffect
extends MmEffect
## "Return [selection] to the battlefield under its owner's control": each selected card in
## exile or a graveyard is put onto the battlefield, all at once. It is a new object
## (ADR 0008), so it enters with summoning sickness and its own "enters" abilities trigger,
## as do others' (CR 603.6a). It enters untapped unless [member tapped] reads "... to the
## battlefield tapped": then it is tapped as it arrives (CR 110.5b). With [member counters]
## it reads "... with [counters] [counter_kind] counters on it": it enters with them
## (CR 122.6). Either way its "enters" abilities see it as it arrived. A token that left the
## battlefield never comes back (CR 111.8).
# Later: "under your control", for a card returned from another player's graveyard.

@export var selection: MmSelection
## How many counters it enters with. Null for none.
@export var counters: MmValue = null
@export var counter_kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
## True for "to the battlefield tapped".
@export var tapped: bool = false


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [0 if counters == null else counters.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var card: MmGameObject = state.object(found.id) if found.is_object() else null
		var from: MmZone = null if card == null else card.zone()
		if from == null or card.is_token or not (from == state.exile or from.kind == MmZone.Kind.GRAVEYARD):
			continue
		# A new object starts under its owner's control (CR 110.2).
		var move: ZoneChangeEvent = ZoneChangeEvent.new(card, state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.RETURN_TO_BATTLEFIELD)
		if worked_out[0] > 0:  # CR 107.1b: a negative number is treated as 0.
			move.counters_on_arrival[counter_kind] = worked_out[0]
		move.tapped_on_arrival = tapped
		events.append(move)
	return events


func selections() -> Array[MmSelection]:
	return [selection]
