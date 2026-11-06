extends MmEffect
## A stand-in effect that has a target, for testing rules that care whether an ability
## targets (such as mana ability classification) before any real targeted effect exists.


func has_targets() -> bool:
	return true
