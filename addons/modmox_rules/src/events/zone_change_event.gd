class_name ZoneChangeEvent
extends MmEvent
## A card moves from one zone to another and becomes a new Game Object (CR 400.7, ADR 0008).
## Zones are named by kind and owner rather than referenced, so the event stays plain data
## that a copied game state can share.

## Only ever add values at the end, so saved event histories keep their meaning.
## DESTROY is CR 701.8 (indestructible and regeneration care); ZERO_TOUGHNESS is CR 704.5f,
## which is not destruction.
enum Reason { DRAW, MULLIGAN, PUT_ON_BOTTOM, DISCARD, PLAY_LAND, CAST, RESOLVED, DID_NOT_RESOLVE, DESTROY, ZERO_TOUGHNESS }

## The object leaving. It stops existing once this event is applied.
var object_id: int
var card_id: int
var from_zone_kind: MmZone.Kind
var from_owner_id: int
var to_zone_kind: MmZone.Kind
var to_owner_id: int
## Position in the destination: 0 for the top, MmZone.BOTTOM for after the last object.
var position: int
var reason: Reason
## The new object's ID, set when the event is applied.
var new_object_id: int = 0
## For an object leaving the battlefield: its characteristics as it last existed there,
## set when the event is applied (CR 608.2h).
var last_known: MmCharacteristics = null


func _init(leaving: MmGameObject, destination: MmZone, at_position: int, why: Reason) -> void:
	object_id = leaving.id
	card_id = leaving.card_id
	from_zone_kind = leaving.zone().kind
	from_owner_id = leaving.zone().owner_id
	to_zone_kind = destination.kind
	to_owner_id = destination.owner_id
	position = at_position
	reason = why


func apply(state: MmGameState) -> void:
	var from_zone: MmZone = state.zone(from_zone_kind, from_owner_id)
	var to_zone: MmZone = state.zone(to_zone_kind, to_owner_id)
	var leaving: MmGameObject = state.object(object_id)
	assert(leaving != null and leaving.zone() == from_zone, "Object %d is no longer in the %s." % [object_id, from_zone.describe()])
	if from_zone_kind == MmZone.Kind.BATTLEFIELD:
		# CR 608.2h: keep what it last looked like, for look-back triggers and "its power".
		last_known = state.characteristics_of(leaving)
		leaving.freeze_last_known(last_known)
		state.record_departure(leaving)
	from_zone.remove(leaving)
	state.retire_object(leaving)
	var arriving: MmGameObject = state.create_object(leaving.card_id, leaving.owner_id, leaving.definition)
	to_zone.insert(arriving, position)
	new_object_id = arriving.id
	if to_zone_kind == MmZone.Kind.BATTLEFIELD:
		# CR 302.6: summoning sickness counts from when its controller began controlling it.
		arriving.record_control_since(state.game_turn)
	if reason == Reason.PLAY_LAND:
		state.player(arriving.controller_id).record_land_play()


func describe() -> String:
	return "%s: object %d (card %d) from %s to %s as object %d" % [
		Reason.find_key(reason), object_id, card_id,
		MmZone.describe_zone(from_zone_kind, from_owner_id), MmZone.describe_zone(to_zone_kind, to_owner_id), new_object_id]
