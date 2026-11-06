class_name RemovedFromCombatEvent
extends MmEvent
## A creature stops being an attacking or blocking creature (CR 506.4), as when it
## regenerates. An attacker it was blocking stays blocked (CR 509.1h).

var object_id: int


func _init(removed_id: int) -> void:
	object_id = removed_id


func apply(state: MmGameState) -> void:
	state.combat.remove_from_combat(object_id)


func describe() -> String:
	return "REMOVED FROM COMBAT: object %d" % object_id
