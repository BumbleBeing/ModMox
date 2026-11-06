class_name ManaAddedEvent
extends MmEvent
## Mana is added to a player's mana pool (CR 106.3).

var player_id: int
var mana_type: MmMana.Type
var amount: int
var source_object_id: int


func _init(receiving_player_id: int, added_type: MmMana.Type, added_amount: int, source_id: int) -> void:
	player_id = receiving_player_id
	mana_type = added_type
	amount = added_amount
	source_object_id = source_id


func apply(state: MmGameState) -> void:
	var units: Array[MmMana] = []
	for _index: int in amount:
		units.append(MmMana.new(mana_type, source_object_id))
	state.player(player_id).add_mana(units)


func describe() -> String:
	return "MANA ADDED: player %d gets %d %s from object %d" % [player_id, amount, MmMana.Type.find_key(mana_type), source_object_id]
