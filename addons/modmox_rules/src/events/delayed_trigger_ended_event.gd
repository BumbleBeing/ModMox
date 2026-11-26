class_name DelayedTriggerEndedEvent
extends MmEvent
## A delayed triggered ability has triggered, and it is gone: it triggers only once
## (CR 603.7c, engine ADR 0103).

var delayed: DelayedTrigger


func _init(ended: DelayedTrigger) -> void:
	delayed = ended


func apply(state: MmGameState) -> void:
	state.remove_delayed_trigger(delayed)


func describe() -> String:
	return "DELAYED TRIGGER ENDED: " + delayed.describe()
