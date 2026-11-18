class_name AttachedEvent
extends MmEvent
## A permanent becomes attached to another (CR 701.3a). One that was attached to something
## else is no longer attached to that (CR 701.3c).

var object_id: int
var to_object_id: int


func _init(attachment_id: int, attached_to_id: int) -> void:
	object_id = attachment_id
	to_object_id = attached_to_id


func apply(state: MmGameState) -> void:
	state.object(object_id).attach_to(to_object_id)


func describe() -> String:
	return "ATTACHED: object %d to object %d" % [object_id, to_object_id]
