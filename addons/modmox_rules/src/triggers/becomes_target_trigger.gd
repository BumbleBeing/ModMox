class_name BecomesTargetTrigger
extends MmTrigger
## "Whenever [filter] becomes the target of a spell or ability [whose] controls" (CR 115.1,
## 603.2), as ward is (CR 702.21a). It triggers as each target is chosen, while the spell or
## ability is being put on the stack, and goes on the stack once it is (CR 603.3). "That
## player" is the controller of the spell or ability, and "it" the spell or ability. With
## [member is_spells_only] it is "Whenever [filter] becomes the target of a spell", as
## Bonecrusher Giant says: an activated or triggered ability never triggers it.
# Later: a permanent made the target of one spell twice, through two "target" words, becomes
# its target once; it triggers twice here. Once a card can aim one spell at one object twice.

## Null matches anything that becomes a target, a player included.
@export var filter: MmFilter = null
## Compared with the controller of the spell or ability.
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY
## "Of a spell" only (CR 112.1): a card or a copy of one on the stack, never an ability.
@export var is_spells_only: bool = false


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var chosen: TargetChosenEvent = event as TargetChosenEvent
	if chosen == null or chosen.target == null:
		return false
	var targeting: MmGameObject = state.object(chosen.object_id)
	if targeting == null or not is_whose(whose, targeting.controller_id, context):
		return false
	if is_spells_only and not targeting.is_card_or_copy():
		return false
	return filter == null or filter.matches(state, chosen.target, context)


func triggering_player_id(state: MmGameState, event: MmEvent) -> int:
	var targeting: MmGameObject = state.object((event as TargetChosenEvent).object_id)
	return MmGameState.NO_PLAYER if targeting == null else targeting.controller_id


func triggering_object_id(event: MmEvent) -> int:
	var chosen: TargetChosenEvent = event as TargetChosenEvent
	return 0 if chosen == null else chosen.object_id
