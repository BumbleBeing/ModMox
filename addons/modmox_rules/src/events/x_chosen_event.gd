class_name XChosenEvent
extends MmEvent
## The X of a spell's mana cost is chosen as it is cast (CR 107.3a, 601.2b, ADR 0076).

var object_id: int
var x: int


func _init(stack_object_id: int, chosen: int) -> void:
	object_id = stack_object_id
	x = chosen


func apply(state: MmGameState) -> void:
	state.object(object_id).set_chosen_x(x)


func describe() -> String:
	return "X CHOSEN: object %d X %d" % [object_id, x]
