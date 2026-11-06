class_name StaticAbility
extends MmAbility
## An ability that is simply true while its object is in the right zone (CR 604). Each
## keyword with no parameters is its own subclass, such as FirstStrikeAbility, so a
## Modification adds or removes one like any other ability, and rules ask for it with
## MmCharacteristics.has_ability().
##
## Later (milestone 9): static abilities that create continuous effects.


func describe() -> String:
	return "static ability"
