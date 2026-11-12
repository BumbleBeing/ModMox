class_name AutoPass
extends RefCounted
## When the Encounter Presenter passes priority for the Hero. With auto-pass on, the Hero is
## asked only on a step that has a stop and where they could cast, play or activate
## something, or when the other player's spell or ability is on top of the stack.


## Whether auto-pass passes [param decision] for the player whose [param view] this is.
static func passes(decision: MmPendingDecision, view: MmPlayerView, stops: StepStops) -> bool:
	var priority: PriorityDecision = decision as PriorityDecision
	if priority == null:
		return false
	if not view.stack.is_empty() and view.stack.back().controller_id != view.viewer_id:
		return false
	if not stops.has_stop(view.active_player_id, view.step):
		return true
	return not has_plays(priority, view)


## Whether a Yield (game glossary) passes [param decision]: every priority, whatever is on
## the stack and whatever the stops say. Choosing attackers or blockers, and any other
## choice that is not priority, is the Hero's to make.
static func yields(decision: MmPendingDecision) -> bool:
	return decision is PriorityDecision


## Whether [param decision] offers anything besides passing and mana abilities. Tapping a
## land for mana with nothing to spend it on is never a reason to stop.
static func has_plays(decision: PriorityDecision, view: MmPlayerView) -> bool:
	for action: MmAction in decision.actions:
		if not (action is PassAction) and not is_mana_ability(action, view):
			return true
	return false


## Whether [param action] activates a mana ability, worked out from [param view] alone.
static func is_mana_ability(action: MmAction, view: MmPlayerView) -> bool:
	var activate: ActivateAbilityAction = action as ActivateAbilityAction
	if activate == null:
		return false
	for permanent: MmObjectView in view.battlefield:
		if permanent.id == activate.object_id and activate.ability_index < permanent.abilities.size():
			var ability: ActivatedAbility = permanent.abilities[activate.ability_index] as ActivatedAbility
			return ability != null and ability.is_mana_ability()
	return false


## The index of passing in [param decision]'s actions.
static func pass_index(decision: PriorityDecision) -> int:
	for index: int in decision.actions.size():
		if decision.actions[index] is PassAction:
			return index
	return 0


## Whether the top of the stack in [param view] belongs to the viewer.
static func is_own_object_on_top(view: MmPlayerView) -> bool:
	return not view.stack.is_empty() and view.stack.back().controller_id == view.viewer_id
