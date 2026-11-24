extends GutTest
## A land that may be paid for to enter untapped on the Encounter Screen (game ADR 0067).
## The Hero plays a Shock Forest Plains ("As this land enters, you may pay 2 life. If you
## don't, it enters tapped."); while asked, it waits in the hand glowing white, the Info
## Panel reads "Have Shock Forest Plains enter untapped?" with "Pay 2 life" and "No" in its
## Answer Row and neither selected, so the Pass Button reads "Choose an answer". A click on
## either answers at once (game ADR 0066's addendum); once Left or Right has selected one,
## the Pass Button reads it over SPACE and gives it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const CombatAgent := preload("res://tests/ui/encounter/support/combat_agent.gd")
const SCREEN: Vector2 = Vector2(1920, 1080)
const SHOCK: String = "Shock Forest Plains"

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_the_info_panel_asks_what_paying_does_with_the_cost_on_the_left_and_nothing_selected() -> void:
	_open_asked()
	var panel: InfoPanel = _screen.info_panel()

	assert_eq(panel.prompt_text(), "Have Shock Forest Plains enter untapped?")
	assert_eq(panel.owed_pip_names(), [] as Array[String])
	assert_eq(panel.affirmative_text(), "Pay 2 life")
	assert_eq(panel.no_button().text, "No")
	assert_null(panel.cancel_button())
	assert_eq(panel.selected(), InfoPanel.NOTHING, "A question that costs life starts on nothing.")
	assert_eq(_screen.pass_button().shown_text(), "Choose an answer")
	assert_true(_screen.pass_button().disabled)


func test_the_land_being_played_waits_in_the_hand_glowing_white() -> void:
	_open_asked()

	var in_hand: int = _shock_card_id()
	assert_ne(in_hand, -1, "Still in the hand.")
	assert_eq(BorderEffects.glow_color(_screen.hand_strip().face_of(in_hand)), Color.WHITE)


func test_the_pass_key_does_nothing_until_an_answer_is_selected() -> void:
	_open_asked()
	var asked: MmPendingDecision = _presenter.snapshot().decision

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().decision, asked)


func test_a_click_on_pay_pays_at_once() -> void:
	_open_asked()
	var life: int = _presenter.snapshot().view.life_totals[MmEncounterSetup.HERO_PLAYER_ID]

	_screen.info_panel().affirmative_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().view.life_totals[MmEncounterSetup.HERO_PLAYER_ID], life - 2)
	assert_false(_land().is_tapped)


func test_selecting_pay_with_a_key_makes_the_pass_button_read_it_and_the_pass_key_pays() -> void:
	_open_asked()
	var life: int = _presenter.snapshot().view.life_totals[MmEncounterSetup.HERO_PLAYER_ID]

	_screen.press_key(KEY_LEFT)

	assert_true(_presenter.snapshot().decision is ChooseYesOrNoDecision, "Selecting pays nothing.")
	assert_eq(_screen.pass_button().shown_text(), "Pay 2 life")
	assert_eq(_screen.pass_button().key_text(), "SPACE")
	assert_false(_screen.pass_button().disabled)

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().view.life_totals[MmEncounterSetup.HERO_PLAYER_ID], life - 2)
	assert_false(_land().is_tapped)


func test_a_click_on_no_has_it_enter_tapped_at_once() -> void:
	_open_asked()
	var life: int = _presenter.snapshot().view.life_totals[MmEncounterSetup.HERO_PLAYER_ID]

	_screen.info_panel().no_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_land().is_tapped)
	assert_eq(_presenter.snapshot().view.life_totals[MmEncounterSetup.HERO_PLAYER_ID], life)


func test_no_selected_with_a_key_is_given_by_the_pass_button() -> void:
	_open_asked()

	_screen.press_key(KEY_RIGHT)
	assert_eq(_screen.pass_button().shown_text(), "No")
	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_land().is_tapped)


func _land() -> MmObjectView:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == SHOCK:
			return permanent
	return null


func _shock_card_id() -> int:
	for in_hand: MmObjectView in _presenter.snapshot().view.hand:
		if in_hand.name == SHOCK:
			return in_hand.card_id
	return -1


## Opens the screen with the Hero holding a Shock Forest Plains, and plays it in the main
## phase of Game Turn 1.
func _open_asked() -> void:
	var hero_deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.shock_land("Forest", "Plains"),
		Scenario.basic_land("Plains")])
	var villain_deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.basic_land("Forest")])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(hero_deck, villain_deck,
			MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		if Scenario.names(engine, engine.hero().hand).has(SHOCK):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(chosen, CombatAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	for attempt: int in 20:
		var snapshot: EncounterSnapshot = _presenter.snapshot()
		if snapshot.decision is PriorityDecision and snapshot.view.step == MmTurn.Step.PRECOMBAT_MAIN:
			break
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	for index: int in priority.actions.size():
		var play: PlayLandAction = priority.actions[index] as PlayLandAction
		if play != null and EncounterSnapshot.name_in(_presenter.snapshot().view, play.object_id) == SHOCK:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			break
	assert_true(_presenter.snapshot().decision is ChooseYesOrNoDecision, "The question was never asked.")
