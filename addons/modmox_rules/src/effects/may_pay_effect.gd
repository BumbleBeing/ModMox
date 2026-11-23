class_name MayPayEffect
extends MmEffect
## "You may [cost]. If you do, [effect]." (CR 603.5, 608.2d, ADR 0076), as Guiding Hydra's "you
## may remove a +1/+1 counter from this creature. If you do, put a +1/+1 counter on each other
## creature you control." As it begins its controller is asked a ChooseYesOrNoDecision with
## the cost as its [member ChooseYesOrNoDecision.resolution_cost], only if they could pay it
## now for the ability's source; ResolutionProcedure pays it at once on yes, and then
## [member effect] happens. No, or a cost that cannot be paid, does nothing (CR 118.3).
# Later: a mana cost ("you may pay {1}{W}"), paid one PayManaDecision at a time as ward's is,
# and "if you don't". Each once a card needs it.

@export var cost: MmCost
## What happens once the cost is paid.
@export var effect: MmEffect


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	if not cost.can_pay(state, state.object(context.source_object_id), context.controller_id):
		return null
	var asked: ChooseYesOrNoDecision = ChooseYesOrNoDecision.new(context.controller_id, stack_object_id, effect)
	asked.resolution_cost = cost
	return asked


## Unpaid, since it could not be: nothing happens.
func numbers(_state: MmGameState, _context: MmEffectContext) -> Array[int]:
	return [0]


## The first number is 1 once paid and 0 on no; then [member effect]'s own numbers follow
## (CR 608.2h).
func numbers_with_answer(state: MmGameState, context: MmEffectContext, answer: Variant) -> Array[int]:
	if answer as int != ChooseYesOrNoDecision.Choice.YES:
		return [0]
	var worked_out: Array[int] = [1]
	worked_out.append_array(effect.numbers(state, context))
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if worked_out.is_empty() or worked_out[0] != 1:
		return []
	return effect.next_batch(state, context, step, worked_out.slice(1))


## [member effect]'s Selections, so what it targets is what the ability targets.
func selections() -> Array[MmSelection]:
	return effect.selections()


func adds_mana() -> bool:
	return effect.adds_mana()
