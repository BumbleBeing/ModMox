class_name Pacing
extends RefCounted
## Pacing (game glossary): how long the Villain's next answer is held back so the Hero can
## read what the Villain just did (A238, A358). The wait comes from what the last snapshot
## showed, never from what kind of answer made it: a pass that makes a spell resolve shows
## as much as casting one. It is also how long a step of the turn is shown, at the least,
## so that the steps a turn is passed through can be followed.
##
## These are the game's numbers at the Fast Game Speed; Normal takes one and a half times
## as long. The Encounter Presenter and Face Motion take theirs as
## plain values that default to zero, which the Encounter Screen sets when it starts a real
## encounter, so tests and screenshots never wait.

## Between two Villain actions.
const ACTION_MSEC: int = 500
## After the Villain taps for mana: longer than a move, so each land finishes turning
## before the next one starts.
const MANA_MSEC: int = 270
## The least time a step of the turn is shown before the game leaves it.
const STEP_MSEC: int = 100
## How long a face takes to move, turn or fade (Face Motion).
const MOVE_SECONDS: float = 0.25
## How long a card takes to fly from one zone to another (Card Flights): longer than a
## move, since it goes further, and over before the Villain's next action.
const FLIGHT_SECONDS: float = 0.35
## How long a Glow, Stack Mark or window takes to ease in or out.
const EASE_SECONDS: float = 0.15


## How many milliseconds a snapshot that showed [param events] is left on screen before the
## Villain's next answer: nothing for none or only quiet ones, [param mana_msec] when the
## rest are only tapping and mana, and [param action_msec] for anything else.
static func wait_for(events: Array[MmEvent], action_msec: int, mana_msec: int) -> int:
	var wait: int = 0
	for event: MmEvent in events:
		if _is_quiet(event):
			continue
		if not _is_mana(event):
			return action_msec
		wait = mana_msec
	return wait


## Whether [param events] show a step of the turn starting. A snapshot that does is left up
## for the step wait before the game moves on, whoever moves it.
static func starts_step(events: Array[MmEvent]) -> bool:
	for event: MmEvent in events:
		if event is StepStartedEvent:
			return true
	return false


## Bookkeeping that shows the Hero nothing they need time to read (A363). Every untap
## counts: nothing but the untap step untaps yet.
static func _is_quiet(event: MmEvent) -> bool:
	return (event is StepStartedEvent or event is TurnStartedEvent or event is ManaEmptiedEvent
			or event is UntapEvent or event is CombatEndedEvent or event is ContinuousEffectsEndedEvent
			or event is DamageRemovedEvent or event is DeathtouchDamageClearedEvent
			or event is RemovedFromCombatEvent)


static func _is_mana(event: MmEvent) -> bool:
	return event is TapEvent or event is ManaAddedEvent or event is ManaSpentEvent
