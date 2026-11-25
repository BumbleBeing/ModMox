extends GutTest
## Exploring on the Encounter Screen (engine ADR 0090). An explore that reveals a nonland card
## opens the Surveil window with that one card, titled "Explore", its button reading
## "Graveyard", as a surveil of one card does; the Info Panel says what is asked, in the
## words the user was shown. Explorers are 1/1s costing {0}, "When this creature enters, it
## explores."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const FLIGHT: float = 0.4

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_an_explore_opens_the_surveil_window_titled_explore_with_its_one_card() -> void:
	_open_exploring()

	var window: SurveilWindow = _screen.surveil_window()
	var explore: ExploreDecision = _presenter.snapshot().decision as ExploreDecision
	assert_true(window.is_open(), "Opened by the explore itself.")
	assert_eq(window.title_text(), "Explore")
	assert_eq(window.entries(), explore.card_ids)
	assert_eq(window.graveyard_button().text, "Graveyard")
	assert_eq(_screen.info_panel().prompt_text(), "Explore: graveyard this card, or keep it on top.")
	assert_eq(_screen.pass_button().shown_text(), "Done")


func _advance(seconds: float) -> void:
	var frames: int = ceili(seconds / 0.01)
	for frame: int in frames:
		_screen.advance_motion(seconds / frames)
	_screen.advance_motion(0.000001)


## Opens the screen in the Hero's first main phase holding an Explorer, casts it, and lets
## its trigger resolve to its explore. Its deck holds no lands, so the card revealed is never
## one.
func _open_exploring() -> void:
	var deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.explorer(), Scenario.creature("Bear", 2, 2)])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		if Scenario.names(engine, engine.hero().hand).has("Explorer"):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.set_process(false)
	_screen.size = SCREEN
	_screen.flight_layer().seconds = 0.0
	_presenter = EncounterPresenter.new(chosen, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	for attempt: int in 10:
		if _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN:
			break
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == "Explorer":
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			break
	for attempt: int in 10:
		if _presenter.snapshot().decision is ExploreDecision:
			_advance(FLIGHT * 2.0)
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("The Explorer's explore was never asked.")
