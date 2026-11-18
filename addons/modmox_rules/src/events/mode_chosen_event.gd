class_name ModeChosenEvent
extends MmEvent
## The mode of a modal spell on the stack is chosen (CR 601.2b, 700.2a).

var object_id: int
var mode_index: int


func _init(stack_object_id: int, chosen_mode: int) -> void:
	object_id = stack_object_id
	mode_index = chosen_mode


func apply(state: MmGameState) -> void:
	state.object(object_id).set_chosen_mode(mode_index)


func describe() -> String:
	return "MODE CHOSEN: object %d mode %d" % [object_id, mode_index]
