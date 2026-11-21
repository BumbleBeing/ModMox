extends GutTest
## How the debug run moves between screens (milestones 16 and 17): the Deckbox first, the
## Stage Intro, the Stage Map, the Deckbox before each encounter met there, the encounter,
## and back to the Stage Map, through the Spoils screen after a win (milestone 18); the Boss
## again after losing to it. A beaten Boss's Spoils lead to the next Tier's Stage Intro, and
## the fifth Boss's to Run Won, the Credits and the main menu; the last Heart lost leads to
## Run Lost and the main menu (milestone 19).


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


## T10: a won encounter opens the Spoils screen, and the Spoils screen the Stage Map.
func test_winning_an_encounter_opens_the_spoils_then_the_stage_map() -> void:
	var run: Run = _on_the_map()
	_move_to_an_encounter(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(true), RunFlow.Screen.SPOILS)
	assert_not_null(run.last_spoils)
	assert_null(RunFlow.villain)
	assert_eq(RunFlow.finish_spoils(), RunFlow.Screen.STAGE_MAP)
	assert_false(run.stage_visit.must_play())


func test_losing_to_the_boss_opens_the_deckbox_against_it_again() -> void:
	var run: Run = _on_the_map()
	_walk_to_the_boss(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(false), RunFlow.Screen.DECKBOX)
	assert_eq(RunFlow.villain, run.stage_visit.boss)


## T9: a Boss beaten at Tiers 1 to 4 pays its Spoils, whose Continue opens the next Tier's
## Stage Intro and then its Stage Map, on its Start Node.
func test_a_beaten_bosss_spoils_lead_to_the_next_tiers_stage_intro() -> void:
	var run: Run = _on_the_map()
	_walk_to_the_boss(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(true), RunFlow.Screen.SPOILS)
	assert_eq(RunFlow.finish_spoils(), RunFlow.Screen.STAGE_INTRO)
	assert_eq(run.stage_visit.stage.tier, 2)
	assert_eq(RunFlow.finish_intro(), RunFlow.Screen.STAGE_MAP)
	assert_eq(run.stage_visit.node().kind, StageMap.Kind.START)
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_MAP)


## T9: the fifth Boss's Spoils open Run Won, whose Continue opens the Credits, which end at
## the main menu.
func test_the_fifth_bosss_spoils_lead_to_run_won_the_credits_and_the_main_menu() -> void:
	var run: Run = Run.debug(4, null, Run.LAST_TIER)
	RunFlow.start(run)
	RunFlow.finish_intro()
	_walk_to_the_boss(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(true), RunFlow.Screen.SPOILS)
	assert_eq(RunFlow.finish_spoils(), RunFlow.Screen.RUN_WON)
	assert_eq(RunFlow.run, run, "Run Won reads the run.")
	assert_eq(RunFlow.finish_run_won(), RunFlow.Screen.CREDITS)
	assert_eq(RunFlow.finish_credits(), RunFlow.Screen.MENU)
	assert_null(RunFlow.run)


## T9: losing the last Heart opens Run Lost, whose Main Menu goes there.
func test_losing_the_last_heart_opens_run_lost_then_the_main_menu() -> void:
	var run: Run = _on_the_map()
	run.hearts = 1
	_move_to_an_encounter(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(false), RunFlow.Screen.RUN_LOST)
	assert_eq(RunFlow.run, run, "Run Lost reads the run.")
	assert_null(RunFlow.villain)
	assert_eq(RunFlow.finish_run_lost(), RunFlow.Screen.MENU)
	assert_null(RunFlow.run)


## T9: losing the last Heart to the Boss opens Run Lost, not the Boss again.
func test_losing_the_last_heart_to_the_boss_opens_run_lost() -> void:
	var run: Run = _on_the_map()
	run.hearts = 1
	_walk_to_the_boss(run)
	RunFlow.arrive()

	assert_eq(RunFlow.finish_encounter(false), RunFlow.Screen.RUN_LOST)
	assert_eq(run.fell_to, run.stage_visit.boss)


## The Credits opened with no run, as the main menu will open them (milestone 35), lead
## back to the main menu.
func test_the_credits_without_a_run_lead_to_the_main_menu() -> void:
	assert_eq(RunFlow.finish_credits(), RunFlow.Screen.MENU)
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
