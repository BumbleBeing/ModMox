class_name PlayerLostEvent
extends MmEvent
## A player loses the game (CR 104.3), through a state-based action or by conceding.

var player_id: int
var reason: MmPlayer.LossReason


func _init(losing_player_id: int, why: MmPlayer.LossReason) -> void:
	player_id = losing_player_id
	reason = why


func apply(state: MmGameState) -> void:
	state.player(player_id).lose(reason)


func describe() -> String:
	return "PLAYER LOST: player %d (%s)" % [player_id, MmPlayer.LossReason.find_key(reason)]
