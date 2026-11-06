class_name MmEvent
extends RefCounted
## A single change to the game. Proposed, offered to replacement effects, applied, then
## recorded in the event log (ADR 0007). Only apply() may mutate zones, players or objects.


## Makes this change to [param state]. Called only by MmGameState.perform().
func apply(_state: MmGameState) -> void:
	assert(false, "%s must override apply()." % get_script().resource_path)


## A short human-readable description for logs and debugging.
func describe() -> String:
	return "event"
