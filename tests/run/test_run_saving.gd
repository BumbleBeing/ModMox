extends GutTest
## Milestone 21: the run is saved each time a run's Screen opens, never during an encounter,
## and Continue reopens the Screen it was saved on (ADR 0074). An encounter quit and
## continued starts over with the same Encounter Seed. Winning, losing or abandoning the run
## deletes the save.

const FOLDER: String = "user://test_run_saving/"
const PATH: String = FOLDER + "run.json"
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"


func before_each() -> void:
	RunFlow.clear()
	RunFlow.use_storage(PATH, "")


func after_each() -> void:
	RunFlow.clear()
	RunFlow.use_storage("", "")
	for file: String in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER + file)
	DirAccess.remove_absolute(FOLDER)


## S2: starting a run saves it on the Deckbox, whose Close leads to the Stage Intro.
func test_starting_a_run_saves_it_on_the_deckbox() -> void:
	var run: Run = _run()

	RunFlow.start(run)

	assert_eq(_saved_screen(), "DECKBOX")
	assert_eq(_saved()["back_from_deckbox"], "STAGE_INTRO")


## S2: the run is saved as each of its Screens opens: the Stage Intro, the Stage Map, the
## Deckbox against a Villain on arriving at an encounter, the Spoils after a win, the Stage
## Map after them, and the Deckbox again after the deckbuilder.
func test_the_run_is_saved_as_each_of_its_screens_opens() -> void:
	var run: Run = _run()
	RunFlow.start(run)

	assert_eq(RunFlow.close_deckbox(), RunFlow.Screen.STAGE_INTRO)
	assert_eq(_saved_screen(), "STAGE_INTRO")
	RunFlow.finish_intro()
	assert_eq(_saved_screen(), "STAGE_MAP")
	_move_to_an_encounter(run)
	RunFlow.arrive()
	assert_eq(_saved_screen(), "DECKBOX")
	assert_eq(_saved_node(), run.stage_visit.current)
	RunFlow.begin_encounter()
	run.next_encounter_seed()
	RunFlow.finish_encounter(true)
	assert_eq(_saved_screen(), "SPOILS")
	RunFlow.finish_spoils()
	assert_eq(_saved_screen(), "STAGE_MAP")
	RunFlow.open_deckbox()
	assert_eq(_saved_screen(), "DECKBOX")
	RunFlow.edit(null)
	RunFlow.finish_editing()
	assert_eq(_saved_screen(), "DECKBOX")
	assert_eq(RunFlow.close_deckbox(), RunFlow.Screen.STAGE_MAP)
	assert_eq(_saved_screen(), "STAGE_MAP")


## S2: arriving at a Node that is not an encounter saves the run on the Stage Map, with the
## Hero on that Node.
func test_arriving_anywhere_saves_the_run_with_the_hero_there() -> void:
	var run: Run = _on_the_map()
	run.move_to(run.stage_visit.choices()[0])

	assert_eq(RunFlow.arrive(), RunFlow.Screen.NONE)

	assert_eq(_saved_screen(), "STAGE_MAP")
	assert_eq(_saved_node(), run.stage_visit.current)


## S2: nothing is saved during an encounter, nor in the deckbuilder.
func test_nothing_is_saved_during_an_encounter_or_in_the_deckbuilder() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)
	RunFlow.arrive()
	var before: String = FileAccess.get_file_as_string(PATH)

	RunFlow.begin_encounter()
	run.next_encounter_seed()
	run.gold += 5

	assert_eq(FileAccess.get_file_as_string(PATH), before)
	RunFlow.finish_encounter(false)
	RunFlow.open_deckbox()
	before = FileAccess.get_file_as_string(PATH)
	RunFlow.edit(null)
	assert_eq(FileAccess.get_file_as_string(PATH), before)


## S2: Continue reopens the Screen the run was saved on, with the run as it was.
func test_continue_reopens_the_screen_the_run_was_saved_on() -> void:
	var run: Run = _on_the_map()
	run.move_to(run.stage_visit.choices()[0])
	RunFlow.arrive()
	var node: int = run.stage_visit.current

	RunFlow.clear()
	assert_eq(RunFlow.continue_run(SavedRun.read(PATH)), RunFlow.Screen.STAGE_MAP)

	assert_eq(RunFlow.run.stage_visit.current, node)
	assert_eq(RunFlow.run.run_seed, run.run_seed)
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_MAP)
	assert_null(RunFlow.villain)


## S2: a run saved on the Deckbox before an encounter continues there, against the Villain.
func test_continue_on_the_deckbox_before_an_encounter_faces_its_villain() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)
	RunFlow.arrive()
	var villain: String = run.stage_visit.meeting.resource_path

	RunFlow.clear()
	assert_eq(RunFlow.continue_run(SavedRun.read(PATH)), RunFlow.Screen.DECKBOX)

	assert_eq(RunFlow.villain.resource_path, villain)
	assert_eq(RunFlow.villain, RunFlow.run.stage_visit.meeting)


## S2: a run saved on the Spoils screen continues there, with the Spoils it was paid.
func test_continue_on_the_spoils_shows_the_spoils_paid() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)
	RunFlow.arrive()
	RunFlow.begin_encounter()
	RunFlow.finish_encounter(true)
	var gold: int = run.gold

	RunFlow.clear()
	assert_eq(RunFlow.continue_run(SavedRun.read(PATH)), RunFlow.Screen.SPOILS)

	assert_eq(RunFlow.run.gold, gold)
	assert_eq(RunFlow.run.last_spoils.gold, run.last_spoils.gold)


## S3: an encounter quit and continued reopens the Deckbox against the same Villain, and the
## encounter is dealt from the same Encounter Seed.
func test_an_encounter_quit_starts_over_with_the_same_encounter_seed() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)
	RunFlow.arrive()
	var villain: String = run.stage_visit.meeting.resource_path
	RunFlow.begin_encounter()
	var encounter_seed: int = run.next_encounter_seed()

	assert_eq(RunFlow.quit(), RunFlow.Screen.MENU)
	assert_null(RunFlow.run)
	assert_true(SavedRun.exists(PATH), "Quitting keeps the run saved.")
	assert_eq(RunFlow.continue_run(SavedRun.read(PATH)), RunFlow.Screen.DECKBOX)

	assert_eq(RunFlow.villain.resource_path, villain)
	assert_eq(RunFlow.run.next_encounter_seed(), encounter_seed)
	assert_eq(RunFlow.run.hearts, run.hearts, "A quit encounter costs no Heart.")


## Quitting elsewhere in a run saves it where it was left first, so nothing done there since
## the Screen opened is lost.
func test_quitting_away_from_an_encounter_saves_where_it_was_left() -> void:
	var run: Run = _on_the_map()
	RunFlow.open_deckbox()
	run.deckbox.set_active(run.deckbox.decks()[2])

	assert_eq(RunFlow.quit(), RunFlow.Screen.MENU)
	assert_eq(RunFlow.continue_run(SavedRun.read(PATH)), RunFlow.Screen.DECKBOX)

	assert_eq(RunFlow.run.deckbox.decks().find(RunFlow.run.deckbox.active()), 2)
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_MAP)


## S5: losing the last Heart deletes the save.
func test_losing_the_run_deletes_the_save() -> void:
	var run: Run = _on_the_map()
	run.hearts = 1
	_move_to_an_encounter(run)
	RunFlow.arrive()
	RunFlow.begin_encounter()

	assert_eq(RunFlow.finish_encounter(false), RunFlow.Screen.RUN_LOST)

	assert_false(SavedRun.exists(PATH))


## S5: beating the fifth Boss deletes the save.
func test_winning_the_run_deletes_the_save() -> void:
	var run: Run = Run.debug(4, null, Run.LAST_TIER)
	RunFlow.start(run)
	RunFlow.finish_intro()
	_walk_to_the_boss(run)
	RunFlow.arrive()
	RunFlow.begin_encounter()
	RunFlow.finish_encounter(true)
	assert_true(SavedRun.exists(PATH))

	assert_eq(RunFlow.finish_spoils(), RunFlow.Screen.RUN_WON)

	assert_false(SavedRun.exists(PATH))
	assert_eq(RunFlow.run, run, "Run Won still reads the run.")


## S5: abandoning the run deletes the save and goes to the main menu.
func test_abandoning_the_run_deletes_the_save() -> void:
	_on_the_map()

	assert_eq(RunFlow.abandon(), RunFlow.Screen.MENU)

	assert_false(SavedRun.exists(PATH))
	assert_null(RunFlow.run)


## Starting a new run replaces the saved one.
func test_starting_a_new_run_replaces_the_saved_one() -> void:
	_on_the_map()
	RunFlow.quit()

	RunFlow.start(Run.debug(9, load(KITTY_KEEP) as StageDefinition))

	assert_eq(int(_saved()["run"]["run_seed"]), 9)


## With no file to save to, a run that remembers its saves keeps its last snapshot in memory
## alone, as a replay does, and nothing is written; one that does not keeps none.
func test_with_no_file_the_run_is_saved_in_memory_alone() -> void:
	RunFlow.use_storage("", "")
	RunFlow.remembers_saves = true
	var run: Run = _on_the_map()
	run.move_to(run.stage_visit.choices()[0])

	RunFlow.arrive()

	assert_false(SavedRun.exists(PATH))
	assert_eq(int(RunFlow.last_save()["run"]["stage_visit"]["current"]), run.stage_visit.current)
	RunFlow.remembers_saves = false
	RunFlow.clear()
	RunFlow.start(_run())
	assert_eq(RunFlow.last_save(), {})


func _run() -> Run:
	return Run.debug(5, load(KITTY_KEEP) as StageDefinition)


func _on_the_map() -> Run:
	var run: Run = _run()
	RunFlow.start(run)
	RunFlow.finish_intro()
	return run


func _saved() -> Dictionary:
	return SavedRun.read(PATH)


func _saved_screen() -> String:
	return str(_saved().get("screen", ""))


func _saved_node() -> int:
	return int(_saved()["run"]["stage_visit"]["current"])


func _move_to_an_encounter(run: Run) -> void:
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])


func _walk_to_the_boss(run: Run) -> void:
	while run.stage_visit.node().kind != StageMap.Kind.BOSS:
		if run.stage_visit.must_play():
			run.record_encounter(true)
		run.move_to(run.stage_visit.choices()[0])
