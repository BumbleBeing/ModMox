class_name ZoneChangeEvent
extends MmEvent
## A card moves from one zone to another and becomes a new Game Object (CR 400.7, ADR 0008).

enum Reason { DRAW, MULLIGAN, PUT_ON_BOTTOM, DISCARD, PLAY_LAND }

## The object leaving. It stops existing once this event is applied.
var object_id: int
var card_id: int
var from_zone: MmZone
var to_zone: MmZone
## Position in [member to_zone]: 0 for the top, MmZone.BOTTOM for after the last object.
var position: int
var reason: Reason
## The new object's ID, set when the event is applied.
var new_object_id: int = 0


func _init(leaving: MmGameObject, destination: MmZone, at_position: int, why: Reason) -> void:
	object_id = leaving.id
	card_id = leaving.card_id
	from_zone = leaving.zone()
	to_zone = destination
	position = at_position
	reason = why


func apply(state: MmGameState) -> void:
	var leaving: MmGameObject = state.object(object_id)
	assert(leaving != null and leaving.zone() == from_zone, "Object %d is no longer in the %s." % [object_id, from_zone.describe()])
	from_zone.remove(leaving)
	state.retire_object(leaving)
	var arriving: MmGameObject = state.create_object(leaving.card_id, leaving.owner_id, leaving.definition)
	to_zone.insert(arriving, position)
	new_object_id = arriving.id
	if reason == Reason.PLAY_LAND:
		state.player(arriving.controller_id).record_land_play()


func describe() -> String:
	return "%s: object %d (card %d) from %s to %s as object %d" % [
		Reason.find_key(reason), object_id, card_id, from_zone.describe(), to_zone.describe(), new_object_id]
