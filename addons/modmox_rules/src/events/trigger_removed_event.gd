class_name TriggerRemovedEvent
extends MmEvent
## A pending trigger with no legal target for one of its requirements is removed instead of
## being put on the stack (CR 603.3d).

var pending: PendingTrigger


func _init(triggered: PendingTrigger) -> void:
	pending = triggered


func apply(state: MmGameState) -> void:
	state.remove_pending_trigger(pending)


func describe() -> String:
	return "TRIGGER REMOVED: " + pending.describe()
