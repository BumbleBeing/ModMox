class_name DamageRemovedEvent
extends MmEvent
## All damage marked on a permanent is removed, as in the cleanup step (CR 514.2).

var object_id: int
## How much damage was removed, set when the event is applied.
var amount: int = 0


func _init(damaged_object_id: int) -> void:
	object_id = damaged_object_id


func apply(state: MmGameState) -> void:
	var damaged: MmGameObject = state.object(object_id)
	amount = damaged.damage_marked
	damaged.remove_damage()


func describe() -> String:
	return "DAMAGE REMOVED: %d from object %d" % [amount, object_id]
