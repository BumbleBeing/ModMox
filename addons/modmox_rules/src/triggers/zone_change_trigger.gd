class_name ZoneChangeTrigger
extends MmTrigger
## "Whenever a [filter] [whose] is put into [to zone] from [from zone]", which covers
## "enters the battlefield" and "dies" (battlefield to graveyard, CR 700.4). The Filter and
## whose see the object as it was before it moved when it left the battlefield, and as it
## is now otherwise. "That creature" is the moving object, as it was before it moved.

@export var any_from_zone: bool = true
@export var from_zone: MmZone.Kind = MmZone.Kind.BATTLEFIELD
@export var to_zone: MmZone.Kind = MmZone.Kind.BATTLEFIELD
## Null matches any object.
@export var filter: MmFilter = null
## Compared with the object's controller (its owner outside the battlefield and stack).
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var moved: ZoneChangeEvent = event as ZoneChangeEvent
	if moved == null or moved.to_zone_kind != to_zone:
		return false
	if not any_from_zone and moved.from_zone_kind != from_zone:
		return false
	var seen_id: int = _seen_object_id(moved)
	var seen: MmGameObject = state.object_or_last_known(seen_id)
	if seen == null or not is_whose(whose, seen.controller_id, context):
		return false
	return filter == null or filter.matches(state, MmReference.to_object(seen_id), context)


func looks_back() -> bool:
	return not any_from_zone and from_zone == MmZone.Kind.BATTLEFIELD


func triggering_object_id(event: MmEvent) -> int:
	var moved: ZoneChangeEvent = event as ZoneChangeEvent
	return 0 if moved == null else _seen_object_id(moved)


func triggering_player_id(state: MmGameState, event: MmEvent) -> int:
	var seen: MmGameObject = state.object_or_last_known(triggering_object_id(event))
	return MmGameState.NO_PLAYER if seen == null else seen.controller_id


## CR 603.10a and 603.6a: the object as it was on the battlefield when it left it, and the
## new object otherwise.
func _seen_object_id(moved: ZoneChangeEvent) -> int:
	return moved.object_id if moved.from_zone_kind == MmZone.Kind.BATTLEFIELD else moved.new_object_id
