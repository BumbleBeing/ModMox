class_name EncounterSnapshot
extends RefCounted
## Everything the Encounter Screen is handed after each change (ADR 0021): what the Hero
## may see, what the Hero is being asked, and what has just happened. The screen draws from
## this alone and never reads the engine.

## The Hero's Player View.
var view: MmPlayerView
## The Pending Decision the Hero must answer, or null while the Villain is deciding or once
## the encounter is over.
var decision: MmPendingDecision = null
var is_villain_thinking: bool = false
## Whether the Hero kept priority with their own spell or ability on the stack.
var is_holding_priority: bool = false
var can_undo: bool = false
## Whether this snapshot came from an undo or a canceled cast. Nothing moves on the screen
## for one (ADR 0015, A365): an empty event list alone cannot tell it from a quiet pass.
var is_rewind: bool = false
## The Event Log entries added since the previous snapshot, in order, for animations (13d).
## Empty after an undo, which is never animated (ADR 0015).
var events: Array[MmEvent] = []
## How to draw each Game Object the view shows, by object ID.
var looks: Dictionary[int, CardLook] = {}


## Whether the encounter has ended. The view says who won and why each loser lost.
func is_over() -> bool:
	return view.is_over


## Whether it ended with no winner.
func is_draw() -> bool:
	return view.is_over and not view.life_totals.has(view.winner_id)


## The look of Game Object [param object_id], or null if the view does not show it.
func look_of(object_id: int) -> CardLook:
	return looks.get(object_id, null) as CardLook


## Every Game Object the view shows, wherever it is.
func visible_objects() -> Array[MmObjectView]:
	var all: Array[MmObjectView] = []
	all.append_array(view.hand)
	all.append_array(view.battlefield)
	all.append_array(view.stack)
	all.append_array(view.command)
	for player_id: int in view.graveyards:
		all.append_array(view.graveyards[player_id])
	for player_id: int in view.exiles:
		all.append_array(view.exiles[player_id])
	return all
