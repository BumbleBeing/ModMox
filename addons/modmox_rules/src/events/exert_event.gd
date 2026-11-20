class_name ExertEvent
extends MmEvent
## A permanent is exerted (CR 701.43a): it won't untap during [member player_id]'s next
## untap step.

var object_id: int
## The player who exerted it, whose next untap step it skips.
var player_id: int


func _init(exerted_object_id: int, exerting_player_id: int) -> void:
	object_id = exerted_object_id
	player_id = exerting_player_id


func apply(state: MmGameState) -> void:
	state.object(object_id).exert(player_id)


func describe() -> String:
	return "EXERT: object %d, by player %d" % [object_id, player_id]
