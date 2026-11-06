class_name EmptyLibraryDrawEvent
extends MmEvent
## A player tries to draw from an empty library (CR 121.4). They lose the next time
## state-based actions are checked (CR 704.5b).

var player_id: int


func _init(drawing_player_id: int) -> void:
	player_id = drawing_player_id


func apply(state: MmGameState) -> void:
	state.player(player_id).record_empty_library_draw()


func describe() -> String:
	return "EMPTY LIBRARY DRAW: player %d" % player_id
