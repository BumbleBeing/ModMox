class_name AbilityLeftStackEvent
extends MmEvent
## An ability on the stack finishes resolving, fails to, or is countered, and stops
## existing (CR 608.2n, 701.6a).

var object_id: int
var did_resolve: bool
var was_countered: bool


func _init(ability_object_id: int, resolved: bool, countered: bool = false) -> void:
	object_id = ability_object_id
	did_resolve = resolved
	was_countered = countered


func apply(state: MmGameState) -> void:
	var leaving: MmGameObject = state.object(object_id)
	state.stack.remove(leaving)
	state.retire_object(leaving)


func describe() -> String:
	return "ABILITY LEFT STACK: object %d (%s)" % [object_id, "countered" if was_countered else ("resolved" if did_resolve else "did not resolve")]
