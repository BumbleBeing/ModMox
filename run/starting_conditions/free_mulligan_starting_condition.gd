class_name FreeMulliganStartingCondition
extends StartingCondition
## "You start each encounter with an extra free mulligan.": extra free mulligans.

## How many extra free mulligans.
@export var amount: int = 0


func apply_to(setup: MmPlayerSetup) -> void:
	setup.free_mulligans += amount


func problems() -> Array[String]:
	var found: Array[String] = []
	if amount <= 0:
		found.append("Extra free mulligans need at least one.")
	return found
