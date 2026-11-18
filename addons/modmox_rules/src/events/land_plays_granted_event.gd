class_name LandPlaysGrantedEvent
extends MmEvent
## A player may play [member count] more lands this turn (CR 305.2).

var player_id: int
var count: int


func _init(granted_player_id: int, land_plays: int) -> void:
	player_id = granted_player_id
	count = land_plays


func apply(state: MmGameState) -> void:
	state.player(player_id).grant_land_plays(count)


func describe() -> String:
	return "LAND PLAYS GRANTED: player %d may play %d more lands this turn" % [player_id, count]
