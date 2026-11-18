class_name TokenCeasedEvent
extends MmEvent
## A token that is anywhere but the battlefield ceases to exist (CR 704.5d). It goes to no
## zone and nothing replaces it.

var object_id: int
var zone_kind: MmZone.Kind
var zone_owner_id: int


func _init(token: MmGameObject) -> void:
	object_id = token.id
	zone_kind = token.zone().kind
	zone_owner_id = token.zone().owner_id


func apply(state: MmGameState) -> void:
	var token: MmGameObject = state.object(object_id)
	assert(token != null and token.is_token, "Object %d is not a token." % object_id)
	state.zone(zone_kind, zone_owner_id).remove(token)
	state.retire_object(token)


func describe() -> String:
	return "TOKEN CEASED: object %d" % object_id
