extends GutTest
## The steps auto-pass stops at: one row for the Hero's turn and one for the Villain's.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID


func test_the_rows_start_with_their_default_stops() -> void:
	var stops: StepStops = StepStops.new()

	assert_true(stops.has_stop(HERO, MmTurn.Step.PRECOMBAT_MAIN))
	assert_false(stops.has_stop(HERO, MmTurn.Step.UPKEEP))
	assert_true(stops.has_stop(VILLAIN, MmTurn.Step.END))
	assert_false(stops.has_stop(VILLAIN, MmTurn.Step.PRECOMBAT_MAIN), "Each turn has its own row.")


func test_toggling_a_stop_sets_then_clears_it_on_that_row_only() -> void:
	var stops: StepStops = StepStops.new()

	stops.toggle(HERO, MmTurn.Step.UPKEEP)
	assert_true(stops.has_stop(HERO, MmTurn.Step.UPKEEP))
	assert_false(stops.has_stop(VILLAIN, MmTurn.Step.UPKEEP))

	stops.toggle(HERO, MmTurn.Step.UPKEEP)
	assert_false(stops.has_stop(HERO, MmTurn.Step.UPKEEP))


func test_untap_and_cleanup_never_hold_a_stop() -> void:
	# CR 502.4 and 514.3: no player normally gets priority in either step.
	var stops: StepStops = StepStops.new()

	stops.set_stop(HERO, MmTurn.Step.UNTAP, true)
	stops.toggle(VILLAIN, MmTurn.Step.CLEANUP)

	assert_false(StepStops.can_hold(MmTurn.Step.UNTAP))
	assert_false(StepStops.can_hold(MmTurn.Step.CLEANUP))
	assert_true(StepStops.can_hold(MmTurn.Step.DRAW))
	assert_false(stops.has_stop(HERO, MmTurn.Step.UNTAP))
	assert_false(stops.has_stop(VILLAIN, MmTurn.Step.CLEANUP))


func test_two_sets_of_stops_do_not_share_their_rows() -> void:
	var first: StepStops = StepStops.new()
	var second: StepStops = StepStops.new()

	first.toggle(HERO, MmTurn.Step.PRECOMBAT_MAIN)

	assert_true(second.has_stop(HERO, MmTurn.Step.PRECOMBAT_MAIN))
