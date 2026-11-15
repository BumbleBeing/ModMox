extends GutTest
## How the debug run moves between screens (milestone 16): the Deckbox before each
## encounter, the encounter, and back to the Deckbox or, with no Hearts left, the main menu.


func before_each() -> void:
	RunFlow.clear()


func after_each() -> void:
	RunFlow.clear()


func test_starting_a_run_opens_the_deckbox_against_the_first_villain() -> void:
	var run: Run = Run.debug(4)
	var expected: String = Run.debug(4).next_villain()
	assert_eq(RunFlow.start(run), RunFlow.DECKBOX)
	assert_eq(RunFlow.run, run)
	assert_eq(RunFlow.villain, expected)


func test_a_win_returns_to_the_deckbox_against_the_next_villain() -> void:
	var run: Run = Run.debug(4)
	var twin: Run = Run.debug(4)
	twin.next_villain()
	RunFlow.start(run)
	assert_eq(RunFlow.finish_encounter(true), RunFlow.DECKBOX)
	assert_eq(RunFlow.villain, twin.next_villain())
	assert_eq(run.hearts, Run.STARTING_HEARTS)


func test_a_loss_costs_a_heart_and_returns_to_the_deckbox() -> void:
	var run: Run = Run.debug(4)
	RunFlow.start(run)
	assert_eq(RunFlow.finish_encounter(false), RunFlow.DECKBOX)
	assert_eq(run.hearts, Run.STARTING_HEARTS - 1)


func test_losing_the_last_heart_ends_the_run_at_the_main_menu() -> void:
	var run: Run = Run.debug(4)
	RunFlow.start(run)
	RunFlow.finish_encounter(false)
	RunFlow.finish_encounter(false)
	assert_eq(RunFlow.finish_encounter(false), RunFlow.MENU)
	assert_null(RunFlow.run)


func test_leaving_the_deckbuilder_returns_to_the_deckbox() -> void:
	RunFlow.start(Run.debug(4))
	RunFlow.edit(null)
	assert_true(RunFlow.is_editing)
	assert_eq(RunFlow.finish_editing(), RunFlow.DECKBOX)
	assert_false(RunFlow.is_editing)
