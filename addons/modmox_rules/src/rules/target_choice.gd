class_name TargetChoice
extends RefCounted
## Choosing the targets of one target requirement as a spell or ability is put on the stack
## (CR 601.2c, 603.3d), shared by casting, activating and stacking triggers. A plain
## requirement asks for one target; an "up to" one asks for any number up to its most, and
## is not asked at all with nothing to choose. Each target chosen goes in its own place in
## the stack object's targets (ADR 0014).


## The decision for requirement [param index] of [param requirements], or null when it is
## "up to" and there is nothing to choose, which chooses none.
static func decision_for(state: MmGameState, player_id: int, stack_object_id: int,
		requirements: Array[TargetRequirement], index: int, context: MmEffectContext) -> MmPendingDecision:
	var requirement: TargetRequirement = requirements[index]
	var legal: Array[MmReference] = requirement.legal_targets(state, context)
	requirement.place_count()  # Asserts the requirement is one the engine can choose for.
	if not requirement.is_up_to:
		return ChooseTargetDecision.new(player_id, stack_object_id, index, legal)
	if legal.is_empty():
		return null
	return ChooseTargetsDecision.new(player_id, stack_object_id, index, legal, requirement.most)


## Performs the choice an already-validated [param answer] to [param decision] makes, one
## TargetChosenEvent for each target, each in its own place.
static func perform_answer(state: MmGameState, decision: MmPendingDecision, answer: Variant,
		requirements: Array[TargetRequirement]) -> void:
	var single: ChooseTargetDecision = decision as ChooseTargetDecision
	if single != null:
		var place: int = TargetRequirement.first_place(requirements, single.target_index)
		state.perform(TargetChosenEvent.new(single.stack_object_id, place, single.candidates[answer as int]))
		return
	var several: ChooseTargetsDecision = decision as ChooseTargetsDecision
	var first: int = TargetRequirement.first_place(requirements, several.target_index)
	var chosen: Array = answer
	for place: int in chosen.size():
		state.perform(TargetChosenEvent.new(several.stack_object_id, first + place, several.candidates[chosen[place] as int]))
