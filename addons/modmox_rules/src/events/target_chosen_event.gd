class_name TargetChosenEvent
extends MmEvent
## The target for one requirement of a spell or ability on the stack is chosen (CR 601.2c).

var object_id: int
var target_index: int
var target: MmReference


func _init(stack_object_id: int, requirement_index: int, chosen: MmReference) -> void:
	object_id = stack_object_id
	target_index = requirement_index
	target = chosen


func apply(state: MmGameState) -> void:
	state.object(object_id).set_target(target_index, target)


func describe() -> String:
	return "TARGET CHOSEN: object %d target %d is %s" % [object_id, target_index, target.describe()]
