class_name UntapEvent
extends MmEvent
## A permanent becomes untapped (CR 701.26b).

var object_id: int


func _init(untapped_object_id: int) -> void:
	object_id = untapped_object_id


func apply(state: MmGameState) -> void:
	state.object(object_id).set_tapped(false)


func describe() -> String:
	return "UNTAP: object %d" % object_id
