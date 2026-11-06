class_name RegenerationReplacementEffect
extends MmReplacementEffect
## A regeneration shield (CR 701.19a): the next time the permanent would be destroyed this
## turn, instead tap it, remove all damage from it and remove it from combat. It never
## replaces a creature dying from 0 toughness, which is not destruction (CR 704.5f), nor a
## destruction that says it can't be regenerated (CR 701.19c).


func applies_to(state: MmGameState, event: MmEvent, active: ActiveReplacementEffect) -> bool:
	var destroy: ZoneChangeEvent = event as ZoneChangeEvent
	if destroy == null or destroy.reason != ZoneChangeEvent.Reason.DESTROY or not destroy.can_be_regenerated:
		return false
	if destroy.from_zone_kind != MmZone.Kind.BATTLEFIELD or active.remaining == 0:
		return false
	return state.object(destroy.object_id) != null and active.is_locked_to(MmReference.to_object(destroy.object_id))


func replace(state: MmGameState, event: MmEvent, active: ActiveReplacementEffect) -> Array[MmEvent]:
	var permanent: MmGameObject = state.object((event as ZoneChangeEvent).object_id)
	var events: Array[MmEvent] = [RegeneratedEvent.new(permanent.id, active.timestamp)]
	if not permanent.is_tapped:
		events.append(TapEvent.new(permanent.id))  # Already tapped, it simply stays tapped (A150).
	if state.combat.is_attacking(permanent.id) or state.combat.is_blocking(permanent.id):
		events.append(RemovedFromCombatEvent.new(permanent.id))
	return events


func describe() -> String:
	return "regenerate"
