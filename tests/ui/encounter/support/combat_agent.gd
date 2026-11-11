extends MmAgent
## A test Agent that fights: it casts up to [member casts_left] creatures, attacks with
## everything, and blocks the first attacker with every creature that can. Otherwise it
## plays like Scenario.autoplay().

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")

var casts_left: int = 2


func answer(decision: MmPendingDecision, view: MmPlayerView, _source: MmSimulationSource) -> Variant:
	if decision is PriorityDecision and casts_left > 0 and view.stack.is_empty():
		var actions: Array[MmAction] = (decision as PriorityDecision).actions
		for index: int in actions.size():
			if actions[index] is CastSpellAction:
				casts_left -= 1
				return index
	if decision is DeclareAttackersDecision:
		return (decision as DeclareAttackersDecision).candidate_ids.duplicate()
	if decision is DeclareBlockersDecision:
		var blocks: DeclareBlockersDecision = decision as DeclareBlockersDecision
		var pairs: Array = []
		for blocker_id: int in blocks.candidate_blocker_ids:
			if (blocks.blockable_by_blocker[blocker_id] as Array).has(blocks.attacker_ids[0]):
				pairs.append([blocker_id, blocks.attacker_ids[0]])
		return pairs
	return Scenario.default_answer(decision, false)
