class_name RunFlow
extends RefCounted
## Where the debug run goes between screens (milestone 16), kept here because a scene is
## made afresh each time it is opened. The Deckbox opens before each encounter against the
## Villain drawn for it; a won or lost encounter comes back to it, and losing the last
## Heart ends the run at the main menu. Until the Stage Map exists the Deckbox's Close also
## leads to the main menu.

const DECKBOX: String = "res://ui/deckbox/deckbox_screen.tscn"
const DECKBUILDER: String = "res://ui/deckbuilder/deckbuilder_screen.tscn"
const MENU: String = "res://ui/menu/main_menu.tscn"

static var run: Run = null
## The deck name of the Villain the next encounter is against, or "" when none is drawn.
static var villain: String = ""
## Whether the deckbuilder is open from the Deckbox, and on which Deck (null for a new one).
static var is_editing: bool = false
static var deck_to_edit: Deck = null
## Where the Deckbox's Close goes.
static var back_from_deckbox: String = MENU


static func clear() -> void:
	run = null
	villain = ""
	is_editing = false
	deck_to_edit = null
	back_from_deckbox = MENU


## Begins [param new_run] and says which scene to open: the Deckbox, before its first
## encounter.
static func start(new_run: Run) -> String:
	clear()
	run = new_run
	villain = run.next_villain()
	return DECKBOX


## Counts the encounter's end and says which scene to open next.
static func finish_encounter(won: bool) -> String:
	run.record_encounter(won)
	if run.is_lost():
		clear()
		return MENU
	villain = run.next_villain()
	return DECKBOX


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
