class_name AddManaSymbolModification
extends MmModification
## Adds one mana symbol to the card's cost, such as "+{G}". A card with no mana cost gets
## a cost made of just that symbol.

@export var symbol: MmMana.Type = MmMana.Type.COLORLESS


func apply_to(definition: MmCardDefinition) -> void:
	if definition.mana_cost == null:
		definition.mana_cost = MmManaCost.new()
	definition.mana_cost.symbols.append(symbol)
