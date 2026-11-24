class_name MmTrigger
extends Resource
## What a triggered ability waits for (CR 603.1): one kind of event, with conditions on it.
## Subclasses describe one kind each, such as StepBeganTrigger.

## Whose step, spell or object counts, relative to the ability's controller.
## Saved card files store these as numbers: never change or reuse a value, only add new ones.
enum Whose { ANY = 0, YOU = 1, OPPONENT = 2 }


## Whether [param event] triggers the ability. [param context] is the ability's controller
## and source. Called right after the event is applied.
func matches(_state: MmGameState, _event: MmEvent, _context: MmEffectContext) -> bool:
	assert(false, "%s must override matches()." % get_script().resource_path)
	return false


## CR 603.10a: whether this is a leaves-the-battlefield trigger, which looks back in time.
func looks_back() -> bool:
	return false


## The player the event was about ("that player"), or MmGameState.NO_PLAYER.
func triggering_player_id(_state: MmGameState, _event: MmEvent) -> int:
	return MmGameState.NO_PLAYER


## The object the event was about ("that creature"), or 0.
func triggering_object_id(_event: MmEvent) -> int:
	return 0


## What [param event] is one occasion of, when several events of one batch trigger the
## ability only once together, as one lifelink source's damage to several recipients is one
## life gain (CR 119.9, ADR 0082); "" when each event is an occasion of its own, as for most.
func occasion_of(_state: MmGameState, _event: MmEvent) -> String:
	return ""


## One entry for each time [param event] triggers the ability, each the object that time is
## about ("that creature"), or 0 for none; empty when it does not trigger it. One event
## triggers most abilities once at most, so this is matches() with triggering_object_id(),
## but "blocks a creature" triggers once for each attacker blocked (CR 509.3b, ADR 0017's
## addendum).
func triggering_object_ids(state: MmGameState, event: MmEvent, context: MmEffectContext) -> Array[int]:
	var found: Array[int] = []
	if matches(state, event, context):
		found.append(triggering_object_id(event))
	return found


## Whether [param player_id] is [param whose] relative to the controller in [param context].
static func is_whose(whose: Whose, player_id: int, context: MmEffectContext) -> bool:
	match whose:
		Whose.YOU:
			return player_id == context.controller_id
		Whose.OPPONENT:
			return player_id != context.controller_id
	return true
