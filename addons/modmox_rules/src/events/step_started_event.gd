class_name StepStartedEvent
extends MmEvent
## A step (or main phase) of the current turn begins (CR 500.1).

var step: MmTurn.Step


func _init(started_step: MmTurn.Step) -> void:
	step = started_step


func apply(state: MmGameState) -> void:
	state.step = step


func describe() -> String:
	return "STEP STARTED: %s" % MmTurn.Step.find_key(step)
