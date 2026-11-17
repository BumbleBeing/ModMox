class_name ChosenSelection
extends MmSelection
## "A [filter]", such as Whitemane Lion's "return a creature you control": one permanent
## matching [member filter], chosen by the controller of the spell or ability as the effect
## that uses it begins (CR 608.2d). It is not a target (CR 115.10), so protection does not
## stop it and it never keeps the spell or ability from resolving. Several effects may share
## choice [member choice_index]. Selects nothing when there was nothing to choose.

@export var filter: MmFilter
@export var choice_index: int = 0


func select(_state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var chosen: MmReference = context.choices.get(choice_index, null)
	if chosen == null:
		return []
	return [chosen]


## The permanents that may be chosen right now, in ID order.
func candidates(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var result: Array[MmReference] = []
	for candidate: MmReference in TargetRequirement.candidates(state):
		if candidate.is_object() and (filter == null or filter.matches(state, candidate, context)):
			result.append(candidate)
	return result
