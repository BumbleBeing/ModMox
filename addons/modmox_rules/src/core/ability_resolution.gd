class_name AbilityResolution
extends RefCounted
## One time an ability resolved this turn (ADR 0056): the object it came from, by ID, and
## its place among that object's abilities. Never changes once made, so copies of the state
## share it.

var source_object_id: int
var ability_index: int


func _init(source_id: int, index: int) -> void:
	source_object_id = source_id
	ability_index = index


## Whether this was a resolution of ability [param index] of the object [param source_id].
func is_of(source_id: int, index: int) -> bool:
	return source_object_id == source_id and ability_index == index


func describe() -> String:
	return "ability %d of object %d" % [ability_index, source_object_id]
