extends MmModification
## A Modification that makes the card a creature as well, for a test of a Mod that reads the
## card as earlier Mods have made it. Preloaded, never class_name'd.


func apply_to(definition: MmCardDefinition) -> void:
	definition.card_types.append(MmCardTypes.CardType.CREATURE)
