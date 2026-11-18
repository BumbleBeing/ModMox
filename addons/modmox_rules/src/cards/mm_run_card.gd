class_name MmRunCard
extends Resource
## A specific copy of a card owned during a run: an untouched base Card Definition plus
## the ordered Modifications earned for it (ADR 0004).

@export var base: MmCardDefinition
@export var modifications: Array[MmModification] = []


## Returns a private Card Definition with every Modification applied in the order earned.
## The result counts as the card's printed card for all rules purposes, and points to the
## base as its Original. The base is never changed.
func flatten() -> MmCardDefinition:
	assert(base != null, "A Run Card needs a base Card Definition.")
	# Only the card's own parts are copied. A resource in a file of its own, such as a Token
	# Definition (ADR 0044), is shared as it was loaded: it is never changed (ADR 0004), and
	# its file is how the GUI finds its art.
	var result: MmCardDefinition = base.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as MmCardDefinition
	for modification: MmModification in modifications:
		modification.apply_to(result)
	result.original = base
	return result
