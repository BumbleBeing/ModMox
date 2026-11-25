class_name CounterEffect
extends MmEffect
## "Counter [selection]" (CR 701.6): each selected spell is put from the stack into its
## owner's graveyard, and each selected ability is removed from the stack, so it never
## resolves and none of its effects happen. Costs paid for it stay paid.
##
## With [member unless_paid], "counter [selection] unless its controller pays [cost]"
## (CR 118.12), as ward is (CR 702.21a, ADR 0062): as it begins, the controller of what it
## would counter is asked a ChooseYesOrNoDecision with that cost, and only if it is still on
## the stack and they could pay it now. Yes pays it one PayManaDecision at a time, as a
## cast's mana is, and nothing is countered; no counters it. One who could not pay is not
## asked, and it is countered.
##
## A spell with CantBeCounteredAbility is passed over (CR 101.2): it may be targeted, but it
## is never countered, and no one is asked to pay to keep it from being countered.
# Later: "unless [a player] pays" for a cost that is not mana ("Ward—Pay 3 life"), and for
# several spells at once, each once a card needs it.

## numbers_with_answer()'s number once the cost was paid: nothing is countered.
const PAID: int = 1

@export var selection: MmSelection
## What its controller may pay to keep it from being countered, or null for a plain
## "counter".
@export var unless_paid: MmManaCost = null


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	if unless_paid == null:
		return null
	var countered: Array[MmGameObject] = _on_the_stack(state, context)
	assert(countered.size() <= 1, "\"Unless its controller pays\" counters one spell or ability.")
	if countered.is_empty():
		return null  # Nothing to counter, so nothing to pay for.
	var payer_id: int = countered[0].controller_id
	if not ManaPayment.can_afford(state, payer_id, unless_paid):
		return null  # CR 118.3: a cost that cannot be paid is not paid, so it is countered.
	return ChooseYesOrNoDecision.new(payer_id, stack_object_id, self, unless_paid)


## [PAID] once its controller has paid, so nothing is countered; nothing on no.
func numbers_with_answer(_state: MmGameState, _context: MmEffectContext, answer: Variant) -> Array[int]:
	if answer as int == ChooseYesOrNoDecision.Choice.YES:
		return [PAID]
	var none: Array[int] = []
	return none


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or (not worked_out.is_empty() and worked_out[0] == PAID):
		return events
	for countered: MmGameObject in _on_the_stack(state, context):
		if countered.is_card_or_copy():
			events.append(ZoneChangeEvent.new(countered, state.graveyard_from_stack(countered), MmZone.BOTTOM,
				ZoneChangeEvent.Reason.COUNTER))
		else:
			events.append(AbilityLeftStackEvent.new(countered.id, false, true))
	return events


func selections() -> Array[MmSelection]:
	return [selection]


## What [member selection] finds that is still on the stack and can be countered.
func _on_the_stack(state: MmGameState, context: MmEffectContext) -> Array[MmGameObject]:
	var found_on_stack: Array[MmGameObject] = []
	for found: MmReference in selection.select(state, context):
		var countered: MmGameObject = state.object(found.id) if found.is_object() else null
		if countered == null or countered.zone() != state.stack:
			continue
		# CR 101.2: "can't be countered" beats the counter.
		if countered.is_card_or_copy() and state.characteristics_of(countered).has_ability(CantBeCounteredAbility):
			continue
		found_on_stack.append(countered)
	return found_on_stack
