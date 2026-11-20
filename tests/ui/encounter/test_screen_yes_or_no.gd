extends GutTest
## A "you may" on the Encounter Screen (game ADRs 0060 and 0066). As the Hero's "you may"
## ability resolves, the Info Panel asks "[ability]: [what yes does]?" with Yes and No in its
## Answer Row, Yes selected; a press or Left and Right only selects, and the Pass Button reads
## the Selected Answer and gives it. What the ability targets carries its dashed Stack Mark.
## Snarer is a 2/1 costing {0}: "When this creature enters, you may tap target creature.";
## it is the only creature, so it targets itself.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_the_info_panel_asks_with_yes_selected_and_the_pass_button_reads_it() -> void:
	_open_asked()
	var panel: InfoPanel = _screen.info_panel()

	assert_eq(panel.prompt_text(), "Snarer's ability: tap target creature?")
	assert_eq(panel.affirmative_button().text, "Yes")
	assert_eq(panel.no_button().text, "No")
	assert_eq(panel.selected(), InfoPanel.AFFIRMATIVE, "A \"you may\" starts on Yes.")
	assert_true(InfoPanel.is_lit(panel.affirmative_button()))
	assert_false(InfoPanel.is_lit(panel.no_button()))
	assert_eq(_screen.pass_button().shown_text(), "Yes")
	assert_eq(_screen.pass_button().key_text(), "SPACE")
	assert_false(_screen.pass_button().disabled)


func test_the_target_carries_its_dashed_stack_mark_while_asked() -> void:
	_open_asked()

	var face: Control = _screen.face_of(_target_id())
	assert_not_null(face)
	assert_not_null(BorderEffects.mark_color(face), "Marked without the cursor on the Stack Window.")
	assert_true(BorderEffects.is_mark_dashed(face), "Dashed, as a target's mark is.")


func test_the_pass_button_answers_yes() -> void:
	_open_asked()
	var target: int = _target_id()

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_true(_permanent(target).is_tapped)
	assert_null(_screen.info_panel().no_button(), "Nothing is asked any more.")
	assert_false(BorderEffects.mark_color(_screen.face_of(target)) != null, "Nor marked.")


func test_pressing_no_selects_it_and_answers_nothing_until_the_pass_key() -> void:
	_open_asked()
	var target: int = _target_id()
	var asked: MmPendingDecision = _presenter.snapshot().decision

	_screen.info_panel().no_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().decision, asked, "Still asked: a press only selects.")
	assert_eq(_screen.info_panel().selected(), InfoPanel.NO_ANSWER)
	assert_true(InfoPanel.is_lit(_screen.info_panel().no_button()))
	assert_false(InfoPanel.is_lit(_screen.info_panel().affirmative_button()))
	assert_eq(_screen.pass_button().shown_text(), "No")

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_false(_permanent(target).is_tapped)
	assert_true(_presenter.snapshot().view.stack.is_empty(), "The ability resolved all the same.")


func test_left_and_right_move_the_selected_answer_and_answer_nothing() -> void:
	_open_asked()
	var asked: MmPendingDecision = _presenter.snapshot().decision

	_screen.press_key(KEY_RIGHT)

	assert_eq(_screen.info_panel().selected(), InfoPanel.NO_ANSWER)
	assert_eq(_screen.pass_button().shown_text(), "No")

	_screen.press_key(KEY_LEFT)
	_presenter.wait_until_idle()

	assert_eq(_screen.info_panel().selected(), InfoPanel.AFFIRMATIVE)
	assert_eq(_screen.pass_button().shown_text(), "Yes")
	assert_eq(_presenter.snapshot().decision, asked, "Neither key answers.")


func test_the_border_flashes_for_the_question_and_not_for_priority() -> void:
	_open_asked()

	assert_gt(_screen.info_panel().flash_count(), 0, "The question flashed it.")
	var flashes: int = _screen.info_panel().flash_count()
	_screen.pass_priority()
	_presenter.wait_until_idle()
	assert_true(_presenter.snapshot().decision is PriorityDecision)

	assert_eq(_screen.info_panel().flash_count(), flashes, "Priority comes too often to flash.")


func _target_id() -> int:
	var asked: ChooseYesOrNoDecision = _presenter.snapshot().decision as ChooseYesOrNoDecision
	for item: MmObjectView in _presenter.snapshot().view.stack:
		if item.id == asked.stack_object_id:
			return item.targets[0].id
	return -1


func _permanent(object_id: int) -> MmObjectView:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.id == object_id:
			return permanent
	return null


## Opens the screen in the Hero's first main phase holding Snarer, casts it, and lets its
## trigger resolve to the yes or no.
func _open_asked() -> void:
	var deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.snarer(), Scenario.basic_land("Plains")])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([Scenario.basic_land("Forest")]),
			MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		if Scenario.names(engine, engine.hero().hand).has("Snarer"):
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
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == "Snarer":
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			break
	for attempt: int in 20:
		var decision: MmPendingDecision = _presenter.snapshot().decision
		if decision is ChooseYesOrNoDecision:
			return
		if decision is ChooseTargetDecision:
			assert_eq(_presenter.answer(0), "")
		else:
			_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("Snarer's yes or no was never asked.")
