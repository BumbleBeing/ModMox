class_name DamagePreventedEvent
extends MmEvent
## Damage that would have been dealt was prevented (CR 615). It is recorded so the GUI can
## show it and so later effects can ask how much was prevented; the damage itself is never
## dealt (CR 615.1). Applying it uses up that much of a shield.

## The source of the damage that was prevented.
var source_object_id: int
var recipient: MmReference
var amount: int
var is_combat: bool
## The Card Identity of what prevented it, such as a Samite Healer or a Knight with
## protection, so the GUI can point at it.
var prevented_by_card_id: int
## The shield used up, by its timestamp, or 0 when nothing was used up.
var shield_timestamp: int


func _init(damage_source_id: int, damaged: MmReference, prevented: int, combat_damage: bool, preventing_card_id: int,
		shield: int) -> void:
	source_object_id = damage_source_id
	recipient = damaged
	amount = prevented
	is_combat = combat_damage
	prevented_by_card_id = preventing_card_id
	shield_timestamp = shield


func apply(state: MmGameState) -> void:
	if shield_timestamp != 0:
		state.use_replacement_effect(shield_timestamp, amount)


func describe() -> String:
	return "%sDAMAGE PREVENTED: %d from object %d to %s by card %d" % [
		"COMBAT " if is_combat else "", amount, source_object_id, recipient.describe(), prevented_by_card_id]
