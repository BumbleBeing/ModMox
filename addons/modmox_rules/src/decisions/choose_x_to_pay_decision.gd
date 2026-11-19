class_name ChooseXToPayDecision
extends MmPendingDecision
## The controller of a resolving spell or ability says how much X to pay for its "you may
## pay {X}", or declines, as that effect begins (CR 107.3, 608.2d, ADR 0061). X is then
## paid one PayManaDecision at a time. Answer: DECLINE, or answer_for(x) for an X from 0 to
## [member most].

## The answer that pays nothing, so what "if you do" offers does not happen.
const DECLINE: int = 0

var stack_object_id: int
## What happens once X is paid, so that what is asked can be put in words. Card data,
## never changed.
var effect: MmEffect
## The largest X its controller could pay now, from their mana pool and the mana abilities
## they could activate (ManaPayment.can_afford()).
var most: int


func _init(deciding_player_id: int, object_id: int, offered: MmEffect, most_payable: int) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	effect = offered
	most = most_payable


## The answer that pays [param x]. X = 0 is paying too: what "if you do" offers happens.
static func answer_for(x: int) -> int:
	return x + 1


## The X [param answer] pays, or MmEffectContext.NONE_PAID for DECLINE.
static func x_of(answer: int) -> int:
	return MmEffectContext.NONE_PAID if answer == DECLINE else answer - 1


func validate(answer: Variant) -> String:
	return _check_choice(answer, most + 2)


func describe() -> String:
	return "player %d: pay X from 0 to %d, or not, for object %d" % [player_id, most, stack_object_id]
