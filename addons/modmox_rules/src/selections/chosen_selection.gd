class_name ChosenSelection
extends MmSelection
## "A [filter]", such as Whitemane Lion's "return a creature you control": one permanent
## matching [member filter], chosen by the controller of the spell or ability as the effect
## that uses it begins (CR 608.2d). It is not a target (CR 115.10), so protection does not
## stop it and it never keeps the spell or ability from resolving. Several effects may share
## choice [member choice_index]. Selects nothing when there was nothing to choose. With
## [member from_among] it is a card chosen among what that Selection finds instead, as in
## "put an instant or sorcery card from among them into your hand" (engine ADR 0080).

@export var filter: MmFilter
@export var choice_index: int = 0
## What the card is chosen among, such as the cards just milled; null for any permanent.
@export var from_among: MmSelection = null


func select(_state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var chosen: MmReference = context.choices.get(choice_index, null)
	if chosen == null:
		return []
	return [chosen]


## What may be chosen right now: the permanents matching [member filter] in ID order, or
## those of what [member from_among] finds, in its order.
func candidates(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var result: Array[MmReference] = []
	var pool: Array[MmReference] = TargetRequirement.candidates(state) if from_among == null else from_among.select(state, context)
	for candidate: MmReference in pool:
		if candidate.is_object() and (filter == null or filter.matches(state, candidate, context)):
			result.append(candidate)
	return result
