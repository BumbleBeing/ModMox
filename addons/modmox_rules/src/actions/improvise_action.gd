class_name ImproviseAction
extends MmAction
## While paying the mana of a spell with improvise (CR 702.126a, engine ADR 0099), tap the
## untapped artifact [member object_id] to pay {1} of the generic mana still owed. Offered
## only in a PayManaDecision.

var object_id: int


func _init(artifact_id: int) -> void:
	object_id = artifact_id


func describe() -> String:
	return "improvise with object %d" % object_id
