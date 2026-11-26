class_name LookAtTopCardsEffect
extends MmEffect
## "Look at the top [amount] cards of your library. You may reveal a [filter] card from among
## them and put it into your hand. Put the rest on the bottom of your library in a random
## order.", as Militia Bugler says (CR 701.20e). As it begins its controller is asked a
## ChooseLookedAtCardsDecision naming those cards, as many as there are when the library
## holds fewer, and those that match [member filter]; with none to look at, nothing is asked
## and nothing happens. The cards taken, up to [member most], go to the hand, revealed with
## [member reveal] (CR 701.20a), so the other player knows them there (engine ADR 0057).
## Then the rest go to the bottom in an order from the Game RNG (LibraryBottomRandomizedEvent),
## or with [member is_rest_in_any_order], as Faerie Mechanist says, "Put the rest on the bottom
## of your library in any order": in the order its controller answers, each under everything
## (LibraryBottomOrderedEvent), so they know those cards lie there.
## Later: the rest put into the graveyard, and more than one taken, once a card says so.

## How many cards are looked at.
@export var amount: MmValue
## What may be taken from among them. Null matches any card.
@export var filter: MmFilter = null
## The most cards that may be taken.
@export var most: int = 1
## "Reveal" (CR 701.20a): the other player sees each card taken.
@export var reveal: bool = true
## "Put the rest on the bottom of your library in any order" rather than "in a random order".
@export var is_rest_in_any_order: bool = false


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	var looked_at: Array[int] = _looked_at(state, context)
	if looked_at.is_empty():
		return null  # Nothing to look at.
	var matching: Array[int] = []
	for id: int in looked_at:
		if filter == null or filter.matches(state, MmReference.to_object(id), context):
			matching.append(id)
	var decision: ChooseLookedAtCardsDecision = ChooseLookedAtCardsDecision.new(context.controller_id, stack_object_id,
		looked_at, matching, most, filter)
	decision.orders_rest = is_rest_in_any_order
	return decision


## How many cards are taken, those cards, then the rest: top first, or in any order as
## answered, the last the deepest.
func numbers_with_answer(state: MmGameState, context: MmEffectContext, answer: Variant) -> Array[int]:
	var taken: Array[int] = []
	for id: Variant in (answer as Array)[0] if is_rest_in_any_order else answer as Array:
		taken.append(id as int)
	var worked_out: Array[int] = [taken.size()]
	worked_out.append_array(taken)
	if is_rest_in_any_order:
		for id: Variant in (answer as Array)[1]:
			worked_out.append(id as int)
		return worked_out
	for id: int in _looked_at(state, context):
		if not taken.has(id):
			worked_out.append(id)
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if worked_out.is_empty():
		return []
	var taken_count: int = worked_out[0]
	var taken: Array[int] = worked_out.slice(1, 1 + taken_count)
	var rest: Array[int] = worked_out.slice(1 + taken_count)
	var library: MmZone = state.player(context.controller_id).library
	var takes_first: bool = not taken.is_empty()
	if step == 0 and takes_first:
		var hand: MmZone = state.player(context.controller_id).hand
		var batch: Array[MmEvent] = []
		for id: int in taken:
			var card: MmGameObject = state.object(id)
			if card == null or card.zone() != library:
				continue
			var moved: ZoneChangeEvent = ZoneChangeEvent.new(card, hand, MmZone.BOTTOM, ZoneChangeEvent.Reason.LOOK)
			moved.revealed = reveal
			batch.append(moved)
		return batch
	if step == (1 if takes_first else 0) and not rest.is_empty():
		if is_rest_in_any_order:
			return [LibraryBottomOrderedEvent.new(context.controller_id, rest)]
		return [LibraryBottomRandomizedEvent.new(context.controller_id, rest)]
	return []


## The object IDs of the cards looked at: the top [member amount] of the controller's
## library, top first.
func _looked_at(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var count: int = maxi(0, amount.evaluate(state, context)) if amount != null else 1
	return state.player(context.controller_id).library.object_ids().slice(0, count)
