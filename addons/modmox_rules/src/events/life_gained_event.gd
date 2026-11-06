class_name LifeGainedEvent
extends MmEvent
## A player gains life (CR 119.3).

var player_id: int
var amount: int


func _init(gaining_player_id: int, life: int) -> void:
	player_id = gaining_player_id
	amount = life


func apply(state: MmGameState) -> void:
	state.player(player_id).change_life(amount)


func describe() -> String:
	return "LIFE GAINED: player %d gains %d" % [player_id, amount]
