class_name DamageEvent
extends MmEvent
## A source deals damage to a player, who loses that much life (CR 120.3a), or to a
## creature, which has that much damage marked on it (CR 120.3e). When the source has
## lifelink, its controller gains that much life as well (CR 120.3f).

var source_object_id: int
var recipient: MmReference
var amount: int
## Whether this is combat damage (CR 510.2), which some abilities care about.
var is_combat: bool
## Whether the source had deathtouch, set when the event is applied (CR 702.2b).
var is_deathtouch: bool = false
## Whether the source had lifelink, set when the event is applied (CR 702.15b).
var is_lifelink: bool = false


func _init(damage_source_id: int, damaged: MmReference, damage: int, combat_damage: bool = false) -> void:
	source_object_id = damage_source_id
	recipient = damaged
	amount = damage
	is_combat = combat_damage


func apply(state: MmGameState) -> void:
	var source: MmGameObject = state.object_or_last_known(source_object_id)
	is_deathtouch = source != null and state.characteristics_of(source).has_ability(DeathtouchAbility)
	if recipient.is_player():
		state.player(recipient.id).change_life(-amount)
	else:
		var damaged: MmGameObject = state.object(recipient.id)
		damaged.mark_damage(amount)
		if is_deathtouch:
			damaged.mark_deathtouch_damage()
	is_lifelink = source != null and state.characteristics_of(source).has_ability(LifelinkAbility)
	if is_lifelink:
		state.player(source.controller_id).change_life(amount)


func describe() -> String:
	return "%sDAMAGE: object %d deals %d to %s" % ["COMBAT " if is_combat else "", source_object_id, amount, recipient.describe()]
