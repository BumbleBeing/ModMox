class_name KeepOrMulliganDecision
extends MmPendingDecision
## A player decides whether to keep their opening hand (CR 103.5). Answer: a Choice value.

enum Choice { KEEP, MULLIGAN }

var mulligans_taken: int
## How many cards keeping now would put on the bottom, for the GUI ("Keep 6").
var cards_to_bottom_if_kept: int
## Whether mulliganing now would be a Free Mulligan, for the GUI ("Free Mulligan").
var is_next_mulligan_free: bool


func _init(deciding_player_id: int, taken: int, to_bottom_if_kept: int, next_is_free: bool = false) -> void:
	super(deciding_player_id)
	mulligans_taken = taken
	cards_to_bottom_if_kept = to_bottom_if_kept
	is_next_mulligan_free = next_is_free


func validate(answer: Variant) -> String:
	return _check_choice(answer, Choice.size())


func describe() -> String:
	return "player %d: keep or mulligan (mulligans taken %d)" % [player_id, mulligans_taken]
