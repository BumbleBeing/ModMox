class_name DamageEvent
extends MmEvent
## A source deals damage to a player, who loses that much life (CR 120.3a).

var source_object_id: int
var player_id: int
var amount: int


func _init(damage_source_id: int, damaged_player_id: int, damage: int) -> void:
	source_object_id = damage_source_id
	player_id = damaged_player_id
	amount = damage


func apply(state: MmGameState) -> void:
	state.player(player_id).change_life(-amount)


func describe() -> String:
	return "DAMAGE: object %d deals %d to player %d" % [source_object_id, amount, player_id]
