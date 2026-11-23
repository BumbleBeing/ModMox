extends GutTest
## "Up to N" targets on the Encounter Screen (game ADR 0022): each permanent that can be
## targeted glows as a target, a click picks it (white, where it stands, never turned) or
## lets it go, and the click that leaves nothing more to pick answers. Fewer are answered
## with the pass button, "No targets" with none picked and "Confirm targets" otherwise, and
## a spell with nothing to target still waits for it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_targets_glow_as_targets_and_the_prompt_and_button_say_what_is_asked() -> void:
	_open_choosing_gird_targets()
	var bears: Array[int] = _bears()

	assert_eq(BorderEffects.glow_colors(_screen.face_of(bears[0])),
		[DecisionClicks.color_of(DecisionClicks.Kind.TARGET)] as Array[Color])
	assert_eq(_screen.info_panel().prompt_text(), "Choose up to two targets for Gird (0 of 2)")
	assert_eq(_screen.pass_button().shown_text(), "No targets")
	assert_false(_screen.pass_button().disabled, "None is an answer.")


func test_a_click_picks_a_target_white_where_it_stands_and_answers_nothing() -> void:
	_open_choosing_gird_targets()
	var bears: Array[int] = _bears()

	_screen.click_catcher(bears[0]).clicked.emit()

	assert_eq(BorderEffects.glow_colors(_screen.face_of(bears[0])), [Color.WHITE] as Array[Color])
	assert_false(_screen.is_drawn_tapped(bears[0]), "A target is not tapped.")
	assert_eq(_screen.info_panel().prompt_text(), "Choose up to two targets for Gird (1 of 2)")
	assert_eq(_screen.pass_button().shown_text(), "Confirm targets")
	assert_true(_presenter.snapshot().decision is ChooseTargetsDecision, "One more may be picked.")


func test_the_pick_that_reaches_the_most_answers_with_the_targets_picked() -> void:
	_open_choosing_gird_targets()
	var bears: Array[int] = _bears()
	_presenter.is_hold_key_down = true  # So it stays on the stack to be seen.

	_screen.click_catcher(bears[1]).clicked.emit()
	_screen.click_catcher(bears[0]).clicked.emit()
	_presenter.wait_until_idle()

	var stack: Array[MmObjectView] = _presenter.snapshot().view.stack
	assert_eq(stack.size(), 1)
	assert_eq(stack[0].targets.size(), 2)
	assert_eq(stack[0].targets[0].id, bears[1], "In the order picked.")
	assert_eq(stack[0].targets[1].id, bears[0])


func test_picking_the_only_target_answers_though_the_most_is_more() -> void:
	_open_choosing_gird_targets(1)
	var bears: Array[int] = _bears()
	_presenter.is_hold_key_down = true

	_screen.click_catcher(bears[0]).clicked.emit()
	_presenter.wait_until_idle()

	var stack: Array[MmObjectView] = _presenter.snapshot().view.stack
	assert_eq(stack.size(), 1)
	assert_eq(stack[0].targets.size(), 1)
	assert_eq(stack[0].targets[0].id, bears[0])


func test_with_nothing_to_target_the_pass_button_confirms_choosing_none() -> void:
	_open_choosing_gird_targets(0)
	assert_eq(_screen.info_panel().prompt_text(), "Choose up to two targets for Gird (0 of 2)")
	assert_eq(_screen.pass_button().shown_text(), "No targets")
	assert_not_null(_screen.info_panel().cancel_button(), "The cast may still be canceled.")
	_presenter.is_hold_key_down = true

	_screen.pass_priority()
	_presenter.wait_until_idle()

	var stack: Array[MmObjectView] = _presenter.snapshot().view.stack
	assert_eq(stack.size(), 1)
	assert_eq(stack[0].targets.size(), 0)


func test_the_pass_button_answers_with_the_targets_picked() -> void:
	_open_choosing_gird_targets()
	var bears: Array[int] = _bears()
	_presenter.is_hold_key_down = true  # So it stays on the stack to be seen.
	_screen.click_catcher(bears[1]).clicked.emit()

	_screen.pass_priority()
	_presenter.wait_until_idle()

	var stack: Array[MmObjectView] = _presenter.snapshot().view.stack
	assert_eq(stack.size(), 1)
	assert_eq(stack[0].targets.size(), 1)
	assert_eq(stack[0].targets[0].id, bears[1])


func test_a_pick_clicked_again_is_let_go_and_undo_takes_back_a_click() -> void:
	_open_choosing_gird_targets()
	var bears: Array[int] = _bears()

	_screen.click_catcher(bears[0]).clicked.emit()
	_screen.click_catcher(bears[0]).clicked.emit()
	assert_eq(_screen.card_picks().picked(), [] as Array[int])
	_screen.click_catcher(bears[1]).clicked.emit()
	_screen.undo()

	assert_eq(_screen.card_picks().picked(), [] as Array[int])
	assert_true(_presenter.snapshot().decision is ChooseTargetsDecision, "Nothing was answered.")


## The Hero's deck cycles free Bears and Gird, "Put a +1/+1 counter on each of up to two
## target creatures"; a seed deals two Bears and a Gird. The Hero casts [param bears_cast]
## of the Bears and begins casting Gird, which asks for its targets.
func _open_choosing_gird_targets(bears_cast: int = 2) -> void:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
	var cards: Array[MmCardDefinition] = Scenario.cycled([bear, bear.duplicate(), Scenario.free_gird()])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 40):
		chosen = Scenario.setup_with(cards, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var held: Array[String] = Scenario.names(MmEngine.start(chosen), MmEngine.start(chosen).hero().hand)
		if held.count("Bear") >= 2 and held.has("Gird"):
			break
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
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
	for cast: int in bears_cast:
		_cast("Bear", true)
	_cast("Gird", false)
	assert_true(_presenter.snapshot().decision is ChooseTargetsDecision, "Gird asks for its targets.")


## Begins casting the card named [param card_name] from the hand and, with
## [param resolves], lets it resolve.
func _cast(card_name: String, resolves: bool) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			while resolves and not _presenter.snapshot().view.stack.is_empty():
				_presenter.pass_priority()
				_presenter.wait_until_idle()
			return
	fail_test("No cast of %s." % card_name)


func _bears() -> Array[int]:
	var ids: Array[int] = []
	for seen: MmObjectView in _presenter.snapshot().view.battlefield:
		if seen.name == "Bear":
			ids.append(seen.id)
	ids.sort()
	return ids
