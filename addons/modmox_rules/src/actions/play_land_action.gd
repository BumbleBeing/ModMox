class_name PlayLandAction
extends MmAction
## Play the land [member object_id] from hand: a special action that does not use the
## stack (CR 116.2a, 305.1).

var object_id: int


func _init(land_object_id: int) -> void:
	object_id = land_object_id


func describe() -> String:
	return "play land %d" % object_id
