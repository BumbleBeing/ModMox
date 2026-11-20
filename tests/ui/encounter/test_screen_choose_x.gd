extends GutTest
## Choosing X on the Encounter Screen (game ADR 0063). The Hero's X Payer ("When this creature
## enters, you may pay {X}. If you do, you gain X life.") enters while their Mana Bird, which
## taps for {W}{W}{W}, is untapped, so X runs 0 to 3. The Info Panel reads "Pay {X} for X
## Payer?" with the X stepper, starting at the largest X worth paying, and "No" as the halves
## of its Answer Row, neither selected, so the Pass Button reads "Choose an answer" (game ADR
## 0066). Stepping selects the stepper, and the Pass Button then reads "Pay {3}". Paying by hand reads "Pay for X Payer:"
## with what is left after it, and has no Cancel.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_the_info_panel_asks_to_pay_x_with_the_stepper_and_no_and_neither_selected() -> void:
	_open_asked()
	var panel: InfoPanel = _screen.info_panel()

	assert_eq(panel.prompt_text(), "Pay {X} for X Payer?")
	var stepper: XStepper = panel.x_stepper()
	assert_not_null(stepper)
	assert_eq(stepper.amount_text(), "3", "Gaining life is worth every X, so the most.")
	assert_true(stepper.plus_button().disabled, "3 is all the Hero can pay.")
	assert_false(stepper.minus_button().disabled)
	assert_eq(panel.no_button().text, "No")
	assert_almost_eq(stepper.size.x, panel.no_button().size.x, 0.01, "The two halves of the Answer Row.")
	assert_null(panel.cancel_button())
	assert_eq(panel.selected(), InfoPanel.NOTHING)
	assert_false(stepper.is_selected())
	assert_eq(_screen.pass_button().shown_text(), "Choose an answer")
	assert_true(_screen.pass_button().disabled)


func test_stepping_selects_the_stepper_and_x_runs_from_0_to_the_most() -> void:
	_open_asked()

	_screen.info_panel().x_stepper().minus_button().pressed.emit()

	assert_true(_screen.info_panel().x_stepper().is_selected(), "A step selects paying.")
	assert_eq(_screen.info_panel().x_stepper().amount_text(), "2")
	assert_eq(_screen.pass_button().shown_text(), "Pay {2}")
	assert_eq(_screen.pass_button().key_text(), "SPACE")
	assert_false(_screen.info_panel().x_stepper().plus_button().disabled)
	for step: int in 3:
		_screen.info_panel().x_stepper().minus_button().pressed.emit()
	assert_eq(_screen.info_panel().x_stepper().amount_text(), "0", "Never below 0.")
	assert_true(_screen.info_panel().x_stepper().minus_button().disabled)
	assert_eq(_screen.pass_button().shown_text(), "Pay {0}")
	_screen.info_panel().x_stepper().plus_button().pressed.emit()
	assert_eq(_screen.info_panel().x_stepper().amount_text(), "1")


func test_a_press_on_the_stepper_selects_it_without_stepping() -> void:
	_open_asked()

	_screen.info_panel().x_stepper().pressed.emit()

	assert_true(_screen.info_panel().x_stepper().is_selected())
	assert_eq(_screen.info_panel().x_stepper().amount_text(), "3")
	assert_eq(_screen.pass_button().shown_text(), "Pay {3}")


func test_up_and_down_step_x_and_left_and_right_still_move_between_the_stepper_and_no() -> void:
	_open_asked()

	_screen.press_key(KEY_DOWN)

	assert_eq(_screen.info_panel().x_stepper().amount_text(), "2")
	assert_true(_screen.info_panel().x_stepper().is_selected())
	_screen.press_key(KEY_UP)
	_screen.press_key(KEY_UP)
	assert_eq(_screen.info_panel().x_stepper().amount_text(), "3", "Never above the most.")

	_screen.press_key(KEY_RIGHT)

	assert_eq(_screen.info_panel().selected(), InfoPanel.NO_ANSWER)
	assert_false(_screen.info_panel().x_stepper().is_selected())
	assert_eq(_screen.info_panel().x_stepper().amount_text(), "3", "Right does not step X.")
	assert_eq(_screen.pass_button().shown_text(), "No")
	_screen.press_key(KEY_LEFT)
	assert_true(_screen.info_panel().x_stepper().is_selected())
	assert_eq(_screen.pass_button().shown_text(), "Pay {3}")


func test_the_pass_key_does_nothing_until_an_answer_is_selected_and_then_pays() -> void:
	_open_asked()
	var asked: MmPendingDecision = _presenter.snapshot().decision

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().decision, asked, "Still asked: nothing is selected.")

	_screen.press_key(KEY_DOWN)
	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is PayManaDecision, "Paid by hand: Auto-tap is off in a test.")


func test_pay_pays_the_x_shown_by_hand_on_one_line_with_no_cancel() -> void:
	_open_asked()
	_screen.info_panel().x_stepper().minus_button().pressed.emit()

	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is PayManaDecision, "Paid by hand: Auto-tap is off in a test.")
	assert_eq(_screen.info_panel().prompt_text(), "Pay for X Payer:")
	assert_eq(_screen.info_panel().owed_pip_names(), ["2"] as Array[String])
	assert_eq(_screen.info_panel().prompt_written(), "Pay for X Payer: {2}", "On the prompt's line, not under it.")
	assert_null(_screen.info_panel().cancel_button(), "Nothing is being cast.")
	assert_eq(_presenter.answer(_bird_answer()), "")
	_presenter.wait_until_idle()
	assert_eq(_presenter.snapshot().view.life_totals[HERO], 22, "X = 2 life gained.")


func test_no_then_the_pass_key_declines_and_nothing_happens() -> void:
	_open_asked()

	_screen.info_panel().no_button().pressed.emit()
	assert_true(_presenter.snapshot().decision is ChooseXToPayDecision, "A press only selects.")
	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is PriorityDecision)
	assert_eq(_presenter.snapshot().view.stack.size(), 0)
	assert_eq(_presenter.snapshot().view.life_totals[HERO], 20)


func test_with_auto_tap_what_it_would_tap_for_the_x_shown_glows_and_it_pays() -> void:
	_open_asked()
	_presenter.set_auto_tapping(true)
	_screen.info_panel().x_stepper().plus_button().pressed.emit()

	assert_false(BorderEffects.glow_colors(_screen.face_of(_bird_id())).is_empty(), "The Mana Bird would be tapped.")
	for step: int in 3:
		_screen.info_panel().x_stepper().minus_button().pressed.emit()
	assert_true(BorderEffects.glow_colors(_screen.face_of(_bird_id())).is_empty(), "Nothing is tapped for X = 0.")
	_screen.info_panel().x_stepper().plus_button().pressed.emit()

	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is PriorityDecision, "Auto-tap paid.")
	assert_eq(_presenter.snapshot().view.life_totals[HERO], 21)


func _bird_id() -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == "Mana Bird":
			return permanent.id
	return -1


## The answer that taps the Mana Bird.
func _bird_answer() -> int:
	var paying: PayManaDecision = _presenter.snapshot().decision as PayManaDecision
	for index: int in paying.actions.size():
		if paying.actions[index] is ActivateAbilityAction:
			return index
	return -1


## Opens the screen, casts the Hero's Mana Bird on Game Turn 1, and the X Payer in the main
## phase of Game Turn 3, then passes until how much X to pay is asked.
func _open_asked() -> void:
	var hero_deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.mana_bird(), Scenario.x_payer(),
		Scenario.basic_land("Plains")])
	var villain_deck: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(hero_deck, villain_deck,
			MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		var hero_hand: Array = Scenario.names(engine, engine.hero().hand)
		if hero_hand.has("Mana Bird") and hero_hand.has("X Payer"):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(chosen, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	_answer_pregame()
	_play_to(1)
	_cast("Mana Bird")
	_play_to(3)
	_cast("X Payer")
	for attempt: int in 20:
		if _presenter.snapshot().decision is ChooseXToPayDecision:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("How much X to pay was never asked.")


func _answer_pregame() -> void:
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()


## Passes, declaring no attackers or blockers, until the Hero has priority with an empty
## stack in the main phase of Game Turn [param game_turn].
func _play_to(game_turn: int) -> void:
	for attempt: int in 200:
		var snapshot: EncounterSnapshot = _presenter.snapshot()
		var decision: MmPendingDecision = snapshot.decision
		if decision is PriorityDecision and snapshot.view.game_turn == game_turn \
				and snapshot.view.step == MmTurn.Step.PRECOMBAT_MAIN and snapshot.view.stack.is_empty():
			return
		if decision is DeclareAttackersDecision or decision is DeclareBlockersDecision:
			assert_eq(_presenter.answer([]), "")
		else:
			_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("Game Turn %d's main phase was never reached." % game_turn)


## Casts the Hero's card named [param card_name] from their hand.
func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("%s could not be cast." % card_name)
