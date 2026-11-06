class_name BlockersDeclaredEvent
extends MmEvent
## The defending player declares blocks (CR 509.1), given as two lists of the same length:
## each blocker and the attacker it blocks.

var defending_player_id: int
var blocker_ids: Array[int]
var attacker_ids: Array[int]


func _init(defending_id: int, blocking_ids: Array[int], blocked_ids: Array[int]) -> void:
	defending_player_id = defending_id
	blocker_ids = blocking_ids.duplicate()
	attacker_ids = blocked_ids.duplicate()


func apply(state: MmGameState) -> void:
	state.combat.declare_blocks(blocker_ids, attacker_ids)


func describe() -> String:
	return "BLOCKERS DECLARED: player %d blocks with %s against %s" % [defending_player_id, blocker_ids, attacker_ids]
