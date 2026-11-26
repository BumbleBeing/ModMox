class_name UntapSkippedEvent
extends MmEvent
## The untap step a permanent was to skip has come (CR 502.3): it did not untap in it, and
## the effect that said so is used up.

var object_id: int


func _init(skipping_object_id: int) -> void:
	object_id = skipping_object_id


func apply(state: MmGameState) -> void:
	state.object(object_id).end_skipping_untap()


func describe() -> String:
	return "UNTAP SKIPPED: object %d" % object_id
