class_name TapEvent
extends MmEvent
## A permanent becomes tapped (CR 701.26a).

var object_id: int


func _init(tapped_object_id: int) -> void:
	object_id = tapped_object_id


func apply(state: MmGameState) -> void:
	state.object(object_id).set_tapped(true)


func describe() -> String:
	return "TAP: object %d" % object_id
