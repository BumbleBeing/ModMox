class_name BecomesTargetTrigger
extends MmTrigger
## "Whenever [filter] becomes the target of a spell or ability [whose] controls" (CR 115.1,
## 603.2), as ward is (CR 702.21a). It triggers as each target is chosen, while the spell or
## ability is being put on the stack, and goes on the stack once it is (CR 603.3). "That
## player" is the controller of the spell or ability, and "it" the spell or ability.
# Later: a permanent made the target of one spell twice, through two "target" words, becomes
# its target once; it triggers twice here. Once a card can aim one spell at one object twice.

## Null matches anything that becomes a target, a player included.
@export var filter: MmFilter = null
## Compared with the controller of the spell or ability.
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var chosen: TargetChosenEvent = event as TargetChosenEvent
	if chosen == null or chosen.target == null:
		return false
	var targeting: MmGameObject = state.object(chosen.object_id)
	if targeting == null or not is_whose(whose, targeting.controller_id, context):
		return false
	return filter == null or filter.matches(state, chosen.target, context)


func triggering_player_id(state: MmGameState, event: MmEvent) -> int:
	var targeting: MmGameObject = state.object((event as TargetChosenEvent).object_id)
	return MmGameState.NO_PLAYER if targeting == null else targeting.controller_id


func triggering_object_id(event: MmEvent) -> int:
	var chosen: TargetChosenEvent = event as TargetChosenEvent
	return 0 if chosen == null else chosen.object_id
