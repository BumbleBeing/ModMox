extends GutTest
## How the debug run moves between screens (milestones 16 and 17): the Deckbox first, the
## Stage Intro, the Stage Map, the Deckbox before each encounter met there, the encounter,
## and back to the Stage Map; the Boss again after losing to it; the main menu when the run
## is lost or, from the "Run won" notice, won.


func before_each() -> void:
	RunFlow.clear()


func after_each() -> void:
	RunFlow.clear()


## T11: the debug run opens the Deckbox with Close, then the Stage Intro, then the Stage Map.
func test_a_run_opens_the_deckbox_with_close_then_the_stage_intro_then_the_stage_map() -> void:
	var run: Run = Run.debug(4)

	assert_eq(RunFlow.start(run), RunFlow.Screen.DECKBOX)
	assert_eq(RunFlow.run, run)
	assert_null(RunFlow.villain, "No Villain: the Deckbox has Close.")
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_INTRO)
	assert_eq(RunFlow.finish_intro(), RunFlow.Screen.STAGE_MAP)
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_MAP)


func test_the_deckbox_opened_from_the_stage_map_has_close_and_leads_back_to_it() -> void:
	RunFlow.start(Run.debug(4))
	RunFlow.finish_intro()

	assert_eq(RunFlow.open_deckbox(), RunFlow.Screen.DECKBOX)
	assert_null(RunFlow.villain)
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_MAP)


func test_arriving_at_an_encounter_opens_the_deckbox_against_its_villain() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)

	assert_eq(RunFlow.arrive(), RunFlow.Screen.DECKBOX)
	assert_eq(RunFlow.villain, run.stage_visit.meeting)


func test_arriving_anywhere_else_opens_nothing() -> void:
	var run: Run = _on_the_map()
	run.move_to(run.stage_visit.choices()[0])

	assert_eq(run.stage_visit.node().kind, StageMap.Kind.STORE)
	assert_eq(RunFlow.arrive(), RunFlow.Screen.NONE)
	assert_null(RunFlow.villain)


func test_after_an_encounter_the_stage_map_opens_again() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(false), RunFlow.Screen.STAGE_MAP)
	assert_eq(run.hearts, Run.STARTING_HEARTS - 1)
	assert_null(RunFlow.villain)
	assert_false(run.stage_visit.must_play())


func test_losing_to_the_boss_opens_the_deckbox_against_it_again() -> void:
	var run: Run = _on_the_map()
	_walk_to_the_boss(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(false), RunFlow.Screen.DECKBOX)
	assert_eq(RunFlow.villain, run.stage_visit.boss)


func test_beating_the_boss_returns_to_the_stage_map_with_the_run_won() -> void:
	var run: Run = _on_the_map()
	_walk_to_the_boss(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(true), RunFlow.Screen.STAGE_MAP)
	assert_true(run.is_won())
	assert_eq(RunFlow.finish_run(), RunFlow.Screen.MENU)
	assert_null(RunFlow.run)


func test_losing_the_last_heart_ends_the_run_at_the_main_menu() -> void:
	var run: Run = _on_the_map()
	run.hearts = 1
	_move_to_an_encounter(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(false), RunFlow.Screen.MENU)
	assert_null(RunFlow.run)


func test_leaving_the_deckbuilder_returns_to_the_deckbox() -> void:
	RunFlow.start(Run.debug(4))
	RunFlow.edit(null)
	assert_true(RunFlow.is_editing)
	assert_eq(RunFlow.finish_editing(), RunFlow.Screen.DECKBOX)
	assert_false(RunFlow.is_editing)


func _on_the_map() -> Run:
	var run: Run = Run.debug(4)
	RunFlow.start(run)
	RunFlow.finish_intro()
	return run


func _move_to_an_encounter(run: Run) -> void:
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])


func _walk_to_the_boss(run: Run) -> void:
	while run.stage_visit.node().kind != StageMap.Kind.BOSS:
		if run.stage_visit.must_play():
			run.record_encounter(true)
		else:
			run.move_to(run.stage_visit.choices()[0])
