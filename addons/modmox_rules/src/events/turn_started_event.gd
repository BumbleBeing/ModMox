class_name TurnStartedEvent
extends MmEvent
## A new turn begins for [member active_player_id] (CR 500.1).

var active_player_id: int
## The Game Turn and the active player's own Turn Number, set when the event is applied.
var game_turn: int = 0
var turn_number: int = 0


func _init(new_active_player_id: int) -> void:
	active_player_id = new_active_player_id


func apply(state: MmGameState) -> void:
	state.game_turn += 1
	state.active_player_id = active_player_id
	var active: MmPlayer = state.player(active_player_id)
	active.begin_turn()
	game_turn = state.game_turn
	turn_number = active.turn_number


func describe() -> String:
	return "TURN STARTED: game turn %d, player %d turn %d" % [game_turn, active_player_id, turn_number]
