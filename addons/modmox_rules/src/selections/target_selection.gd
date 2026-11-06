class_name TargetSelection
extends MmSelection
## The target chosen for requirement [member target_index] of this spell or ability.
## Several effects may share one, as in "3 damage to target creature and 1 damage to its
## controller". Selects nothing if that target became illegal (CR 608.2b).

@export var target_index: int = 0


func select(_state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	if target_index >= context.targets.size() or context.targets[target_index] == null:
		return []
	return [context.targets[target_index]]


func is_targeted() -> bool:
	return true
