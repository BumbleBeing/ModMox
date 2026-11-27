class_name StartingCondition
extends Resource
## One change to how the Hero starts an encounter (game glossary, game ADR 0106): more or less
## starting life, a smaller opening hand, extra free mulligans, or an Emblem. An Armor holds
## one or more, and a Status will hold the same ones (milestone 33), so nothing here names
## either. Each kind is a subclass that changes an MmPlayerSetup; the engine is handed only
## the final numbers and the Emblems (ADR 0011).

## The least starting life any Starting Conditions leave the Hero.
const LEAST_STARTING_LIFE: int = 1


## Applies each of [param conditions] to [param setup] in order, and then holds its numbers in
## bounds: starting life at least LEAST_STARTING_LIFE and the opening hand at least 0. They
## are held only at the end, so a loss and a gain come to their sum whatever their order.
static func apply_all(conditions: Array[StartingCondition], setup: MmPlayerSetup) -> void:
	for condition: StartingCondition in conditions:
		condition.apply_to(setup)
	setup.starting_life = maxi(setup.starting_life, LEAST_STARTING_LIFE)
	setup.opening_hand_size = maxi(setup.opening_hand_size, 0)


## Changes [param setup] as this Starting Condition says, with no bounds held.
func apply_to(_setup: MmPlayerSetup) -> void:
	push_error("A Starting Condition must say how it changes a setup.")


## What is wrong with this Starting Condition's shape, one reason to an entry, or nothing.
func problems() -> Array[String]:
	return ["A Starting Condition must be one of its kinds."] as Array[String]
