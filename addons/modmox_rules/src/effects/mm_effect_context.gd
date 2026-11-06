class_name MmEffectContext
extends RefCounted
## Who and what an effect is resolving for: the controller of the spell or ability, its
## source, and its targets.

var controller_id: int
var source_object_id: int
## The chosen target of each target requirement, in order. An entry is null when that
## target was illegal on resolution (CR 608.2b).
var targets: Array[MmReference] = []


func _init(controlling_player_id: int, source_id: int, chosen_targets: Array[MmReference] = []) -> void:
	controller_id = controlling_player_id
	source_object_id = source_id
	targets = chosen_targets.duplicate()
