extends GutTest
## The Info Panel shows the prompt, what is owed, a refused answer's reason, whether priority
## is held and the Cancel button, and gives way to an Option Menu row while one is pointed at.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const BOX: Rect2 = Rect2(352, 904, 300, 170)

var _cancels: int = 0


func before_each() -> void:
	_cancels = 0


func after_each() -> void:
	await wait_process_frames(2)


func test_it_fills_its_box_with_a_border_and_the_prompt() -> void:
	var panel: InfoPanel = _panel(_snapshot(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])), "")

	assert_eq(panel.position, BOX.position)
	assert_eq(panel.size, BOX.size)
	assert_true(panel.has_border())
	assert_false(panel.is_dim())
	assert_eq(panel.prompt_text(), "Discard 1 card (0 chosen)")
	assert_true(panel.shows_prompt())
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "It never takes a click meant for the board.")
	assert_null(panel.cancel_button())
	assert_eq(panel.owed_pip_names().size(), 0)


func test_it_is_dim_and_empty_when_nothing_is_asked_or_the_encounter_is_over() -> void:
	var idle: InfoPanel = _panel(_snapshot(null), "")
	var ended: EncounterSnapshot = _snapshot(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int]))
	ended.view.is_over = true
	var over: InfoPanel = _panel(ended, "")

	assert_true(idle.is_dim())
	assert_eq(idle.prompt_text(), "")
	assert_true(over.is_dim())
	assert_eq(over.prompt_text(), "")


func test_while_paying_it_shows_what_is_owed_as_pips_and_a_cancel_button() -> void:
	var decision: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 1,
		[MmMana.Type.RED, MmMana.Type.RED] as Array[MmMana.Type])
	var panel: InfoPanel = _panel(_snapshot(decision), "")

	assert_eq(panel.owed_pip_names(), ["1", "r", "r"] as Array[String])
	assert_not_null(panel.cancel_button())
	assert_true(BOX.encloses(panel.cancel_button().get_global_rect()), "Cancel is inside the panel.")

	panel.cancel_button().pressed.emit()

	assert_eq(_cancels, 1)


func test_a_refused_answers_reason_shows_only_when_there_is_one() -> void:
	var decision: ChooseCardsToDiscardDecision = ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])
	var refused: InfoPanel = _panel(_snapshot(decision), "That card cannot be discarded.")
	var fine: InfoPanel = _panel(_snapshot(decision), "")

	assert_eq(refused.error_text(), "That card cannot be discarded.")
	assert_true(refused._error.visible)
	assert_eq(fine.error_text(), "")
	assert_false(fine._error.visible)


func test_holding_priority_shows_while_the_key_is_down_or_a_hold_is_in_force() -> void:
	var decision: ChooseCardsToDiscardDecision = ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])
	var panel: InfoPanel = _panel(_snapshot(decision), "")
	assert_false(panel.shows_holding())

	panel.set_hold_key_down(true)
	assert_true(panel.shows_holding(), "The game is ready to hold (A304).")
	panel.set_hold_key_down(false)
	assert_false(panel.shows_holding())

	var held: EncounterSnapshot = _snapshot(decision)
	held.is_holding_priority = true
	panel.show_snapshot(held, "", BOX)
	assert_true(panel.shows_holding(), "A hold in force shows without the key.")

	panel.set_hold_key_down(true)
	panel.show_snapshot(_snapshot(decision), "", BOX)
	assert_true(panel.shows_holding(), "A redraw does not forget that the key is down.")


func test_an_option_replaces_everything_and_clearing_it_puts_everything_back() -> void:
	var decision: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 1,
		[] as Array[MmMana.Type])
	var held: EncounterSnapshot = _snapshot(decision)
	held.is_holding_priority = true
	var panel: InfoPanel = _panel(held, "No.")

	panel.show_option("{2}, {T}: Deal Damage")

	assert_eq(panel.option_text(), "{2}, {T}: Deal Damage")
	assert_false(panel.shows_prompt())
	assert_false(panel.shows_holding())
	assert_false(panel._error.visible)
	assert_false(panel.cancel_button().visible)
	assert_false(panel._pips[0].visible)
	assert_true(panel.has_border(), "The box itself stays.")

	panel.show_option("")

	assert_eq(panel.option_text(), "")
	assert_true(panel.shows_prompt())
	assert_true(panel.shows_holding())
	assert_true(panel._error.visible)
	assert_true(panel.cancel_button().visible)
	assert_true(panel._pips[0].visible)


func test_declaring_attackers_offers_all_attack_and_nothing_else_does() -> void:
	var events: Array[String] = []
	var panel: InfoPanel = _panel(_snapshot(DeclareAttackersDecision.new(HERO, [1, 2] as Array[int])), "")
	panel.all_attack_pressed.connect(func() -> void: events.append("all"))

	assert_eq(panel.prompt_text(), "Declare attackers")
	assert_not_null(panel.all_attack_button())
	assert_true(BOX.encloses(panel.all_attack_button().get_global_rect()))
	assert_null(panel.cancel_button(), "Declaring attackers is not a step of a cast.")
	panel.all_attack_button().pressed.emit()

	assert_eq(events, ["all"] as Array[String])
	assert_null(_panel(_snapshot(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])), "").all_attack_button())
	panel.show_option("{T}: Something")
	assert_false(panel.all_attack_button().visible, "An option replaces it like everything else.")


func test_a_hint_shows_under_the_prompt_only_when_there_is_one_and_something_is_asked() -> void:
	var blocks: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1] as Array[int], [7] as Array[int],
		{1: [7]} as Dictionary[int, Array], {1: 1} as Dictionary[int, int])
	var panel: InfoPanel = InfoPanel.new()
	add_child_autofree(panel)

	panel.show_snapshot(_snapshot(blocks), "", BOX, "Click a creature, then the attacker it blocks.")

	assert_eq(panel.prompt_text(), "Declare blockers")
	assert_eq(panel.hint_text(), "Click a creature, then the attacker it blocks.")
	assert_true(panel._hint.visible)
	assert_gt(panel._hint.position.y, panel._prompt.position.y, "Under the prompt.")
	panel.show_option("{T}: Something")
	assert_false(panel._hint.visible)

	panel.show_snapshot(_snapshot(blocks), "", BOX)
	assert_eq(panel.hint_text(), "")
	assert_false(panel._hint.visible)
	panel.show_snapshot(_snapshot(null), "", BOX, "A hint with nothing asked.")
	assert_eq(panel.hint_text(), "", "Nothing is asked, so there is nothing to explain.")


func test_a_long_prompt_wraps_inside_the_panel() -> void:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var spell: MmObjectView = MmObjectView.new()
	spell.id = 20
	spell.card_id = 4
	spell.name = "Merfolk of the Pearl Trident's Longer Cousin"
	view.stack = [spell]
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = view
	snapshot.decision = ChooseTargetDecision.new(HERO, 20, 0, [MmReference.to_player(HERO)] as Array[MmReference])

	var panel: InfoPanel = _panel(snapshot, "A reason long enough that it would run out of the side of the panel if it did not wrap.")

	assert_lt(panel._prompt.size.x, BOX.size.x)
	assert_lt(panel._error.size.x, BOX.size.x)
	assert_gt(panel._prompt.get_line_count(), 1, "It goes on to a second line; none of it is cut off.")
	assert_gt(panel._error.get_line_count(), 1)


func _snapshot(decision: MmPendingDecision) -> EncounterSnapshot:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.view.viewer_id = HERO
	snapshot.decision = decision
	return snapshot


func _panel(snapshot: EncounterSnapshot, error: String) -> InfoPanel:
	var panel: InfoPanel = InfoPanel.new()
	add_child_autofree(panel)
	panel.cancel_pressed.connect(func() -> void: _cancels += 1)
	panel.show_snapshot(snapshot, error, BOX)
	return panel
