class_name ChooseXDecision
extends MmPendingDecision
## The caster of a spell with {X} in its mana cost says what X is, as it is cast (CR 107.3a,
## 601.2b, ADR 0076): after its mode, before its targets. Answer: X, from 0 to
## [member most]. The spell then costs X more for each {X} (CR 601.2f), paid one
## PayManaDecision at a time.

var stack_object_id: int
## The largest X its caster could pay now with the rest of the cost, from their mana pool and
## the mana abilities they could activate (ManaPayment.can_afford()).
var most: int


func _init(deciding_player_id: int, object_id: int, most_payable: int) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	most = most_payable


func validate(answer: Variant) -> String:
	return _check_choice(answer, most + 1)


func describe() -> String:
	return "player %d: choose X from 0 to %d for object %d" % [player_id, most, stack_object_id]
