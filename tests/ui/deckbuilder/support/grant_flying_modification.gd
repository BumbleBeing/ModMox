extends MmModification
## A Modification that gives a card flying, for a test Mod that changes what the card says.
## Preloaded, never class_name'd.


func apply_to(definition: MmCardDefinition) -> void:
	definition.abilities.append(FlyingAbility.new())
