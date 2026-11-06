class_name MulliganEvent
extends MmEvent
## A player takes a mulligan (CR 103.5). Returning the hand and drawing a new one are
## separate events that follow it.

var player_id: int


func _init(mulliganing_player_id: int) -> void:
	player_id = mulliganing_player_id


func apply(state: MmGameState) -> void:
	state.player(player_id).record_mulligan()


func describe() -> String:
	return "MULLIGAN: player %d" % player_id
