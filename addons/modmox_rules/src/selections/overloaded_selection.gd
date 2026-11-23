class_name OverloadedSelection
extends MmSelection
## "Each [what a target requirement could choose]": a "target" an overload changed to "each"
## (CR 702.96b, ADR 0014). It finds every player, permanent, spell, ability or card that
## overloaded requirement [member overloaded_index] could have chosen, fixed as the spell
## began to resolve and shared by every effect, as targets are. It does not target, so
## protection and ward never stop it and it never keeps the spell from resolving.

@export var overloaded_index: int = 0


func select(_state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	return context.overloaded_of(overloaded_index)
