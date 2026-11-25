class_name ScryEffect
extends MmEffect
## "Scry [amount]" (CR 701.22a, ADR 0087): its controller looks at the top [amount] cards of
## their library, then puts any number of them on the bottom of their library in any order
## and the rest on top in any order. As it begins they are asked a ScryDecision naming those
## cards, as many as there are when the library holds fewer; with none, nothing is asked and
## nothing happens (CR 701.22b). The cards kept and those put on the bottom are placed in
## one batch, and none leaves the library.
# Later: "target player scries", and "whenever you scry" (CR 701.22c), once a card needs
# them.

## How many cards are looked at.
@export var amount: MmValue


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	var count: int = maxi(0, amount.evaluate(state, context)) if amount != null else 1
	var library: MmZone = state.player(context.controller_id).library
	var looked_at: Array[int] = library.object_ids().slice(0, count)
	if looked_at.is_empty():
		return null  # CR 701.22b: scry 0, or nothing to look at.
	return ScryDecision.new(context.controller_id, stack_object_id, looked_at)


## How many cards go to the bottom, those cards in order, then the cards kept, top first.
func numbers_with_answer(_state: MmGameState, _context: MmEffectContext, answer: Variant) -> Array[int]:
	var bottom: Array[int] = SurveilDecision.sent_in(answer)
	var worked_out: Array[int] = [bottom.size()]
	worked_out.append_array(bottom)
	worked_out.append_array(SurveilDecision.kept_in(answer))
	return worked_out


func next_batch(_state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if step != 0 or worked_out.is_empty():
		return []
	var bottom_count: int = worked_out[0]
	var batch: Array[MmEvent] = []
	var kept: Array[int] = worked_out.slice(1 + bottom_count)
	if not kept.is_empty():
		batch.append(LibraryTopOrderedEvent.new(context.controller_id, kept))
	var bottom: Array[int] = worked_out.slice(1, 1 + bottom_count)
	if not bottom.is_empty():
		batch.append(LibraryBottomOrderedEvent.new(context.controller_id, bottom))
	return batch
