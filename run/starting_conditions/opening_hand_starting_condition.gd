class_name OpeningHandStartingCondition
extends StartingCondition
## "Your opening hand has one fewer card.": a smaller opening hand. The maximum hand size is
## not changed.

## How many fewer cards the opening hand has.
@export var fewer_cards: int = 0


func apply_to(setup: MmPlayerSetup) -> void:
	setup.opening_hand_size -= fewer_cards


func problems() -> Array[String]:
	var found: Array[String] = []
	if fewer_cards <= 0:
		found.append("A smaller opening hand needs at least one card fewer.")
	return found
