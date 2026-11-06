class_name AttackersDeclaredEvent
extends MmEvent
## The active player declares which creatures attack, and the player they attack
## (CR 508.1). Tapping the attackers is a separate event for each (CR 508.1f).

var attacking_player_id: int
var attacker_ids: Array[int]
var defending_player_id: int


func _init(attacking_id: int, attacking_ids: Array[int], defending_id: int) -> void:
	attacking_player_id = attacking_id
	attacker_ids = attacking_ids.duplicate()
	defending_player_id = defending_id


func apply(state: MmGameState) -> void:
	state.combat.declare_attackers(attacker_ids, defending_player_id)


func describe() -> String:
	return "ATTACKERS DECLARED: player %d attacks player %d with %s" % [attacking_player_id, defending_player_id, attacker_ids]
