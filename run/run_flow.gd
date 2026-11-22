class_name RunFlow
extends RefCounted
## Where the debug run goes between screens (milestones 16 and 17), kept here because a
## scene is made afresh each time it is opened. The run opens on the Deckbox, whose Close
## leads to the Stage Intro and on to the Stage Map. Arriving at an encounter there opens
## the Deckbox against its Villain, with Start; after a won encounter the Spoils screen
## (milestone 18) and then the Stage Map open, after a lost one the Stage Map at once, or
## the Deckbox against the Boss after losing to it. A beaten Boss's Spoils lead to the next
## Tier's Stage Intro, and the fifth Boss's to Run Won, then the Credits, then the main
## menu; losing the last Heart, at any Tier, leads to Run Lost and then the main menu
## (milestone 19).
##
## The run is saved as a snapshot each time one of its screens opens, never during an
## encounter, and Continue opens the Screen it was saved on (milestone 21, ADR 0074). An
## encounter quit starts over on Continue, dealt from the same Encounter Seed, since the
## snapshot was taken before the seed was drawn. Winning, losing or abandoning the run deletes
## the save and ends its Run Log, which is then handed to run_ended to be shared.

## The screens a run moves between. RunFlow says which comes next and never which scene it
## is: only the GUI knows that, so the run knows nothing of the scene tree. NONE means
## staying where the Hero is.
enum Screen { NONE, MENU, DECKBOX, DECKBUILDER, STAGE_INTRO, STAGE_MAP, SPOILS, RUN_WON, RUN_LOST, CREDITS }

static var run: Run = null
## The Villain the Deckbox shows before an encounter, or null when it is opened to close.
static var villain: Villain = null
## Whether the deckbuilder is open from the Deckbox, and on which Deck (null for a new one).
static var is_editing: bool = false
static var deck_to_edit: Deck = null
## Where the Deckbox's Close goes.
static var back_from_deckbox: Screen = Screen.MENU
## Where the run is saved, or "" to keep its snapshot in memory alone, as tests and the
## command line's debug runs do. use_storage() sets it.
static var save_path: String = ""
## Where Run Logs are written, or "" to keep a run's in memory alone.
static var log_folder: String = ""
## Called with the Run Log's path when a run ends, to share it; nothing when it is empty.
static var run_ended: Callable = Callable()
## Whether a run with no file to save to keeps its last snapshot in memory, as a replay of a
## Run Log does to take a run up again where a Continue did. Off, such a run saves nothing.
static var remembers_saves: bool = false

## The Screen the run is on, as RunFlow last said, and whether an encounter is being played.
static var _screen: Screen = Screen.NONE
static var _is_in_encounter: bool = false
## The last snapshot, as plain data.
static var _last_save: Dictionary = {}


## Saves runs to [param path] and writes their Run Logs into [param folder]; "" keeps either
## in memory alone.
static func use_storage(path: String, folder: String) -> void:
	save_path = path
	log_folder = folder


## Forgets the run in hand. Where runs are saved, and what is saved there, stay.
static func clear() -> void:
	run = null
	villain = null
	is_editing = false
	deck_to_edit = null
	back_from_deckbox = Screen.MENU
	_screen = Screen.NONE
	_is_in_encounter = false


## Begins [param new_run], in place of any run saved, with a Run Log of its own, and says
## which Screen opens: the Deckbox, with Close, which leads to the Stage Intro.
static func start(new_run: Run) -> Screen:
	clear()
	SavedRun.delete(save_path)
	_last_save = {}
	run = new_run
	run.use_log(RunLog.begin(log_folder, run.run_seed))
	run.run_log.record("run_started", run.beginning)
	back_from_deckbox = Screen.STAGE_INTRO
	return _saved_on(Screen.DECKBOX)


## Takes up the run saved as [param data], which is of this build's format
## (SavedRun.is_current()), writing on in its Run Log, and says which Screen opens: the one it
## was saved on, the Deckbox against the Villain being met if that was the Deckbox.
static func continue_run(data: Dictionary) -> Screen:
	clear()
	var saved: SavedRun = SavedRun.from_data(data)
	run = saved.run
	var log_path: String = Run.log_path_of(data["run"])
	run.use_log(RunLog.new(log_path if log_folder != "" else ""))
	back_from_deckbox = saved.back_from_deckbox
	if saved.screen == Screen.DECKBOX and run.stage_visit != null and run.stage_visit.must_play():
		villain = run.stage_visit.meeting
	run.run_log.record("continued", {"screen": Screen.keys()[saved.screen]})
	_last_save = data
	_screen = saved.screen
	return saved.screen


## The last snapshot taken, as plain data, or an empty Dictionary before any.
static func last_save() -> Dictionary:
	return _last_save


## The Stage Intro is over; says which Screen opens: the Stage Map, which the Deckbox's
## Close now leads back to.
static func finish_intro() -> Screen:
	back_from_deckbox = Screen.STAGE_MAP
	return _saved_on(Screen.STAGE_MAP)


## The Deckbox opened from the Stage Map's Run Bar, with Close.
static func open_deckbox() -> Screen:
	villain = null
	return _saved_on(Screen.DECKBOX)


## The Deckbox's Close; says which Screen opens: back_from_deckbox.
static func close_deckbox() -> Screen:
	return _saved_on(back_from_deckbox)


## The Hero has arrived at a Node; says which Screen opens: the Deckbox against its
## Villain if it is an encounter, or NONE to stay on the Stage Map.
static func arrive() -> Screen:
	if not run.stage_visit.must_play():
		_saved_on(Screen.STAGE_MAP)
		return Screen.NONE
	villain = run.stage_visit.meeting
	return _saved_on(Screen.DECKBOX)


## The Deckbox's Start: the encounter begins. Nothing is saved until it ends.
static func begin_encounter() -> void:
	_is_in_encounter = true


## Whether an encounter of the run is being played.
static func is_in_encounter() -> bool:
	return _is_in_encounter


## Counts the encounter's end and says which Screen opens next: Run Lost once the last
## Heart is gone, the run kept for it to show. [param record] is what the encounter logs: its
## answers, each with its words, then who won, the turns played and both players' life.
static func finish_encounter(won: bool, record: Dictionary = {}) -> Screen:
	_is_in_encounter = false
	if run.run_log != null:
		_log_answers(record)
		run.run_log.record("encounter_ended", {
			"won": won, "winner": record.get("winner", ""), "turns": record.get("turns", 0),
			"hero_life": record.get("hero_life", 0), "villain_life": record.get("villain_life", 0),
		})
	run.record_encounter(won)
	villain = null
	if run.is_lost():
		_end("lost")
		return Screen.RUN_LOST
	if run.stage_visit.must_play():
		villain = run.stage_visit.meeting
		return _saved_on(Screen.DECKBOX)
	if run.last_spoils != null:
		return _saved_on(Screen.SPOILS)
	return _saved_on(Screen.STAGE_MAP)


## The Spoils screen is closed; says which Screen opens: Run Won after the fifth Boss, the
## next Tier's Stage Intro after any other Boss, its Stage entered, and otherwise the Stage
## Map.
static func finish_spoils() -> Screen:
	if run.is_won():
		_end("won")
		return Screen.RUN_WON
	if run.is_stage_beaten():
		run.enter_next_stage()
		return _saved_on(Screen.STAGE_INTRO)
	return _saved_on(Screen.STAGE_MAP)


## The Pause Menu's Quit to main menu, in a run: the run stays saved and the main menu opens.
## Away from an encounter it is saved where it was left first. An encounter is left unsaved,
## to start over on Continue, and [param record] logs its answers so far.
static func quit(record: Dictionary = {}) -> Screen:
	if run != null:
		var where: String = "ENCOUNTER" if _is_in_encounter else Screen.keys()[_screen]
		if _is_in_encounter:
			_log_answers(record)
			_log("encounter_quit")
		elif _screen != Screen.NONE:
			_saved_on(_screen)
		_log("quit", {"screen": where})
	clear()
	return Screen.MENU


## The Pause Menu's Abandon Run, once confirmed: the run ends as abandoned, its save is
## deleted, and the main menu opens. [param record] logs the answers of an encounter left.
static func abandon(record: Dictionary = {}) -> Screen:
	if run != null:
		if _is_in_encounter:
			_log_answers(record)
			_log("encounter_quit")
		_end("abandoned")
	clear()
	return Screen.MENU


## Run Won's Continue; says which Screen opens: the Credits.
static func finish_run_won() -> Screen:
	return Screen.CREDITS


## Run Lost's Main Menu; the run is over, and the main menu opens.
static func finish_run_lost() -> Screen:
	clear()
	return Screen.MENU


## The Credits' Main Menu; any run is over, and the main menu opens.
static func finish_credits() -> Screen:
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
	return _saved_on(Screen.DECKBOX)


## Saves the run on [param screen], to the file if there is one and in memory always, and
## says that Screen.
static func _saved_on(screen: Screen) -> Screen:
	_screen = screen
	if run == null or (save_path == "" and not remembers_saves):
		return screen
	_last_save = SavedRun.data_of(run, screen, back_from_deckbox)
	if save_path != "":
		SavedRun.write(_last_save, save_path)
	return screen


## Ends the run [param how] ("won", "lost" or "abandoned"): its save is deleted, its Run Log
## says so, and the log is handed on to be shared.
static func _end(how: String) -> void:
	SavedRun.delete(save_path)
	_last_save = {}
	_log("run_ended", {"how": how})
	if run.run_log != null and run.run_log.path != "" and run_ended.is_valid():
		run_ended.call(run.run_log.path)


static func _log(kind: String, fields: Dictionary = {}) -> void:
	if run != null and run.run_log != null:
		run.run_log.record(kind, fields)


## Logs each of an encounter's answers in [param record], a line each.
static func _log_answers(record: Dictionary) -> void:
	for answer: Dictionary in record.get("answers", []):
		_log("answer", answer)
