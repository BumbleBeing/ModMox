class_name MmZone
extends RefCounted
## A zone (CR 400): an ordered collection of Game Objects. Index 0 is the top of a library
## and the first object of any other zone, except the stack, whose top is its last object. Every zone keeps a stable order so that views
## and replays are consistent; the GUI may display a hand in its own order.

enum Kind { LIBRARY, HAND, GRAVEYARD, BATTLEFIELD, STACK, EXILE, COMMAND }

## Owner ID of a shared zone (battlefield, stack, exile, command).
const NO_OWNER: int = -1
## Insert position meaning "after the last object" (the bottom of a library).
const BOTTOM: int = -1

var kind: Kind
var owner_id: int
var _objects: Array[MmGameObject] = []


func _init(zone_kind: Kind, zone_owner_id: int = NO_OWNER) -> void:
	kind = zone_kind
	owner_id = zone_owner_id


func size() -> int:
	return _objects.size()


func is_empty() -> bool:
	return _objects.is_empty()


## A copy of the objects in order, first (top) object first.
func objects() -> Array[MmGameObject]:
	return _objects.duplicate()


## The IDs of the objects in order, first (top) object first.
func object_ids() -> Array[int]:
	var result: Array[int] = []
	for object: MmGameObject in _objects:
		result.append(object.id)
	return result


## The first (top) object, or null if the zone is empty.
func top() -> MmGameObject:
	return null if _objects.is_empty() else _objects[0]


func has(object: MmGameObject) -> bool:
	return _objects.has(object)


## A short description for logs and debugging, such as "library of player 0".
func describe() -> String:
	return describe_zone(kind, owner_id)


## Describes the zone of [param zone_kind] owned by [param zone_owner_id].
static func describe_zone(zone_kind: Kind, zone_owner_id: int) -> String:
	var kind_name: String = Kind.find_key(zone_kind).to_lower()
	return kind_name if zone_owner_id == NO_OWNER else "%s of player %d" % [kind_name, zone_owner_id]


## Event-only: puts [param object] at [param position] (0 = top, BOTTOM = last).
func insert(object: MmGameObject, position: int) -> void:
	assert(object.zone() == null, "An object can only be in one zone.")
	if position == BOTTOM or position >= _objects.size():
		_objects.append(object)
	else:
		_objects.insert(position, object)
	object.attach_to_zone(self)


## Event-only: takes [param object] out of this zone.
func remove(object: MmGameObject) -> void:
	assert(_objects.has(object), "Object %d is not in the %s." % [object.id, describe()])
	_objects.erase(object)
	object.attach_to_zone(null)


## Event-only: replaces the order of the objects with [param ordered], which must hold
## exactly the same objects.
func reorder(ordered: Array[MmGameObject]) -> void:
	assert(ordered.size() == _objects.size(), "Reordering must keep the same objects.")
	for object: MmGameObject in ordered:
		assert(_objects.has(object), "Reordering must keep the same objects.")
	_objects = ordered.duplicate()
