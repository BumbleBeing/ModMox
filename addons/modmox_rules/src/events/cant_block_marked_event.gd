class_name CantBlockMarkedEvent
extends MmEvent
## A permanent can't block in a Game Turn (CR 509.1a), as a CantBlockThisTurnEffect says.

var object_id: int
var game_turn: int


func _init(marked_object_id: int, in_game_turn: int) -> void:
	object_id = marked_object_id
	game_turn = in_game_turn


func apply(state: MmGameState) -> void:
	state.object(object_id).forbid_blocking_in(game_turn)


func describe() -> String:
	return "CAN'T BLOCK: object %d in Game Turn %d" % [object_id, game_turn]
