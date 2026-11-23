class_name AddManaCostModification
extends MmModification
## Adds a mana cost to the card's, such as "{1}" or "{G}": its generic mana to the card's
## generic mana, so {1}{G} with {1} added is {2}{G}, and its symbols and hybrid symbols to the
## card's. A card with no mana cost gets a copy of this one as its own.

@export var cost: MmManaCost = null


func apply_to(definition: MmCardDefinition) -> void:
	assert(cost != null, "An AddManaCostModification needs a cost.")
	if definition.mana_cost == null:
		definition.mana_cost = cost.duplicate(true) as MmManaCost
		return
	definition.mana_cost.generic += cost.generic
	definition.mana_cost.symbols.append_array(cost.symbols)
	definition.mana_cost.hybrid_symbols.append_array(cost.hybrid_symbols)
