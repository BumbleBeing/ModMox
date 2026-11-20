class_name SurveilEffect
extends MmEffect
## "Surveil [amount]" (CR 701.25a, ADR 0068): its controller looks at the top [amount] cards
## of their library, then puts any number of them into their graveyard and the rest on top
## of their library in any order. As it begins they are asked a SurveilDecision naming those
## cards, as many as there are when the library holds fewer; with none, nothing is asked and
## nothing happens. The cards graveyarded and the order of the rest are one batch.
# Later: "target player surveils", and "whenever you surveil" (CR 701.25c), once a card
# needs them.

## How many cards are looked at.
@export var amount: MmValue


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	var count: int = maxi(0, amount.evaluate(state, context)) if amount != null else 1
	var library: MmZone = state.player(context.controller_id).library
	var looked_at: Array[int] = library.object_ids().slice(0, count)
	if looked_at.is_empty():
		return null  # CR 701.25b: surveil 0, or nothing to look at.
	return SurveilDecision.new(context.controller_id, stack_object_id, looked_at)


## How many cards are graveyarded, those cards in order, then the cards kept, top first.
func numbers_with_answer(_state: MmGameState, _context: MmEffectContext, answer: Variant) -> Array[int]:
	var graveyarded: Array[int] = SurveilDecision.graveyarded_in(answer)
	var worked_out: Array[int] = [graveyarded.size()]
	worked_out.append_array(graveyarded)
	worked_out.append_array(SurveilDecision.kept_in(answer))
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if step != 0 or worked_out.is_empty():
		return []
	var graveyard_count: int = worked_out[0]
	var batch: Array[MmEvent] = []
	var graveyard: MmZone = state.player(context.controller_id).graveyard
	for id: int in worked_out.slice(1, 1 + graveyard_count):
		var card: MmGameObject = state.object(id)
		if card != null:
			batch.append(ZoneChangeEvent.new(card, graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.SURVEIL))
	var kept: Array[int] = worked_out.slice(1 + graveyard_count)
	if not kept.is_empty():
		batch.append(LibraryTopOrderedEvent.new(context.controller_id, kept))
	return batch
