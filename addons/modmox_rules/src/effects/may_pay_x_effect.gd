class_name MayPayXEffect
extends MmEffect
## "You may pay {X}. If you do, [effect]." (CR 107.3, 605.3a, 608.2d, ADR 0061): as it
## begins its controller is asked a ChooseXToPayDecision, from declining up to the most X
## they could pay. Declining does nothing. Otherwise ResolutionProcedure has X paid one
## PayManaDecision at a time, as a cast's mana is, and then begins [member effect] in its
## place, with its own choices and decision, in a context holding the X paid, which every
## later effect of the spell or ability reads too (PaidXValue).
# Later: a cost to pay other than {X} ("you may pay {1}{W}"), and "if you don't". Each once
# a card needs it.

## What happens once X is paid.
@export var effect: MmEffect


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	return ChooseXToPayDecision.new(context.controller_id, stack_object_id, effect,
		most_payable(state, context.controller_id))


## The largest X [param player_id] could pay now, as generic mana.
static func most_payable(state: MmGameState, player_id: int) -> int:
	var x: int = 0
	var more: MmManaCost = MmManaCost.new()
	more.generic = 1
	while ManaPayment.can_afford(state, player_id, more):
		x += 1
		more.generic = x + 1
	return x


## Only a decline is worked out here: once X is paid, [member effect] begins in its place.
func numbers_with_answer(_state: MmGameState, _context: MmEffectContext, answer: Variant) -> Array[int]:
	assert(answer as int == ChooseXToPayDecision.DECLINE, "A paid X begins the effect it wraps instead.")
	var none: Array[int] = []
	return none


## Only ever worked out with an answer: nothing that cannot stop for a decision, such as a
## mana ability (CR 605.3a), may pay {X}.
func numbers(_state: MmGameState, _context: MmEffectContext) -> Array[int]:
	assert(false, "A \"you may pay {X}\" is answered before its numbers are worked out.")
	var none: Array[int] = []
	return none


## Declined, it does nothing.
func next_batch(_state: MmGameState, _context: MmEffectContext, _step: int, _numbers: Array[int]) -> Array[MmEvent]:
	return []


## [member effect]'s Selections, so what it targets is what the ability targets.
func selections() -> Array[MmSelection]:
	return effect.selections()
