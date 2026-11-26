class_name NextUntapSkippedEvent
extends MmEvent
## A permanent won't untap during its controller's next untap step (CR 502.3), as a
## DoesntUntapEffect says.

var object_id: int


func _init(skipping_object_id: int) -> void:
	object_id = skipping_object_id


func apply(state: MmGameState) -> void:
	state.object(object_id).skip_next_untap()


func describe() -> String:
	return "SKIPS NEXT UNTAP: object %d" % object_id
