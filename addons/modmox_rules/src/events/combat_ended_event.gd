class_name CombatEndedEvent
extends MmEvent
## As the end of combat step ends, every creature is removed from combat (CR 511.3).


func apply(state: MmGameState) -> void:
	state.combat.clear()


func describe() -> String:
	return "COMBAT ENDED"
