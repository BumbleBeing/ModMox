class_name EntersWithCountersReplacementEffect
extends MmReplacementEffect
## What EntersWithCountersAbility generates for its own permanent: it enters the battlefield
## with [member amount] more [member kind] counters on it (CR 614.1c, 122.6). Once applied to
## an entering it is not applied to it again (CR 616.2).

var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
## Card data, never changed. Worked out with the entering object as the source.
var amount: MmValue


func applies_to(state: MmGameState, event: MmEvent, active: ActiveReplacementEffect) -> bool:
	var entering: ZoneChangeEvent = event as ZoneChangeEvent
	if entering == null or entering.to_zone_kind != MmZone.Kind.BATTLEFIELD:
		return false
	return state.object(entering.object_id) != null and active.is_locked_to(MmReference.to_object(entering.object_id))


func replace(state: MmGameState, event: MmEvent, _active: ActiveReplacementEffect) -> Array[MmEvent]:
	var entering: ZoneChangeEvent = event as ZoneChangeEvent
	var moving: MmGameObject = state.object(entering.object_id)
	var more: int = maxi(0, amount.evaluate(state, MmEffectContext.new(moving.controller_id, moving.id)))
	var with_counters: ZoneChangeEvent = entering.copy(state)
	with_counters.counters_on_arrival = entering.counters_on_arrival.duplicate()
	with_counters.counters_on_arrival[kind] = with_counters.counters_on_arrival.get(kind, 0) + more
	return [with_counters]


func content_key() -> String:
	return "enters with %d %s" % [kind, content_of(amount)]


func describe() -> String:
	return "enters with counters"
