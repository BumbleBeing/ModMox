class_name TargetChosenEvent
extends MmEvent
## One target of a spell or ability on the stack is chosen (CR 601.2c), for one place of its
## targets: a requirement takes a place for each target it may choose (ADR 0014).

var object_id: int
## The place in the stack object's targets, not the requirement's index.
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
