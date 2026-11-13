class_name HeldWindows
extends RefCounted
## Which of the Hero's Emblems and Potions windows closed because something in them was
## used, and so come back if that is taken back (ADR 0032, A528). A window closes at the
## click that starts an activation, with a target or without, so the board is clear; it
## reopens where it was if the activation is canceled or undone, and stays closed once the
## ability has resolved or been countered. Kept on the screen, outside what a redraw
## rebuilds.
##
## An ability is put on the stack as it is announced (CR 602.2a), before its targets and
## its mana are chosen, so "still on the stack" covers the whole of activating it too.

## The Hero's two windows of Held things.
enum Kind { EMBLEMS, POTIONS }

## The windows to reopen now, set by follow().
var to_reopen: Array[Kind] = []

## Window → the Game Object IDs of what was used from it and has neither left the stack nor
## been taken back, in the order they were used.
var _pending: Dictionary[Kind, Array] = {}


## Something in [param window] was clicked to be used: the Emblem or Potion with Game
## Object ID [param source_id]. The window closes now.
func started(window: Kind, source_id: int) -> void:
	if not _pending.has(window):
		_pending[window] = []
	(_pending[window] as Array).append(source_id)


## The answer that would have used [param source_id] from [param window] was refused, so
## nothing was started.
func forget(window: Kind, source_id: int) -> void:
	if _pending.has(window):
		(_pending[window] as Array).erase(source_id)
		if (_pending[window] as Array).is_empty():
			_pending.erase(window)


## Whether [param window] is closed for something still being activated or on the stack.
func is_waiting(window: Kind) -> bool:
	return _pending.has(window)


## Takes in [param snapshot]. Whatever was used and is no longer on the stack has ended: a
## rewind took it back, and its window reopens; anything else resolved it or countered it,
## and it is forgotten. A later rewind then reopens nothing.
func follow(snapshot: EncounterSnapshot) -> void:
	to_reopen.clear()
	for window: Kind in _pending.keys():
		var still_there: Array = []
		for source_id: int in _pending[window]:
			if _is_on_stack(snapshot.view, source_id):
				still_there.append(source_id)
			elif snapshot.is_rewind and not to_reopen.has(window):
				to_reopen.append(window)
		if still_there.is_empty():
			_pending.erase(window)
		else:
			_pending[window] = still_there


static func _is_on_stack(view: MmPlayerView, source_id: int) -> bool:
	for item: MmObjectView in view.stack:
		if item.ability != null and item.source_object_id == source_id:
			return true
	return false
