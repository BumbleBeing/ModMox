class_name ChoosePlayOrDrawDecision
extends MmPendingDecision
## The chooser decides whether to play first or let the other player start (CR 103.1).
## Answer: a Choice value.

enum Choice { PLAY, DRAW }

## Whether a random method picked this player to choose (CR 103.1), for the GUI ("You won
## the coin flip"); false when the Encounter Setup named them.
var is_chooser_random: bool


func _init(deciding_player_id: int, chosen_at_random: bool = false) -> void:
	super(deciding_player_id)
	is_chooser_random = chosen_at_random


func validate(answer: Variant) -> String:
	return _check_choice(answer, Choice.size())


func describe() -> String:
	return "player %d: play or draw" % player_id
