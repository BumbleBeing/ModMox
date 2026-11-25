class_name CopyCeasedEvent
extends MmEvent
## A copy of a spell that is anywhere but the stack ceases to exist (CR 704.5e, 707.10a), as
## one does once it is countered or, for an instant or sorcery, once it resolves. It goes to
## no zone and nothing replaces it.

var object_id: int
var zone_kind: MmZone.Kind
var zone_owner_id: int


func _init(copy: MmGameObject) -> void:
	object_id = copy.id
	zone_kind = copy.zone().kind
	zone_owner_id = copy.zone().owner_id


func apply(state: MmGameState) -> void:
	var copy: MmGameObject = state.object(object_id)
	assert(copy != null and copy.is_copy, "Object %d is not a copy of a spell." % object_id)
	state.zone(zone_kind, zone_owner_id).remove(copy)
	state.retire_object(copy)


func describe() -> String:
	return "COPY CEASED: object %d" % object_id
