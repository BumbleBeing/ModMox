class_name RunFlow
extends RefCounted
## Where the debug run goes between screens (milestones 16 and 17), kept here because a
## scene is made afresh each time it is opened. The run opens on the Deckbox, whose Close
## leads to the Stage Intro and on to the Stage Map. Arriving at an encounter there opens
## the Deckbox against its Villain, with Start; after the encounter the Stage Map opens
## again, or the Deckbox against the Boss after losing to it. Losing the last Heart ends
## the run at the main menu; beating the Boss leaves the Stage Map to say so.

const DECKBOX: String = "res://ui/deckbox/deckbox_screen.tscn"
const DECKBUILDER: String = "res://ui/deckbuilder/deckbuilder_screen.tscn"
const STAGE_INTRO: String = "res://ui/stage_map/stage_intro.tscn"
const STAGE_MAP: String = "res://ui/stage_map/stage_map_screen.tscn"
const MENU: String = "res://ui/menu/main_menu.tscn"

static var run: Run = null
## The Villain the Deckbox shows before an encounter, or null when it is opened to close.
static var villain: Villain = null
## Whether the deckbuilder is open from the Deckbox, and on which Deck (null for a new one).
static var is_editing: bool = false
static var deck_to_edit: Deck = null
## Where the Deckbox's Close goes.
static var back_from_deckbox: String = MENU


static func clear() -> void:
	run = null
	villain = null
	is_editing = false
	deck_to_edit = null
	back_from_deckbox = MENU


## Begins [param new_run] and says which scene to open: the Deckbox, with Close, which
## leads to the Stage Intro.
static func start(new_run: Run) -> String:
	clear()
	run = new_run
	back_from_deckbox = STAGE_INTRO
	return DECKBOX


## The Stage Intro is over; says which scene to open: the Stage Map, which the Deckbox's
## Close now leads back to.
static func finish_intro() -> String:
	back_from_deckbox = STAGE_MAP
	return STAGE_MAP


## The Deckbox opened from the Stage Map's Run Bar, with Close.
static func open_deckbox() -> String:
	villain = null
	return DECKBOX


## The Hero has arrived at a Node; says which scene to open: the Deckbox against its
## Villain if it is an encounter, or "" to stay on the Stage Map.
static func arrive() -> String:
	if not run.stage_visit.must_play():
		return ""
	villain = run.stage_visit.meeting
	return DECKBOX


## Counts the encounter's end and says which scene to open next.
static func finish_encounter(won: bool) -> String:
	run.record_encounter(won)
	if run.is_lost():
		clear()
		return MENU
	villain = null
	if run.stage_visit.must_play():
		villain = run.stage_visit.meeting
		return DECKBOX
	return STAGE_MAP


## The run is won and its notice closed; says which scene to open: the main menu.
static func finish_run() -> String:
	clear()
	return MENU


## Opens [param deck] in the deckbuilder, or a new Deck if it is null, and says which scene
## that is.
static func edit(deck: Deck) -> String:
	is_editing = true
	deck_to_edit = deck
	return DECKBUILDER


static func finish_editing() -> String:
	is_editing = false
	deck_to_edit = null
	return DECKBOX
