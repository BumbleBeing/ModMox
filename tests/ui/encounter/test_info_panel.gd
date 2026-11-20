extends GutTest
## The Info Panel shows the prompt, what is owed and a refused answer's reason, all centered,
## over its Answer Row: a question's two answers, which a press only selects, or one action
## across its width. It gives way to an Option Menu row while one is pointed at (game ADR
## 0066).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const BOX: Rect2 = Rect2(352, 904.5, 360, 169.5)

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
	assert_true(panel.prompt_written().ends_with("\n{1}{R}{R}"), "What is owed is under the prompt, drawn as its symbols.")
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


func test_an_option_replaces_everything_and_clearing_it_puts_everything_back() -> void:
	var decision: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 1,
		[] as Array[MmMana.Type])
	var held: EncounterSnapshot = _snapshot(decision)
	held.is_holding_priority = true
	var panel: InfoPanel = _panel(held, "No.")

	panel.show_option("{2}, {T}: Deal Damage")

	assert_eq(panel.option_text(), "{2}, {T}: Deal Damage")
	assert_false(panel.shows_prompt())
	assert_false(panel._error.visible)
	assert_false(panel.cancel_button().visible)
	assert_true(panel.has_border(), "The box itself stays.")

	panel.show_option("")

	assert_eq(panel.option_text(), "")
	assert_true(panel.shows_prompt())
	assert_true(panel._error.visible)
	assert_true(panel.cancel_button().visible)


func test_while_auto_tap_pays_it_is_lit_and_shows_what_is_owed_and_a_cancel_button() -> void:
	var paying: EncounterSnapshot = _snapshot(null)
	paying.paying = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 2, [] as Array[MmMana.Type])
	var panel: InfoPanel = _panel(paying, "")

	assert_false(panel.is_dim(), "Nothing is asked, but something is happening for the Hero.")
	assert_true(panel.prompt_text().begins_with("Paying for"))
	assert_eq(panel.owed_pip_names(), ["2"] as Array[String])
	assert_not_null(panel.cancel_button())


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
	assert_gt(panel.prompt_rect().size.y, panel._line_height(panel.prompt_font_size()) * 1.5,
		"It goes on to a second line; none of it is cut off.")
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


func test_the_cancel_button_names_the_key_it_is_told() -> void:
	var decision: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 1,
		[MmMana.Type.RED] as Array[MmMana.Type])
	var panel: InfoPanel = _panel(_snapshot(decision), "")
	assert_eq(panel.cancel_button().text, "Cancel [X]")

	panel.show_cancel_key("BACKSPACE")

	assert_eq(panel.cancel_button().text, "Cancel [BACKSPACE]")
	panel.show_snapshot(_snapshot(decision), "", BOX)
	assert_eq(panel.cancel_button().text, "Cancel [BACKSPACE]", "A panel filled again still names it.")


func test_a_refusal_has_its_own_centered_line_above_the_answer_row_and_under_the_prompt() -> void:
	# Game ADR 0066: one line, or two when it must, growing upward from the row.
	var box: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["info"]
	var decision: PayManaDecision = PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 1,
		[MmMana.Type.RED] as Array[MmMana.Type])
	var panel: InfoPanel = InfoPanel.new()
	add_child_autofree(panel)

	panel.show_snapshot(_snapshot(decision), "Leonin Lightbringer has ward, and you can't pay for it.", box)

	var inside: Rect2 = Rect2(Vector2.ZERO, box.size)
	var cancel: Rect2 = Rect2(panel.cancel_button().position, panel.cancel_button().size)
	assert_true(inside.encloses(cancel), "Cancel is inside the panel.")
	assert_true(inside.encloses(panel.error_rect()), "The reason is inside it too,")
	assert_lt(panel.error_rect().end.y, cancel.position.y, "above the Answer Row and never over it,")
	assert_eq(panel._error.get_line_count(), 2, "on two lines when it must be,")
	assert_eq(panel._error.vertical_alignment, VERTICAL_ALIGNMENT_BOTTOM, "growing upward from the row,")
	assert_eq(panel._error.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "and centered.")
	var refusal_top: float = panel.error_rect().end.y - 2.0 * panel._error.get_line_height()
	assert_gt(refusal_top, panel.prompt_rect().end.y - 4.0, "Its two lines clear the prompt's.")


func test_an_action_fills_the_answer_row_from_side_to_side() -> void:
	var paying: InfoPanel = _panel(_snapshot(PayManaDecision.new(HERO, [PayWithManaAction.new(0)] as Array[MmAction], 1,
		[] as Array[MmMana.Type])), "")
	var attacking: InfoPanel = _panel(_snapshot(DeclareAttackersDecision.new(HERO, [1, 2] as Array[int])), "")

	for button: Button in [paying.cancel_button(), attacking.all_attack_button()]:
		assert_eq(Rect2(button.position, button.size), paying.row_rect(), button.text)
		assert_eq(button.get_theme_stylebox("normal"), SteelFrame.plate(InfoPanel.BUTTON, "normal", 44), "Framed in steel.")
	assert_eq(paying.row_rect(), Rect2(12, 113.5, 336, 44), "The bottom row, inset from the panel's sides.")


func test_the_text_above_the_row_is_centered() -> void:
	var blocks: DeclareBlockersDecision = DeclareBlockersDecision.new(HERO, [1] as Array[int], [7] as Array[int],
		{1: [7]} as Dictionary[int, Array], {1: 1} as Dictionary[int, int])
	var panel: InfoPanel = InfoPanel.new()
	add_child_autofree(panel)

	panel.show_snapshot(_snapshot(blocks), "No.", BOX, "Click a creature, then the attacker it blocks.")
	panel.show_option("{T}: Something")

	assert_eq(panel._prompt.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(panel._hint.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(panel._error.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(panel._option.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "An Option Menu row in full too.")


func test_a_prompt_that_would_need_a_third_line_is_drawn_smaller() -> void:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	var spell: MmObjectView = MmObjectView.new()
	spell.id = 20
	spell.card_id = 4
	spell.name = "Bushwhack"
	view.stack = [spell]
	var short: EncounterSnapshot = EncounterSnapshot.new()
	short.view = view
	short.decision = ChooseTargetDecision.new(HERO, 20, 0, [MmReference.to_player(HERO)] as Array[MmReference])
	var panel: InfoPanel = _panel(short, "")

	assert_eq(panel.prompt_font_size(), 22)

	panel.show_prompt("Taj-Nar Swordsmith's ability: search your library for an Equipment card with mana value 2 or less")

	assert_eq(panel.prompt_font_size(), 18, "Three lines at 22, so 18.")
	panel.show_prompt("Choose a target for Bushwhack (0 of 2)")
	assert_eq(panel.prompt_font_size(), 22, "And back.")


func test_it_is_dither_shaded_and_dim_only_while_nothing_is_asked() -> void:
	var asked: InfoPanel = _panel(_snapshot(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])), "")

	assert_true(asked._back.get_theme_stylebox("panel") is StyleBoxTexture, "A painted plate, not a flat fill.")
	assert_eq(asked._back.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_false(asked.is_dim())
	assert_true(_panel(_snapshot(null), "").is_dim())


func test_the_border_flashes_once_for_a_new_question_and_never_for_priority() -> void:
	var discard: EncounterSnapshot = _snapshot(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int]))
	var panel: InfoPanel = InfoPanel.new()
	add_child_autofree(panel)

	panel.show_snapshot(_snapshot(PriorityDecision.new(HERO, [] as Array[MmAction])), "", BOX)
	assert_eq(panel.flash_count(), 0, "Priority comes too often to flash.")
	panel.show_snapshot(discard, "", BOX)
	assert_eq(panel.flash_count(), 1)
	assert_eq(panel._flash.modulate.a, 1.0, "White at once, then it fades.")
	panel.show_snapshot(discard, "", BOX)
	assert_eq(panel.flash_count(), 1, "The same question redrawn does not flash again.")
	panel.show_snapshot(_snapshot(null), "", BOX)
	panel.show_snapshot(_snapshot(DeclareAttackersDecision.new(HERO, [1, 2] as Array[int])), "", BOX)
	assert_eq(panel.flash_count(), 2)
	await wait_seconds(InfoPanel.FLASH_TIME + 0.15)
	assert_almost_eq(panel._flash.modulate.a, 0.0, 0.01, "It settles.")


func test_all_attack_reads_undeclare_all_once_told_an_attacker_is_declared_and_turns_back() -> void:
	var events: Array[String] = []
	var panel: InfoPanel = _panel(_snapshot(DeclareAttackersDecision.new(HERO, [1, 2] as Array[int])), "")
	panel.all_attack_pressed.connect(func() -> void: events.append("all"))
	panel.undeclare_all_pressed.connect(func() -> void: events.append("none"))
	assert_eq(panel.all_attack_button().text, "Declare All")

	panel.show_undeclare(true)

	assert_eq(panel.all_attack_button().text, "Undeclare All")
	assert_true(BOX.encloses(panel.all_attack_button().get_global_rect()))
	panel.all_attack_button().pressed.emit()
	assert_eq(events, ["none"] as Array[String])

	panel.show_undeclare(false)

	assert_eq(panel.all_attack_button().text, "Declare All")
	panel.all_attack_button().pressed.emit()
	assert_eq(events, ["none", "all"] as Array[String])
	_panel(_snapshot(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])), "").show_undeclare(true)


func test_a_you_may_has_yes_and_no_as_the_halves_of_the_answer_row_and_a_press_only_selects() -> void:
	# Game ADR 0066: the Pass Button gives the Selected Answer.
	var said: Array[int] = []
	var panel: InfoPanel = _panel(_snapshot(ChooseYesOrNoDecision.new(HERO, 21, Scenario.draw_cards(1, Scenario.you()))), "")
	panel.answer_selected.connect(func(index: int) -> void: said.append(index))

	assert_eq(panel.affirmative_button().text, "Yes")
	assert_eq(panel.affirmative_text(), "Yes")
	assert_eq(panel.no_button().text, "No")
	var row: Rect2 = panel.row_rect()
	assert_eq(panel.affirmative_button().position, row.position, "The affirmative on the left,")
	assert_almost_eq(panel.no_button().position.x + panel.no_button().size.x, row.end.x, 0.01, "No on the right,")
	assert_almost_eq(panel.affirmative_button().size.x, panel.no_button().size.x, 0.01, "in equal halves")
	assert_almost_eq(panel.no_button().position.x - (row.position.x + panel.affirmative_button().size.x), InfoPanel.ROW_GAP, 0.01)
	assert_eq(panel.no_button().focus_mode, Control.FOCUS_NONE)
	assert_null(panel.cancel_button())
	panel.affirmative_button().pressed.emit()
	panel.no_button().pressed.emit()

	assert_eq(said, [InfoPanel.AFFIRMATIVE, InfoPanel.NO_ANSWER] as Array[int])
	assert_null(_panel(_snapshot(ChooseCardsToDiscardDecision.new(HERO, 1, [1] as Array[int])), "").no_button())
	panel.show_option("{T}: Something")
	assert_false(panel.no_button().visible, "An option replaces it like everything else.")
	assert_false(panel.affirmative_button().visible)


func test_the_selected_answer_is_lit_with_a_white_ring_and_a_brighter_face() -> void:
	var panel: InfoPanel = _panel(_snapshot(ChooseYesOrNoDecision.new(HERO, 21, Scenario.draw_cards(1, Scenario.you()))), "")
	assert_false(InfoPanel.is_lit(panel.affirmative_button()), "Nothing is lit until told.")
	assert_false(InfoPanel.is_lit(panel.no_button()))

	panel.show_selected(InfoPanel.AFFIRMATIVE)

	assert_eq(panel.selected(), InfoPanel.AFFIRMATIVE)
	assert_true(InfoPanel.is_lit(panel.affirmative_button()))
	assert_eq(panel.affirmative_button().get_theme_stylebox("normal"), SteelFrame.plate(InfoPanel.SELECTED, "normal", 44, true))
	assert_eq(panel.no_button().get_theme_stylebox("normal"), SteelFrame.plate(InfoPanel.BUTTON, "normal", 44, false))

	panel.show_selected(InfoPanel.NO_ANSWER)

	assert_true(InfoPanel.is_lit(panel.no_button()))
	assert_false(InfoPanel.is_lit(panel.affirmative_button()))
	panel.show_selected(InfoPanel.NOTHING)
	assert_false(InfoPanel.is_lit(panel.no_button()))


func test_a_cost_asked_reads_pay_and_its_cost_as_the_affirmative() -> void:
	var cost: MmManaCost = MmManaCost.new()
	cost.generic = 2
	var asked: ChooseYesOrNoDecision = ChooseYesOrNoDecision.new(HERO, 21, Scenario.draw_cards(1, Scenario.you()))
	asked.cost = cost
	var panel: InfoPanel = _panel(_snapshot(asked), "")

	assert_eq(panel.affirmative_text(), "Pay {2}")
	assert_eq(panel.affirmative_button().text, "", "Drawn with its symbol.")
	assert_true(panel.prompt_written().ends_with(": {2}"), "The cost follows the prompt on its line.")
