class_name ExertionEndsEvent
extends MmEvent
## The untap step a permanent was exerted for has come (CR 701.43a): it did not untap in
## it, and is no longer exerted.

var object_id: int


func _init(exerted_object_id: int) -> void:
	object_id = exerted_object_id


func apply(state: MmGameState) -> void:
	state.object(object_id).end_exertion()


func describe() -> String:
	return "EXERTION ENDS: object %d" % object_id
