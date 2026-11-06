class_name StaticAbility
extends MmAbility
## An ability that is simply true while its object is in the right zone (CR 604). Each
## keyword with no parameters is its own subclass, such as FirstStrikeAbility, so a
## Modification adds or removes one like any other ability, and rules ask for it with
## MmCharacteristics.has_ability().
##
## Static abilities that change characteristics are ContinuousStaticAbility instead.


func describe() -> String:
	return "static ability"
