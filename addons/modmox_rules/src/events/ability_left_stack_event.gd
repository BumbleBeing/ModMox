class_name AbilityLeftStackEvent
extends MmEvent
## An ability on the stack finishes resolving, or fails to, and stops existing (CR 608.2n).

var object_id: int
var did_resolve: bool


func _init(ability_object_id: int, resolved: bool) -> void:
	object_id = ability_object_id
	did_resolve = resolved


func apply(state: MmGameState) -> void:
	var leaving: MmGameObject = state.object(object_id)
	state.stack.remove(leaving)
	state.retire_object(leaving)


func describe() -> String:
	return "ABILITY LEFT STACK: object %d (%s)" % [object_id, "resolved" if did_resolve else "did not resolve"]
