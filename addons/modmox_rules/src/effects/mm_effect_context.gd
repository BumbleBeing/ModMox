class_name MmEffectContext
extends RefCounted
## Who and what an effect is resolving for: the controller of the spell or ability, its
## source, its targets, and for a triggered ability what triggered it.

var controller_id: int
var source_object_id: int
## The chosen target of each target requirement, in order. An entry is null when that
## target was illegal on resolution (CR 608.2b).
var targets: Array[MmReference] = []
## For a triggered ability: what its event was about ("that player", "that creature").
var triggering_player_id: int = -1
var triggering_object_id: int = 0


func _init(controlling_player_id: int, source_id: int, chosen_targets: Array[MmReference] = [],
		trigger_player_id: int = -1, trigger_object_id: int = 0) -> void:
	controller_id = controlling_player_id
	source_object_id = source_id
	targets = chosen_targets.duplicate()
	triggering_player_id = trigger_player_id
	triggering_object_id = trigger_object_id
