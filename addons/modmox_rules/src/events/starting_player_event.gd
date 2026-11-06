class_name StartingPlayerEvent
extends MmEvent
## The starting player is determined (CR 103.1).

## Chooser ID when the start was forced by the setup rather than chosen.
const NO_CHOOSER: int = -1

var starting_player_id: int
var chooser_id: int


func _init(starting_id: int, choosing_id: int = NO_CHOOSER) -> void:
	starting_player_id = starting_id
	chooser_id = choosing_id


func apply(state: MmGameState) -> void:
	state.starting_player_id = starting_player_id


func describe() -> String:
	if chooser_id == NO_CHOOSER:
		return "STARTING PLAYER: player %d (forced)" % starting_player_id
	return "STARTING PLAYER: player %d (chosen by player %d)" % [starting_player_id, chooser_id]
