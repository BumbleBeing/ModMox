class_name ManaEmptiedEvent
extends MmEvent
## A player's unspent mana empties from their pool (CR 500.4). There is no mana burn.

var player_id: int
## How much mana was lost, set when the event is applied.
var mana_lost: int = 0


func _init(emptying_player_id: int) -> void:
	player_id = emptying_player_id


func apply(state: MmGameState) -> void:
	mana_lost = state.player(player_id).empty_mana_pool()


func describe() -> String:
	return "MANA EMPTIED: player %d loses %d mana" % [player_id, mana_lost]
