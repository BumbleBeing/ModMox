class_name MmObjectView
extends RefCounted
## What a player can see of one Game Object they are allowed to see.

var id: int
var name: String


func _init(object_id: int, object_name: String) -> void:
	id = object_id
	name = object_name
