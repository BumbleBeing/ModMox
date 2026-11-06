class_name AbilityTriggeredEvent
extends MmEvent
## A triggered ability triggers and waits to be put on the stack (CR 603.2).

var pending: PendingTrigger


func _init(triggered: PendingTrigger) -> void:
	pending = triggered


func apply(state: MmGameState) -> void:
	state.add_pending_trigger(pending)


func describe() -> String:
	return "TRIGGERED: " + pending.describe()
