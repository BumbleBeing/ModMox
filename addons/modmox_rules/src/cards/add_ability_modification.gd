class_name AddAbilityModification
extends MmModification
## Gives the card one more printed ability, after the ones it has: a keyword such as
## trample, or any triggered, activated or static ability.

@export var ability: MmAbility = null


func apply_to(definition: MmCardDefinition) -> void:
	assert(ability != null, "An AddAbilityModification needs an ability.")
	# ADR 0004: a private copy, as flattening copies the card's own abilities, with any file
	# of its own (a Token Definition) shared as it was loaded.
	definition.abilities.append(ability.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL) as MmAbility)
