class_name MmAction
extends RefCounted
## Something a player may do while holding priority (CR 117.1), offered as one option of
## a PriorityDecision. Subclasses describe one kind each, such as PassAction.


## A short human-readable description for logs and debugging.
func describe() -> String:
	return "action"
