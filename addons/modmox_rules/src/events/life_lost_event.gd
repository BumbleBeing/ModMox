class_name LifeLostEvent
extends MmEvent
## A player loses life that is not from damage (CR 119.3).

var player_id: int
var amount: int


func _init(losing_player_id: int, life: int) -> void:
	player_id = losing_player_id
	amount = life


func apply(state: MmGameState) -> void:
	state.player(player_id).change_life(-amount)


func describe() -> String:
	return "LIFE LOST: player %d loses %d" % [player_id, amount]
