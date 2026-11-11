class_name StepStops
extends RefCounted
## The steps where the Hero wants to be asked before auto-pass carries on (A231). There is
## one row for each player's turn: the Hero's own turn, and the Villain's.

## Auto-pass stops here until the player changes them.
const DEFAULTS: Dictionary[int, Array] = {
	MmEncounterSetup.HERO_PLAYER_ID: [
		MmTurn.Step.PRECOMBAT_MAIN, MmTurn.Step.DECLARE_ATTACKERS, MmTurn.Step.DECLARE_BLOCKERS,
		MmTurn.Step.POSTCOMBAT_MAIN,
	],
	MmEncounterSetup.VILLAIN_PLAYER_ID: [
		MmTurn.Step.DECLARE_ATTACKERS, MmTurn.Step.DECLARE_BLOCKERS, MmTurn.Step.END,
	],
}

var _stops: Dictionary[int, Array] = {}


func _init() -> void:
	for player_id: int in DEFAULTS:
		_stops[player_id] = DEFAULTS[player_id].duplicate()


## Whether [param step] can hold a stop. No player normally gets priority in the untap or
## cleanup step (CR 502.4, 514.3), so those never do.
static func can_hold(step: MmTurn.Step) -> bool:
	return step != MmTurn.Step.NONE and step != MmTurn.Step.UNTAP and step != MmTurn.Step.CLEANUP


## Whether there is a stop at [param step] of [param turn_player_id]'s turn.
func has_stop(turn_player_id: int, step: MmTurn.Step) -> bool:
	var steps: Array = _stops.get(turn_player_id, [])
	return steps.has(step)


## Sets or clears the stop at [param step] of [param turn_player_id]'s turn. A step that
## cannot hold a stop is left alone.
func set_stop(turn_player_id: int, step: MmTurn.Step, is_on: bool) -> void:
	if not can_hold(step) or not _stops.has(turn_player_id):
		return
	var steps: Array = _stops[turn_player_id]
	if is_on and not steps.has(step):
		steps.append(step)
	elif not is_on:
		steps.erase(step)


func toggle(turn_player_id: int, step: MmTurn.Step) -> void:
	set_stop(turn_player_id, step, not has_stop(turn_player_id, step))
