class_name RunFlow
extends RefCounted
## Where the debug run goes between screens (milestones 16 and 17), kept here because a
## scene is made afresh each time it is opened. The run opens on the Deckbox, whose Close
## leads to the Stage Intro and on to the Stage Map. Arriving at an encounter there opens
## the Deckbox against its Villain, with Start; after the encounter the Stage Map opens
## again, or the Deckbox against the Boss after losing to it. Losing the last Heart ends
## the run at the main menu; beating the Boss leaves the Stage Map to say so.

## The screens a run moves between. RunFlow says which comes next and never which scene it
## is: only the GUI knows that, so the run knows nothing of the scene tree. NONE means
## staying where the Hero is.
enum Screen { NONE, MENU, DECKBOX, DECKBUILDER, STAGE_INTRO, STAGE_MAP }

static var run: Run = null
## The Villain the Deckbox shows before an encounter, or null when it is opened to close.
static var villain: Villain = null
## Whether the deckbuilder is open from the Deckbox, and on which Deck (null for a new one).
static var is_editing: bool = false
static var deck_to_edit: Deck = null
## Where the Deckbox's Close goes.
static var back_from_deckbox: Screen = Screen.MENU


static func clear() -> void:
	run = null
	villain = null
	is_editing = false
	deck_to_edit = null
	back_from_deckbox = Screen.MENU


## Begins [param new_run] and says which Screen opens: the Deckbox, with Close, which
## leads to the Stage Intro.
static func start(new_run: Run) -> Screen:
	clear()
	run = new_run
	back_from_deckbox = Screen.STAGE_INTRO
	return Screen.DECKBOX


## The Stage Intro is over; says which Screen opens: the Stage Map, which the Deckbox's
## Close now leads back to.
static func finish_intro() -> Screen:
	back_from_deckbox = Screen.STAGE_MAP
	return Screen.STAGE_MAP


## The Deckbox opened from the Stage Map's Run Bar, with Close.
static func open_deckbox() -> Screen:
	villain = null
	return Screen.DECKBOX


## The Hero has arrived at a Node; says which Screen opens: the Deckbox against its
## Villain if it is an encounter, or NONE to stay on the Stage Map.
static func arrive() -> Screen:
	if not run.stage_visit.must_play():
		return Screen.NONE
	villain = run.stage_visit.meeting
	return Screen.DECKBOX


## Counts the encounter's end and says which Screen opens next.
static func finish_encounter(won: bool) -> Screen:
	run.record_encounter(won)
	if run.is_lost():
		clear()
		return Screen.MENU
	villain = null
	if run.stage_visit.must_play():
		villain = run.stage_visit.meeting
		return Screen.DECKBOX
	return Screen.STAGE_MAP


## The run is won and its notice closed; says which Screen opens: the main menu.
static func finish_run() -> Screen:
	clear()
	return Screen.MENU


## Opens [param deck] in the deckbuilder, or a new Deck if it is null, and says which
## Screen that is.
static func edit(deck: Deck) -> Screen:
	is_editing = true
	deck_to_edit = deck
	return Screen.DECKBUILDER


static func finish_editing() -> Screen:
	is_editing = false
	deck_to_edit = null
	return Screen.DECKBOX
