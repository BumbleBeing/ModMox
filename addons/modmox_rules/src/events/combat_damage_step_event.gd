class_name CombatDamageStepEvent
extends MmEvent
## A combat damage step begins (CR 510). When it is the extra, earlier step for first and
## double strikers (CR 510.4), it records which creatures strike in it.

var is_first_strike: bool
var first_strike_ids: Array[int]


func _init(first_strike: bool, striking_ids: Array[int] = []) -> void:
	is_first_strike = first_strike
	first_strike_ids = striking_ids.duplicate()


func apply(state: MmGameState) -> void:
	state.combat.begin_damage_step(is_first_strike, first_strike_ids)


func describe() -> String:
	if is_first_strike:
		return "COMBAT DAMAGE STEP: first strike, with %s" % [first_strike_ids]
	return "COMBAT DAMAGE STEP"
