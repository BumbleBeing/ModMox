extends MmAgent
## A test Agent that answers the Hero's first spell with a spell of its own, once, and
## otherwise plays like Scenario.autoplay().

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")

var responses_left: int = 1


func answer(decision: MmPendingDecision, view: MmPlayerView, _source: MmSimulationSource) -> Variant:
	var priority: PriorityDecision = decision as PriorityDecision
	if priority != null and responses_left > 0 and not view.stack.is_empty() and view.stack.back().controller_id != view.viewer_id:
		for index: int in priority.actions.size():
			if priority.actions[index] is CastSpellAction:
				responses_left -= 1
				return index
	return Scenario.default_answer(decision, false)
