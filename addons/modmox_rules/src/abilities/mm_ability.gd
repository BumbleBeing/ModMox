class_name MmAbility
extends Resource
## An ability of a card (CR 113): spell, activated, triggered or static. Subclasses
## describe one kind each, such as ActivatedAbility. The kinds not built yet arrive with
## the milestones that need them (ADR 0002).


## A short human-readable description for logs and debugging.
func describe() -> String:
	return "ability"
