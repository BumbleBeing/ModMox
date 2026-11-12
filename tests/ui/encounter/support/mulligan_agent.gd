extends MmAgent
## A test Agent that mulligans a set number of times before keeping, and otherwise answers
## like Scenario.autoplay().

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")

## How many more times it will mulligan.
var mulligans: int = 1


func answer(decision: MmPendingDecision, _view: MmPlayerView, _source: MmSimulationSource) -> Variant:
	if decision is KeepOrMulliganDecision and mulligans > 0:
		mulligans -= 1
		return KeepOrMulliganDecision.Choice.MULLIGAN
	return Scenario.default_answer(decision, true)
