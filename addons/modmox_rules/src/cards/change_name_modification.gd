class_name ChangeNameModification
extends MmModification
## Gives the card a new name.

@export var new_name: String = ""


## Replaces the definition's name with [member new_name].
func apply_to(definition: MmCardDefinition) -> void:
	definition.name = new_name
