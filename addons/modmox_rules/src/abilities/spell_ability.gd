class_name SpellAbility
extends MmAbility
## What an instant or sorcery does when it resolves (CR 113.3a): its target requirements
## and its effects, in order.

@export var targets: Array[TargetSpec] = []
@export var effects: Array[MmEffect] = []


func describe() -> String:
	return "spell ability (%d targets, %d effects)" % [targets.size(), effects.size()]
