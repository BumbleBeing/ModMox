extends GutTest
## The Player View shows where the game is, so the GUI can show "<name>'s Turn N".

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_a_view_shows_the_active_players_turn_and_the_current_step() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	assert_eq(Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN), "")

	var view: MmPlayerView = engine.view_for(engine.villain())

	assert_eq(view.game_turn, 3)
	assert_eq(view.active_player_id, engine.hero().id)
	assert_eq(view.active_player_turn_number, 2, "Game turn 3 is the Hero's second turn.")
	assert_eq(view.step, Step.PRECOMBAT_MAIN)


func test_a_view_shows_who_has_priority() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	Scenario.keep_all(engine)

	assert_eq(engine.view_for(engine.villain()).priority_player_id, engine.hero().id)
	engine.submit(Scenario.pass_index(engine.pending_decision() as PriorityDecision))
	assert_eq(engine.view_for(engine.hero()).priority_player_id, engine.villain().id)


func test_nobody_has_priority_during_the_pregame() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	assert_eq(engine.view_for(engine.hero()).priority_player_id, MmGameState.NO_PLAYER)
