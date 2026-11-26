class_name DelayedTriggerCreatedEvent
extends MmEvent
## A delayed triggered ability is created, to trigger the next time its event happens
## (CR 603.7, engine ADR 0103).

var delayed: DelayedTrigger


func _init(created: DelayedTrigger) -> void:
	delayed = created


func apply(state: MmGameState) -> void:
	state.add_delayed_trigger(delayed)


func describe() -> String:
	return "DELAYED TRIGGER CREATED: " + delayed.describe()
