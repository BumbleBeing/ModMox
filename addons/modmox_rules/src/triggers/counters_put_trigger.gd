class_name CountersPutTrigger
extends MmTrigger
## "Whenever one or more [kind] counters are put on [filter] [whose]" (CR 122.6, 603.2), as
## Dusk Legion Duelist's "Whenever one or more +1/+1 counters are put on this creature". It
## matches a CountersPutEvent of [member kind], which an effect performs once for each
## permanent it puts counters on, however many go there, so it triggers once for each
## permanent each effect reaches. A permanent that enters with counters had them put on it
## too (CR 122.6), so its arrival matches as well, and its own ability sees it, as an
## "enters" ability does (CR 603.6a). "That creature" is the permanent, and "that player" its
## controller.

## Which counters count.
@export var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
## Null matches any permanent.
@export var filter: MmFilter = null
## Compared with the controller of the permanent the counters are put on.
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var permanent_id: int = triggering_object_id(event)
	var permanent: MmGameObject = state.object(permanent_id) if permanent_id != 0 else null
	if permanent == null or not is_whose(whose, permanent.controller_id, context):
		return false
	return filter == null or filter.matches(state, MmReference.to_object(permanent_id), context)


func triggering_player_id(state: MmGameState, event: MmEvent) -> int:
	var permanent: MmGameObject = state.object_or_last_known(triggering_object_id(event))
	return MmGameState.NO_PLAYER if permanent == null else permanent.controller_id


func triggering_object_id(event: MmEvent) -> int:
	var put: CountersPutEvent = event as CountersPutEvent
	if put != null:
		return put.object_id if put.kind == kind and put.amount > 0 else 0
	# CR 122.6: entering with counters is having them put on it.
	var entering: ZoneChangeEvent = event as ZoneChangeEvent
	if entering != null and entering.to_zone_kind == MmZone.Kind.BATTLEFIELD and entering.counters_on_arrival.get(kind, 0) > 0:
		return entering.new_object_id
	return 0
