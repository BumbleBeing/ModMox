extends MmAgent
## A test Agent that answers like Scenario.autoplay(): keeps, plays the first land offered,
## and otherwise passes, never attacks or blocks.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")

## Answers given so far, for tests that check the driver used this Agent.
var answers_given: int = 0


func answer(decision: MmPendingDecision, _view: MmPlayerView, _source: MmSimulationSource) -> Variant:
	answers_given += 1
	return Scenario.default_answer(decision, true)
