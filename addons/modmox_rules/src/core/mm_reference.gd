class_name MmReference
extends RefCounted
## A player or a Game Object, as chosen for a target or found by a Selection. Never
## changes once made, so it is safe to share.

enum Kind { PLAYER, OBJECT }

var kind: Kind
var id: int


func _init(reference_kind: Kind, reference_id: int) -> void:
	kind = reference_kind
	id = reference_id


static func to_player(player_id: int) -> MmReference:
	return MmReference.new(Kind.PLAYER, player_id)


static func to_object(object_id: int) -> MmReference:
	return MmReference.new(Kind.OBJECT, object_id)


func is_player() -> bool:
	return kind == Kind.PLAYER


func is_object() -> bool:
	return kind == Kind.OBJECT


func equals(other: MmReference) -> bool:
	return other != null and other.kind == kind and other.id == id


func describe() -> String:
	return "%s %d" % ["player" if is_player() else "object", id]
