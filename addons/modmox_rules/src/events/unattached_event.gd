class_name UnattachedEvent
extends MmEvent
## A permanent becomes unattached and stays on the battlefield (CR 701.3d, 704.5n).

var object_id: int


func _init(attachment_id: int) -> void:
	object_id = attachment_id


func apply(state: MmGameState) -> void:
	state.object(object_id).attach_to(0)


func describe() -> String:
	return "UNATTACHED: object %d" % object_id
