class_name EntersTappedReplacementEffect
extends MmReplacementEffect
## What EntersTappedAbility generates for its own permanent: it enters the battlefield
## tapped instead (CR 614.1c). A move that already puts it there tapped is left alone, so
## two of these never need ordering and none applies twice.


func applies_to(state: MmGameState, event: MmEvent, active: ActiveReplacementEffect) -> bool:
	var entering: ZoneChangeEvent = event as ZoneChangeEvent
	if entering == null or entering.to_zone_kind != MmZone.Kind.BATTLEFIELD or entering.tapped_on_arrival:
		return false
	return state.object(entering.object_id) != null and active.is_locked_to(MmReference.to_object(entering.object_id))


func replace(state: MmGameState, event: MmEvent, _active: ActiveReplacementEffect) -> Array[MmEvent]:
	var tapped: ZoneChangeEvent = (event as ZoneChangeEvent).copy(state)
	tapped.tapped_on_arrival = true
	return [tapped]


func describe() -> String:
	return "enters tapped"
