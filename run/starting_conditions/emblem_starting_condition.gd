class_name EmblemStartingCondition
extends StartingCondition
## "You get an emblem with "…"": an Emblem that is the Hero's for the encounter. An Armor's is
## a file in content/emblems/ named after the Armor, with its name (game ADR 0106).

## A Card Definition with abilities and nothing else (ADR 0011).
@export var emblem: MmCardDefinition = null


func apply_to(setup: MmPlayerSetup) -> void:
	setup.emblems.append(emblem)


func problems() -> Array[String]:
	var found: Array[String] = []
	if emblem == null:
		found.append("An Emblem Starting Condition needs an Emblem.")
	elif emblem.abilities.is_empty():
		found.append("An Emblem needs at least one ability.")
	return found
