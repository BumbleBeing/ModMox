class_name PlayPermittedEvent
extends MmEvent
## A card in exile may be played by a player through a Game Turn, as a MayPlayExiledEffect
## says (engine ADR 0100).

var object_id: int
var player_id: int
var through_game_turn: int


func _init(permitted_object_id: int, permitted_player_id: int, last_game_turn: int) -> void:
	object_id = permitted_object_id
	player_id = permitted_player_id
	through_game_turn = last_game_turn


func apply(state: MmGameState) -> void:
	state.object(object_id).permit_playing(player_id, through_game_turn)


func describe() -> String:
	return "PLAY PERMITTED: object %d by player %d through game turn %d" % [object_id, player_id, through_game_turn]
