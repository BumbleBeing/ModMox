class_name ZoneChangeTrigger
extends MmTrigger
## "Whenever a [filter] [whose] is put into [to zone] from [from zone]", which covers
## "enters the battlefield", "dies" (battlefield to graveyard, CR 700.4) and, with any
## destination, "leaves the battlefield" (CR 603.6c). The Filter and whose see the object as
## it was before it moved when it left the battlefield, and as it is now otherwise. "That
## creature" is the moving object, as it was before it moved. A token created on the
## battlefield enters it from no zone (CR 111.2, 603.6a), so it is seen only by a trigger
## that takes any zone it came from.
## With [member is_except_to_zone] it is a move to any zone but [member to_zone]: from the
## battlefield, all but the graveyard is "leaves the battlefield without dying" (CR 700.4), as
## Dour Port-Mage says. With [member is_one_or_more] it is "Whenever one or more [filter]
## ...": every matching move of one batch is one occasion, so it triggers once for all of
## them (occasion_of(), engine ADR 0082's addendum), and "that creature" is the first.

@export var any_from_zone: bool = true
@export var from_zone: MmZone.Kind = MmZone.Kind.BATTLEFIELD
## True for a move to any zone, when [member to_zone] is not read.
@export var any_to_zone: bool = false
@export var to_zone: MmZone.Kind = MmZone.Kind.BATTLEFIELD
## True for a move to any zone but [member to_zone].
@export var is_except_to_zone: bool = false
## True for "one or more": once for each batch, however many moves of it match.
@export var is_one_or_more: bool = false
## Null matches any object.
@export var filter: MmFilter = null
## Compared with the object's controller (its owner outside the battlefield and stack).
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var created: TokenCreatedEvent = event as TokenCreatedEvent
	if created != null:
		if created.new_object_id == 0:
			return false  # CR 303.4g: no token was created.
		return any_from_zone and _goes_to(MmZone.Kind.BATTLEFIELD) and _matches_object(state, created.new_object_id, context)
	var moved: ZoneChangeEvent = event as ZoneChangeEvent
	if moved == null or not _goes_to(moved.to_zone_kind):
		return false
	if not any_from_zone and moved.from_zone_kind != from_zone:
		return false
	return _matches_object(state, _seen_object_id(moved), context)


func looks_back() -> bool:
	return not any_from_zone and from_zone == MmZone.Kind.BATTLEFIELD


func occasion_of(_state: MmGameState, _event: MmEvent) -> String:
	return "one or more" if is_one_or_more else ""


func triggering_object_id(event: MmEvent) -> int:
	if event is TokenCreatedEvent:
		return (event as TokenCreatedEvent).new_object_id
	var moved: ZoneChangeEvent = event as ZoneChangeEvent
	return 0 if moved == null else _seen_object_id(moved)


func triggering_player_id(state: MmGameState, event: MmEvent) -> int:
	var seen: MmGameObject = state.object_or_last_known(triggering_object_id(event))
	return MmGameState.NO_PLAYER if seen == null else seen.controller_id


## Whether a move to [param zone_kind] is one this trigger waits for.
func _goes_to(zone_kind: MmZone.Kind) -> bool:
	return any_to_zone or (zone_kind == to_zone) != is_except_to_zone


## CR 603.10a and 603.6a: the object as it was on the battlefield when it left it, and the
## new object otherwise.
func _seen_object_id(moved: ZoneChangeEvent) -> int:
	return moved.object_id if moved.from_zone_kind == MmZone.Kind.BATTLEFIELD else moved.new_object_id


func _matches_object(state: MmGameState, seen_id: int, context: MmEffectContext) -> bool:
	var seen: MmGameObject = state.object_or_last_known(seen_id)
	if seen == null or not is_whose(whose, seen.controller_id, context):
		return false
	return filter == null or filter.matches(state, MmReference.to_object(seen_id), context)
