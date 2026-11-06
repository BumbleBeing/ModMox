extends GutTest
## CR 500: turns, phases and steps.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_first_turn_begins_with_the_starting_player_in_upkeep() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.VILLAIN_STARTS))

	assert_eq(Scenario.keep_all(engine), "")

	var state: MmGameState = engine.game_state()
	assert_eq(state.game_turn, 1)
	assert_eq(state.active_player_id, engine.villain().id)
	assert_eq(state.step, Step.UPKEEP, "Untap grants no priority, so upkeep is the first stop.")
	assert_eq(engine.pending_decision().player_id, engine.villain().id)


func test_the_starting_players_first_turn_has_no_draw_step() -> void:
	# CR 103.8a: in a two-player game the starting player skips their first draw step.
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	assert_eq(Scenario.play_until_game_turn(engine, 2), "")

	assert_eq(Scenario.steps_by_game_turn(engine)[1], [
		Step.UNTAP, Step.UPKEEP, Step.PRECOMBAT_MAIN,
		Step.BEGINNING_OF_COMBAT, Step.DECLARE_ATTACKERS, Step.END_OF_COMBAT,
		Step.POSTCOMBAT_MAIN, Step.END, Step.CLEANUP,
	])


func test_a_normal_turn_has_every_step_except_those_skipped_without_attackers() -> void:
	# CR 508.8: with no attackers, the declare blockers and combat damage steps are skipped.
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	assert_eq(Scenario.play_until_game_turn(engine, 3), "")

	assert_eq(Scenario.steps_by_game_turn(engine)[2], [
		Step.UNTAP, Step.UPKEEP, Step.DRAW, Step.PRECOMBAT_MAIN,
		Step.BEGINNING_OF_COMBAT, Step.DECLARE_ATTACKERS, Step.END_OF_COMBAT,
		Step.POSTCOMBAT_MAIN, Step.END, Step.CLEANUP,
	])


func test_each_draw_step_draws_one_card_for_the_active_player() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	assert_eq(Scenario.play_until_step(engine, 2, Step.DRAW), "")
	assert_eq(engine.villain().hand.size(), 8, "The non-starting player draws on their first turn.")
	assert_eq(engine.hero().hand.size(), 7)

	assert_eq(Scenario.play_until_step(engine, 3, Step.DRAW), "")
	assert_eq(engine.hero().hand.size(), 8, "The starting player draws from their second turn on.")


func test_turns_alternate_and_each_player_counts_their_own_turns() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	assert_eq(Scenario.play_until_game_turn(engine, 4), "")

	var turns: Array[String] = []
	for event: MmEvent in engine.event_log():
		if event is TurnStartedEvent:
			var started: TurnStartedEvent = event as TurnStartedEvent
			turns.append("game %d: player %d turn %d" % [started.game_turn, started.active_player_id, started.turn_number])
	var hero: int = engine.hero().id
	var villain: int = engine.villain().id
	assert_eq(turns, [
		"game 1: player %d turn 1" % hero,
		"game 2: player %d turn 1" % villain,
		"game 3: player %d turn 2" % hero,
		"game 4: player %d turn 2" % villain,
	])
	assert_eq(engine.hero().turn_number, 2)
	assert_eq(engine.villain().turn_number, 2)


func test_a_player_who_has_not_had_a_turn_is_on_turn_zero() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	assert_eq(Scenario.keep_all(engine), "")

	assert_eq(engine.hero().turn_number, 1)
	assert_eq(engine.villain().turn_number, 0)
