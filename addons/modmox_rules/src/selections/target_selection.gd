class_name TargetSelection
extends MmSelection
## The target chosen for requirement [member target_index] of this spell or ability, or each
## target an "up to" requirement chose, in the order chosen (ADR 0014). Several effects may
## share one, as in "3 damage to target creature and 1 damage to its controller". Selects
## nothing for a target that became illegal (CR 608.2b).

@export var target_index: int = 0


func select(_state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	return context.targets_of(target_index)


func is_targeted() -> bool:
	return true
