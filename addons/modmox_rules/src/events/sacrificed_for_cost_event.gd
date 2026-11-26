class_name SacrificedForCostEvent
extends MmEvent
## The permanents sacrificed to pay a spell's or ability's cost are remembered on its object
## on the stack (CR 601.2h, 602.2b), so "the sacrificed creature" finds them as it resolves
## (engine ADR 0098).

var object_id: int
var sacrificed_ids: Array[int]


func _init(stack_object_id: int, ids: Array[int]) -> void:
	object_id = stack_object_id
	sacrificed_ids = ids.duplicate()


func apply(state: MmGameState) -> void:
	state.object(object_id).record_sacrificed(sacrificed_ids)


func describe() -> String:
	return "SACRIFICED FOR COST: object %d %s" % [object_id, sacrificed_ids]
