class_name DamageEvent
extends MmEvent
## A source deals damage to a player, who loses that much life (CR 120.3a), or to a
## creature, which has that much damage marked on it (CR 120.3e).

var source_object_id: int
var recipient: MmReference
var amount: int
## Whether this is combat damage (CR 510.2), which some abilities care about.
var is_combat: bool


func _init(damage_source_id: int, damaged: MmReference, damage: int, combat_damage: bool = false) -> void:
	source_object_id = damage_source_id
	recipient = damaged
	amount = damage
	is_combat = combat_damage


func apply(state: MmGameState) -> void:
	if recipient.is_player():
		state.player(recipient.id).change_life(-amount)
	else:
		state.object(recipient.id).mark_damage(amount)


func describe() -> String:
	return "%sDAMAGE: object %d deals %d to %s" % ["COMBAT " if is_combat else "", source_object_id, amount, recipient.describe()]
