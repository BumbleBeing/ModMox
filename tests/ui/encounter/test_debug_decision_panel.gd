extends GutTest
## The Debug Decision Panel turns what is filled in on its forms into answers.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID

var _answers: Array = []


func before_each() -> void:
	_answers.clear()


func after_each() -> void:
	await wait_process_frames(2)


func test_cards_are_numbered_in_the_order_picked_and_unpicked_by_picking_again() -> void:
	var decision: ChooseCardsToBottomDecision = ChooseCardsToBottomDecision.new(HERO, 2, [1, 2, 3] as Array[int])
	var panel: DebugDecisionPanel = _panel(decision)

	panel.option_buttons()[2].pressed.emit()
	panel.option_buttons()[0].pressed.emit()
	panel.option_buttons()[1].pressed.emit()
	panel.option_buttons()[1].pressed.emit()

	assert_string_starts_with(panel.option_buttons()[2].text, "[1]  ")
	assert_string_starts_with(panel.option_buttons()[0].text, "[2]  ")
	assert_eq(panel.submit_button().text, "Submit (2 chosen of 2)")
	panel.submit_button().pressed.emit()
	assert_eq(_answers, [[3, 1]])


func test_pointing_at_an_option_says_which_object_it_is_about() -> void:
	var pointed: Array[int] = []
	var panel: DebugDecisionPanel = _panel(ChooseCardsToDiscardDecision.new(HERO, 1, [4, 5] as Array[int]))
	panel.option_pointed.connect(func(object_id: int) -> void: pointed.append(object_id))

	panel.option_buttons()[1].mouse_entered.emit()
	panel.option_buttons()[1].mouse_exited.emit()

	assert_eq(pointed, [5, DebugDecisionForm.NONE] as Array[int])


func test_it_hides_when_the_hero_is_asked_nothing_it_answers() -> void:
	var cast: PriorityDecision = PriorityDecision.new(HERO, [PassAction.new(), CastSpellAction.new(3)] as Array[MmAction])
	var only_pass: PriorityDecision = PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])
	var pay: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 1, [] as Array[MmMana.Type])
	var target: ChooseTargetDecision = ChooseTargetDecision.new(HERO, 3, 0, [MmReference.to_player(HERO)] as Array[MmReference])

	assert_false(_panel(cast).visible, "A spell is cast from the hand (13e-1).")
	assert_false(_panel(only_pass).visible, "Passing has its own button.")
	assert_true(_panel(KeepOrMulliganDecision.new(HERO, 0, 0)).visible)
	assert_true(_panel(ChoosePlayOrDrawDecision.new(HERO)).visible)
	assert_false(_panel(pay).visible)
	assert_false(_panel(target).visible)
	assert_false(_panel(null).visible, "The Villain is deciding.")
	assert_true(_panel(ChooseCardsToDiscardDecision.new(HERO, 1, [4] as Array[int])).visible)
	assert_false(_panel(DeclareAttackersDecision.new(HERO, [4] as Array[int])).visible, "Attackers are clicked (A328).")
	assert_false(_panel(DeclareBlockersDecision.new(HERO, [1] as Array[int], [7] as Array[int],
		{1: [7]} as Dictionary[int, Array], {1: 1} as Dictionary[int, int])).visible)
	assert_false(_panel(DivideCombatDamageDecision.new(HERO, 3, 5,
		[MmReference.to_object(1), MmReference.to_object(2)] as Array[MmReference], [2, 3] as Array[int])).visible)
	var bare: DebugDecisionPanel = autofree(DebugDecisionPanel.new()) as DebugDecisionPanel
	assert_false(bare.has_method("pair_choice"))
	assert_false(bare.has_method("share_box"))


func test_picking_an_option_answers_with_its_number() -> void:
	var panel: DebugDecisionPanel = _panel(KeepOrMulliganDecision.new(HERO, 0, 0))

	panel.option_buttons()[1].pressed.emit()

	assert_eq(_answers, [KeepOrMulliganDecision.Choice.MULLIGAN])


func test_it_hides_once_the_encounter_is_over() -> void:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.view.is_over = true
	snapshot.decision = ChooseCardsToDiscardDecision.new(HERO, 1, [4] as Array[int])
	var panel: DebugDecisionPanel = DebugDecisionPanel.new()
	add_child_autofree(panel)

	panel.show_snapshot(snapshot)

	assert_false(panel.visible)


func _panel(decision: MmPendingDecision) -> DebugDecisionPanel:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.view.viewer_id = HERO
	snapshot.decision = decision
	var panel: DebugDecisionPanel = DebugDecisionPanel.new()
	add_child_autofree(panel)
	panel.answered.connect(func(answer: Variant) -> void: _answers.append(answer))
	panel.show_snapshot(snapshot)
	return panel
