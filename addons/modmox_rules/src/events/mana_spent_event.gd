class_name ManaSpentEvent
extends MmEvent
## A unit of mana leaves a player's pool to pay a cost (CR 601.2h).

var player_id: int
var unit_index: int
## The spent mana's type and source, set when the event is applied.
var mana_type: MmMana.Type = MmMana.Type.COLORLESS
var source_object_id: int = 0


func _init(paying_player_id: int, pool_index: int) -> void:
	player_id = paying_player_id
	unit_index = pool_index


func apply(state: MmGameState) -> void:
	var spent: MmMana = state.player(player_id).remove_mana_at(unit_index)
	mana_type = spent.type
	source_object_id = spent.source_object_id


func describe() -> String:
	return "MANA SPENT: player %d spends %s from object %d" % [player_id, MmMana.Type.find_key(mana_type), source_object_id]
