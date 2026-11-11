extends MmAgent
## A test Agent that takes its time, like a Normal AI, and remembers which thread asked it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")

var delay_msec: int = 300
## The thread answer() last ran on.
var thread_id: int = -1


func answer(decision: MmPendingDecision, _view: MmPlayerView, _source: MmSimulationSource) -> Variant:
	thread_id = OS.get_thread_caller_id()
	OS.delay_msec(delay_msec)
	return Scenario.default_answer(decision, true)
