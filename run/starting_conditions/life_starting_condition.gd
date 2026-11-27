class_name LifeStartingCondition
extends StartingCondition
## "You start each encounter with 3 more life.": more starting life, or less when the amount
## is negative. (The engine's LifeAtLeastStartingCondition is something else: a condition that
## compares a life total with the starting one.)

## How much more starting life; negative for less.
@export var amount: int = 0


func apply_to(setup: MmPlayerSetup) -> void:
	setup.starting_life += amount


func problems() -> Array[String]:
	var found: Array[String] = []
	if amount == 0:
		found.append("More or less life needs an amount other than 0.")
	return found
