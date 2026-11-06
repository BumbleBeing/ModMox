class_name MmEffectContext
extends RefCounted
## Who and what an effect is resolving for: the controller of the ability and its source.

var controller_id: int
var source_object_id: int


func _init(controlling_player_id: int, source_id: int) -> void:
	controller_id = controlling_player_id
	source_object_id = source_id
