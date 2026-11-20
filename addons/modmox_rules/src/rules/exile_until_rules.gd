class_name ExileUntilRules
extends RefCounted
## Exiling "until [this permanent] leaves the battlefield" (CR 610.3, ADR 0065): the card
## returns to the battlefield under its owner's control immediately after the object that
## exiled it leaves. The return is part of the exile's effect, not a triggered ability, so
## nothing goes on the stack; MmGameState performs it as a batch of its own right after the
## batch the object left in, before anything else happens.
# Later: a returned permanent's "as this enters" choice (ADR 0052), when a card exiled this
# way has one.


## The moves that return every card in exile whose exiler has left the battlefield, in the
## zone's order. A token never returns: it ceases to exist (CR 111.8, 704.5d).
static func returns(state: MmGameState) -> Array[MmEvent]:
	var moves: Array[MmEvent] = []
	for card: MmGameObject in state.exile.objects():
		if not card.returns_when_exiler_leaves or card.is_token:
			continue
		var exiler: MmGameObject = state.object(card.exiled_with_object_id)
		if exiler != null and exiler.zone() == state.battlefield:
			continue
		# A new object starts under its owner's control (CR 110.2).
		moves.append(ZoneChangeEvent.new(card, state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.RETURN_TO_BATTLEFIELD))
	return moves
