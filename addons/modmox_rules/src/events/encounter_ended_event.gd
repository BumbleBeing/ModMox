class_name EncounterEndedEvent
extends MmEvent
## The encounter ends (CR 104.2a, 104.4a): the player who has not lost wins, or it is a
## draw when both have lost.

## The winner, or MmGameState.NO_PLAYER for a draw.
var winner_id: int


func _init(winning_player_id: int) -> void:
	winner_id = winning_player_id


func apply(state: MmGameState) -> void:
	state.end_encounter(winner_id)


func describe() -> String:
	return "ENCOUNTER ENDED: %s" % ("a draw" if winner_id == MmGameState.NO_PLAYER else "player %d wins" % winner_id)
