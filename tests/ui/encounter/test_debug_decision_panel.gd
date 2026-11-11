extends GutTest
## The Debug Decision Panel turns what is filled in on its forms into answers.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID

var _answers: Array = []


func before_each() -> void:
	_answers.clear()


func after_each() -> void:
	await wait_process_frames(2)


func test_each_blocker_blocks_the_attacker_chosen_for_it_or_nothing() -> void:
	var decision: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1, 2] as Array[int], [7, 8] as Array[int],
		{1: [7, 8], 2: [8]} as Dictionary[int, Array], {1: 1, 2: 1} as Dictionary[int, int])
	var panel: DebugDecisionPanel = _panel(decision)
	assert_eq(panel.pair_choice(0).item_count, 3, "No block, or either attacker.")
	assert_eq(panel.pair_choice(0).get_item_text(0), "no block")

	panel.pair_choice(0).select(2)
	panel.submit_button().pressed.emit()

	assert_eq(_answers, [[[1, 8]]], "The first blocker blocks its second attacker; the other blocks nothing.")
	assert_eq(decision.validate(_answers[0]), "")


func test_blocking_with_nothing_is_an_empty_answer() -> void:
	var decision: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1] as Array[int], [7] as Array[int],
		{1: [7]} as Dictionary[int, Array], {1: 1} as Dictionary[int, int])
	var panel: DebugDecisionPanel = _panel(decision)

	panel.submit_button().pressed.emit()

	assert_eq(_answers, [[]])


func test_damage_is_divided_as_the_boxes_say() -> void:
	var decision: DivideCombatDamageDecision = DivideCombatDamageDecision.new(HERO, 3, 5,
		[MmReference.to_object(1), MmReference.to_object(2)] as Array[MmReference], [2, 3] as Array[int])
	var panel: DebugDecisionPanel = _panel(decision)
	assert_eq(panel.share_box(0).max_value, 5.0)

	panel.share_box(0).value = 2
	panel.share_box(1).value = 3
	panel.submit_button().pressed.emit()

	assert_eq(_answers, [[2, 3]])
	assert_eq(decision.validate(_answers[0]), "")


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


func test_triggers_are_submitted_in_the_order_picked() -> void:
	var decision: OrderTriggersDecision = OrderTriggersDecision.new(HERO, [] as Array[PendingTrigger])
	decision.source_object_ids = [1, 2]
	decision.source_card_ids = [1, 2]
	decision.descriptions = ["first", "second"]
	var panel: DebugDecisionPanel = _panel(decision)

	panel.option_buttons()[1].pressed.emit()
	panel.option_buttons()[0].pressed.emit()
	panel.submit_button().pressed.emit()

	assert_eq(_answers, [[1, 0]])
	assert_eq(decision.validate(_answers[0]), "")


func test_pointing_at_an_option_says_which_object_it_is_about() -> void:
	var pointed: Array[int] = []
	var panel: DebugDecisionPanel = _panel(DeclareAttackersDecision.new(HERO, [4, 5] as Array[int]))
	panel.option_pointed.connect(func(object_id: int) -> void: pointed.append(object_id))

	panel.option_buttons()[1].mouse_entered.emit()
	panel.option_buttons()[1].mouse_exited.emit()

	assert_eq(pointed, [5, DebugDecisionForm.NONE] as Array[int])


func _panel(decision: MmPendingDecision) -> DebugDecisionPanel:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.view.viewer_id = HERO
	snapshot.decision = decision
	var panel: DebugDecisionPanel = DebugDecisionPanel.new()
	add_child_autofree(panel)
	panel.answered.connect(func(answer: Variant) -> void: _answers.append(answer))
	panel.show_snapshot(snapshot, "")
	return panel
