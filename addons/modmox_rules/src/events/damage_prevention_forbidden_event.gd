class_name DamagePreventionForbiddenEvent
extends MmEvent
## Damage can't be prevented in a Game Turn (CR 615.12), as a DamageCantBePreventedEffect says.

var game_turn: int


func _init(in_game_turn: int) -> void:
	game_turn = in_game_turn


func apply(state: MmGameState) -> void:
	state.forbid_damage_prevention_in(game_turn)


func describe() -> String:
	return "DAMAGE CAN'T BE PREVENTED: in Game Turn %d" % game_turn
