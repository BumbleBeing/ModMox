class_name BecomesTappedTrigger
extends MmTrigger
## "Whenever [filter] [whose] becomes tapped" (CR 603.2): a permanent changing from untapped
## to tapped, for any reason, such as attacking (CR 508.1f), paying a {T} cost or an effect.
## It matches a TapEvent, which only ever taps an untapped permanent. A permanent that
## enters the battlefield tapped never becomes tapped: it arrives tapped on its zone change
## (ADR 0008), with no TapEvent. "That creature" is the tapped permanent, and "that player"
## its controller.

## Null matches any permanent.
@export var filter: MmFilter = null
## Compared with the tapped permanent's controller.
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var tapped: TapEvent = event as TapEvent
	if tapped == null:
		return false
	var permanent: MmGameObject = state.object(tapped.object_id)
	if permanent == null or not is_whose(whose, permanent.controller_id, context):
		return false
	return filter == null or filter.matches(state, MmReference.to_object(tapped.object_id), context)


func triggering_player_id(state: MmGameState, event: MmEvent) -> int:
	var permanent: MmGameObject = state.object_or_last_known(triggering_object_id(event))
	return MmGameState.NO_PLAYER if permanent == null else permanent.controller_id


func triggering_object_id(event: MmEvent) -> int:
	var tapped: TapEvent = event as TapEvent
	return 0 if tapped == null else tapped.object_id
