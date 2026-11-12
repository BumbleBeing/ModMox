class_name KeepOrMulliganEvent
extends MmEvent
## A player chooses to keep their opening hand or to mulligan it (CR 103.5), or keeps it
## because it owes every card it holds. The choice is made in the open, in turn order, and
## logged as it is made: the hands are redrawn only once every player has chosen, which is
## when the MulliganEvent follows. Changes nothing itself.

var player_id: int
var is_keeping: bool
## How many cards a kept hand puts on the bottom; 0 for a mulligan.
var cards_to_bottom: int


func _init(choosing_player_id: int, keeps: bool, to_bottom: int = 0) -> void:
	player_id = choosing_player_id
	is_keeping = keeps
	cards_to_bottom = to_bottom


func apply(_state: MmGameState) -> void:
	pass


func describe() -> String:
	if is_keeping:
		return "KEEP: player %d (%d to the bottom)" % [player_id, cards_to_bottom]
	return "MULLIGAN CHOSEN: player %d" % player_id
