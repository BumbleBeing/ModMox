class_name MmAbility
extends Resource
## An ability of a card (CR 113): spell, activated, triggered or static. Subclasses
## describe one kind each, such as ActivatedAbility. The kinds not built yet arrive with
## the milestones that need them (ADR 0002).


## Its modes (CR 700.2): a modal spell's or modal triggered ability's "•" lines, and none
## for anything else (ADR 0046).
func modes_or_none() -> Array[AbilityMode]:
	return []


## A short human-readable description for logs and debugging.
func describe() -> String:
	return "ability"
