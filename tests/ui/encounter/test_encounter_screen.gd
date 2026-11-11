extends GutTest
## The Encounter Screen draws each snapshot into its Regions and windows, and passes what
## the human does to the Encounter Presenter.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SlowAgent := preload("res://tests/ui/encounter/support/slow_agent.gd")
const Rule := MmEncounterSetup.StartingPlayerRule
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to.clear()


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_lands_and_other_permanents_stand_in_separate_rows() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()

	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)
	var land: Control = _screen.face_of(_permanent("Forest"))
	var bear: Control = _screen.face_of(_permanent("Bear"))

	assert_true(land is BattlefieldFace)
	assert_true(regions["hero_lands"].encloses(land.get_global_rect()), "The land is in the Hero's land row.")
	assert_true(regions["hero_nonlands"].encloses(bear.get_global_rect()), "The creature is nearer the middle.")


func test_other_permanents_stand_to_the_right_of_creatures_smaller_and_set_back() -> void:
	_open(_setup_of([_free_bear(), Scenario.artifact("Orb", [])]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	_do(CastSpellAction, "Orb")
	_presenter.wait_until_idle()

	var bear: Rect2 = _screen.face_of(_permanent("Bear")).get_global_rect()
	var orb: Rect2 = _screen.face_of(_permanent("Orb")).get_global_rect()

	assert_gt(orb.position.x, bear.end.x, "The artifact is to the creature's right.")
	assert_almost_eq(orb.size.y / bear.size.y, EncounterLayout.OTHERS_SCALE, 0.01)
	assert_gt(orb.get_center().y, bear.get_center().y, "Set back, toward the Hero's edge.")
	assert_not_null(_screen.line("hero_others"))
	assert_null(_screen.line("villain_others"), "The Villain has no such permanents.")


func test_a_line_of_creatures_keeps_its_faces_size_and_scrolls_when_it_overflows() -> void:
	_open(_setup_of([_free_bear()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	var alone: Vector2 = _screen.face_of(_permanent("Bear")).size
	var line: ScrollRow = _screen.line("hero_creatures")
	assert_false(line.can_scroll())
	assert_false(line.left_arrow().visible)
	assert_false(line.right_arrow().visible)
	for cast: int in 6:
		_do(CastSpellAction, "Bear")
		_presenter.wait_until_idle()

	line = _screen.line("hero_creatures")
	assert_eq(_screen.face_of(_permanent("Bear")).size, alone, "Seven Bears are each as big as one was.")
	assert_true(line.can_scroll())
	assert_false(line.left_arrow().visible, "It starts at its left end.")
	assert_true(line.right_arrow().visible)

	line.right_arrow().button_down.emit()

	assert_eq(line.offset(), ScrollRow.NUDGE)
	assert_true(line.left_arrow().visible, "Now it can scroll back.")
	line.left_arrow().button_down.emit()
	assert_eq(line.offset(), 0.0, "The left arrow scrolls the other way.")
	line.scroll_by(9000.0)
	assert_false(line.right_arrow().visible, "And at its right end, only back.")
	assert_lt(line.offset(), 500.0, "It stops at its right end, so one press of the left arrow moves it back.")
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)
	assert_almost_eq(_screen.face_of(_last_permanent("Bear")).get_global_rect().end.x,
		regions["hero_nonlands"].end.x - EncounterLayout.LINE_PAD, 0.5, "The last Bear is in view.")


func test_a_scrolled_line_keeps_its_place_when_the_screen_redraws() -> void:
	_open(_setup_of([_free_bear()]))
	_keep_and_reach_main()
	for cast: int in 7:
		_do(CastSpellAction, "Bear")
		_presenter.wait_until_idle()
	_screen.line("hero_creatures").scroll_by(50.0)

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_eq(_screen.line("hero_creatures").offset(), 50.0)


func test_once_attackers_are_declared_the_others_shrink_and_the_attacker_steps_forward() -> void:
	_open(_setup_of([_free_bear()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	for attempt: int in 60:
		if _presenter.snapshot().decision is DeclareAttackersDecision:
			break
		_screen.pass_priority()
		_presenter.wait_until_idle()
	var attacker: int = (_presenter.snapshot().decision as DeclareAttackersDecision).candidate_ids[0]
	var bystander: int = (_presenter.snapshot().decision as DeclareAttackersDecision).candidate_ids[1]
	var full: Vector2 = _screen.face_of(attacker).size
	var rest_y: float = _screen.face_of(attacker).get_global_rect().get_center().y
	assert_eq(_screen.face_of(bystander).size, full, "Before combat every creature is full size.")

	_presenter.answer([attacker] as Array[int])
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().view.battlefield.any(func(seen: MmObjectView) -> bool: return seen.is_attacking))
	assert_almost_eq(_screen.face_of(bystander).size.y / full.y, EncounterLayout.BYSTANDER_SCALE, 0.01)
	assert_eq(_screen.face_of(attacker).size, Vector2(full.y, full.x), "The attacker is full size, and tapped.")
	assert_almost_eq(rest_y - _screen.face_of(attacker).get_global_rect().get_center().y, EncounterLayout.COMBAT_STEP, 0.5,
		"It stepped toward the middle.")
	for attempt: int in 20:
		if _presenter.snapshot().view.step == MmTurn.Step.POSTCOMBAT_MAIN:
			break
		_screen.pass_priority()
		_presenter.wait_until_idle()
	assert_eq(_screen.face_of(bystander).size, full, "After combat they return to normal.")


func test_each_player_has_an_exile_pile_under_their_graveyard() -> void:
	_open(_bear_setup())
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)

	assert_eq(_screen.pile_text("hero_exile"), "Exile (0)")
	assert_eq(_screen.pile_text("villain_exile"), "Exile (0)")
	assert_eq(_screen.pile_text("hero_graveyard"), "Graveyard (0)")
	assert_eq(_screen.pile_text("hero_library"), "Library (33)")
	assert_gt(regions["hero_exile"].position.y, regions["hero_graveyard"].position.y)


func test_an_exiled_card_is_the_top_of_its_owners_exile_pile() -> void:
	_open(_setup_of([_free_bear(), Scenario.exile_spell("Banish")]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	var bear: int = _permanent("Bear")
	_do(CastSpellAction, "Banish")
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	for index: int in target.candidates.size():
		if target.candidates[index].is_object() and target.candidates[index].id == bear:
			_presenter.answer(index)
	_presenter.wait_until_idle()

	var exiled: MmObjectView = _presenter.snapshot().view.exiles[HERO][0]
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)

	assert_eq(_screen.pile_text("hero_exile"), "Exile (1)")
	assert_eq(_screen.pile_text("villain_exile"), "Exile (0)")
	assert_eq(_screen.pile_text("hero_graveyard"), "Graveyard (1)", "Banish itself went to the graveyard.")
	assert_true(_screen.face_of(exiled.id) is CardFace)
	assert_true(regions["hero_exile"].encloses(_screen.face_of(exiled.id).get_global_rect()))


func test_the_heros_hand_is_card_faces_and_the_villains_is_that_many_card_backs() -> void:
	_open(_bear_setup())

	var view: MmPlayerView = _presenter.snapshot().view

	assert_eq(_screen.villain_card_back_count(), 7)
	for card: MmObjectView in view.hand:
		assert_true(_screen.face_of(card.id) is CardFace)
	assert_eq(view.hand.size(), 7)


func test_the_stack_window_is_there_exactly_while_something_is_on_the_stack() -> void:
	_open(_shock_setup())
	_keep()
	_presenter.is_hold_key_down = true
	assert_false(_screen.stack_window().visible)

	_cast_at_the_villain("Zap")

	assert_true(_screen.stack_window().visible)
	assert_eq(_screen.stack_window().title_text(), "Stack (1)")
	assert_null(_screen.stack_window().close_button(), "It closes only when the stack empties.")
	assert_true(_screen.info_panel().shows_holding())

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_false(_screen.stack_window().visible)
	assert_eq(_screen.stack_window().title_text(), "Stack (0)")


func test_the_stack_window_lists_what_resolves_first_at_the_top() -> void:
	_open(_shock_setup())
	_keep()
	_presenter.is_hold_key_down = true

	_cast_at_the_villain("Zap")
	_cast_at_the_villain("Jolt")

	var entries: Array[ZoneEntry] = _screen.stack_entries()
	assert_eq(_screen.stack_window().title_text(), "Stack (2)")
	assert_eq(entries[0].name_text(), "Jolt", "Cast last, so it is on top and resolves first.")
	assert_eq(entries[1].name_text(), "Zap")
	assert_eq(entries[0].detail_text(), "Hero")


func test_the_stack_window_reopens_where_it_was_left() -> void:
	_open(_shock_setup())
	_keep()
	_presenter.is_hold_key_down = true
	_cast_at_the_villain("Zap")
	_screen.stack_window().drag_by(Vector2(-200, 60))
	var place: Vector2 = _screen.stack_window().position

	_screen.pass_priority()
	_presenter.wait_until_idle()
	_cast_at_the_villain("Zap")

	assert_true(_screen.stack_window().visible)
	assert_eq(_screen.stack_window().position, place)
	assert_true(EncounterLayout.regions(SCREEN)["battlefield"].encloses(
		Rect2(_screen.stack_window().position, _screen.stack_window().size)), "It stays within the battlefield.")


func test_each_players_emblems_open_in_their_own_window() -> void:
	var request: EncounterRequest = EncounterRequest.new()
	request.has_sample_emblems = true
	_open(request.setup())
	var window: ZoneWindow = _screen.emblems_window(HERO)
	assert_false(window.visible, "Closed until asked for.")

	_screen.player_panel(HERO).emblems_button().pressed.emit()

	assert_true(window.visible)
	assert_eq(window.title_text(), "Emblems (1)")
	assert_eq(window.body().get_child_count(), 1)
	assert_eq((window.body().get_child(0) as ZoneEntry).name_text(), "Sample Boon: Howling Winds")
	assert_false(_screen.emblems_window(VILLAIN).visible)
	assert_eq((_screen.emblems_window(VILLAIN).body().get_child(0) as ZoneEntry).name_text(), "Sample Hex: Ankh's Curse")

	window.close_button().pressed.emit()
	assert_false(window.visible)


func test_the_emblems_button_cannot_be_pressed_with_no_emblems() -> void:
	_open(_bear_setup())

	assert_true(_screen.player_panel(HERO).emblems_button().disabled)
	assert_eq(_screen.player_panel(HERO).emblems_button().text, "⛨  Emblems (0)")
	assert_eq(_screen.emblems_window(HERO).title_text(), "Emblems (0)")


func test_what_a_decision_can_choose_glows_on_the_thing_itself() -> void:
	_open(_shock_setup())
	_keep()
	var zap: int = _in_hand("Zap")

	assert_eq(BorderEffects.glow_color(_screen.face_of(zap)), DecisionClicks.color_of(DecisionClicks.Kind.OTHER))
	assert_eq(_screen.face_of(zap).get_node(BorderEffects.GLOW).get_parent(), _screen.face_of(zap),
		"The Glow is a child of the card, so it turns with it.")

	_do(CastSpellAction, "Zap")

	assert_eq(BorderEffects.glow_color(_screen.player_panel(VILLAIN)), DecisionClicks.color_of(DecisionClicks.Kind.TARGET))
	assert_eq(BorderEffects.glow_color(_screen.player_panel(HERO)), DecisionClicks.color_of(DecisionClicks.Kind.TARGET))
	assert_null(BorderEffects.glow_color(_screen.face_of(_in_hand("Jolt"))), "A card in hand is not a target.")


func test_pointing_at_a_panel_option_outlines_its_card_and_leaving_removes_it() -> void:
	_open(_shock_setup())
	_keep()
	var zap: int = _in_hand("Zap")

	_screen.debug_panel().option_pointed.emit(zap)
	assert_true(BorderEffects.has_pointer(_screen.face_of(zap)))

	_screen.debug_panel().option_pointed.emit(DebugDecisionForm.NONE)
	assert_false(BorderEffects.has_pointer(_screen.face_of(zap)))


func test_the_panels_options_answer_the_decision() -> void:
	_open(_bear_setup())
	assert_eq(_screen.debug_panel().heading_text(), "Keep this hand, or mulligan? (0 taken)")

	_screen.debug_panel().option_buttons()[0].pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is PriorityDecision)
	assert_eq(_screen.debug_panel().heading_text(), "Priority: choose an action")
	assert_eq(_screen.info_panel().error_text(), "")


func test_a_rejected_answer_shows_its_reason_in_the_info_panel_until_one_is_accepted() -> void:
	_open(_bear_setup())

	_screen.debug_panel().answered.emit(99)

	assert_ne(_screen.info_panel().error_text(), "")
	assert_true(_presenter.snapshot().decision is KeepOrMulliganDecision, "The same decision is still asked.")
	assert_eq(_screen.info_panel().prompt_text(), "Keep this hand, or mulligan? (0 taken)", "And still prompted for.")

	_screen.debug_panel().option_buttons()[0].pressed.emit()
	assert_eq(_screen.info_panel().error_text(), "", "The reason goes once an answer is accepted.")


func test_cancel_is_in_the_info_panel_only_on_the_steps_of_a_cast() -> void:
	_open(_shock_setup())
	_keep()
	assert_null(_screen.info_panel().cancel_button())

	_do(CastSpellAction, "Zap")
	assert_not_null(_screen.info_panel().cancel_button())
	assert_eq(_screen.info_panel().prompt_text(), "Choose a target for Zap")

	_screen.info_panel().cancel_button().pressed.emit()
	assert_true(_presenter.snapshot().decision is PriorityDecision)
	assert_eq(_presenter.snapshot().view.hand.size(), 7)
	assert_null(_screen.info_panel().cancel_button())


func test_attackers_are_picked_in_the_panel_and_submitted_together() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	for attempt: int in 60:
		if _presenter.snapshot().decision is DeclareAttackersDecision:
			break
		_play_a_land_or_pass()
	var bear: int = _permanent("Bear")

	_screen.debug_panel().option_buttons()[0].pressed.emit()
	assert_string_starts_with(_screen.debug_panel().option_buttons()[0].text, "[1]  Bear")
	_screen.debug_panel().submit_button().pressed.emit()
	_presenter.wait_until_idle()
	for attempt: int in 10:
		if _presenter.snapshot().view.life_totals[VILLAIN] != 20:
			break
		_screen.pass_priority()
		_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().view.life_totals[VILLAIN], 18, "The Bear attacked and was not blocked.")
	assert_true(_presenter.snapshot().view.battlefield.any(func(seen: MmObjectView) -> bool: return seen.id == bear and seen.is_tapped))


func test_the_pass_button_works_only_with_priority_and_the_undo_button_only_with_something_to_undo() -> void:
	_open(_bear_setup())
	assert_true(_screen.pass_button().disabled, "Keeping a hand is not priority.")
	assert_true(_screen.undo_button().disabled)
	assert_true(_screen.undo_button().visible, "Undo is always there, grayed out (A245).")
	assert_eq(_screen.pass_button().text, "Pass [SPACE]")
	assert_eq(_screen.undo_button().text, "Undo [Z]")
	_keep_and_reach_main()
	assert_false(_screen.pass_button().disabled)

	_do(PlayLandAction, "Forest")
	assert_false(_screen.undo_button().disabled)

	_screen.undo_button().pressed.emit()
	assert_eq(_presenter.snapshot().view.battlefield.size(), 0)

	var step: MmTurn.Step = _presenter.snapshot().view.step
	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()
	assert_ne(_presenter.snapshot().view.step, step)


func test_only_the_heros_panel_has_the_controls() -> void:
	_open(_bear_setup())

	assert_not_null(_screen.player_panel(HERO).pass_button())
	assert_not_null(_screen.player_panel(HERO).undo_button())
	assert_not_null(_screen.player_panel(HERO).auto_pass_button())
	assert_null(_screen.player_panel(VILLAIN).pass_button())
	assert_null(_screen.player_panel(VILLAIN).undo_button())
	assert_null(_screen.player_panel(VILLAIN).auto_pass_button())
	assert_true(EncounterLayout.regions(SCREEN)["hero_panel"].encloses(_screen.pass_button().get_global_rect()))


func test_the_auto_pass_box_shows_and_switches_auto_pass() -> void:
	_open(_bear_setup())
	assert_eq(_screen.auto_pass_button().text, "☐  Auto-pass")

	_screen.auto_pass_button().pressed.emit()

	assert_true(_presenter.is_auto_passing())
	assert_eq(_screen.auto_pass_button().text, "☑  Auto-pass")


func test_only_the_heros_mana_buttons_can_be_pressed_and_only_while_paying_with_that_color() -> void:
	_open(_bear_setup(Scenario.mana_cost(0, [MmMana.Type.GREEN])))
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	var hero: PlayerPanel = _screen.player_panel(HERO)
	assert_true(hero.mana_button(MmMana.Type.GREEN).disabled, "Nothing is being paid for.")
	_do(ActivateAbilityAction, "Forest")
	assert_eq(_screen.player_panel(HERO).mana_count_text(MmMana.Type.GREEN), "(1)")
	assert_eq(_screen.player_panel(HERO).mana_count_text(MmMana.Type.RED), "(0)")

	_do(CastSpellAction, "Bear")

	hero = _screen.player_panel(HERO)
	assert_true(_presenter.snapshot().decision is PayManaDecision)
	assert_false(hero.mana_button(MmMana.Type.GREEN).disabled)
	assert_eq(BorderEffects.glow_color(hero.mana_button(MmMana.Type.GREEN)), DecisionClicks.color_of(DecisionClicks.Kind.MANA))
	assert_true(hero.mana_button(MmMana.Type.RED).disabled, "There is no red mana in the pool.")
	assert_true(_screen.player_panel(VILLAIN).mana_button(MmMana.Type.GREEN).disabled, "Never the Villain's.")

	hero.mana_button(MmMana.Type.GREEN).pressed.emit()
	_presenter.wait_until_idle()

	assert_ne(_permanent("Bear"), -1, "The mana paid for the Bear.")
	assert_eq(_screen.player_panel(HERO).mana_count_text(MmMana.Type.GREEN), "(0)")


func test_step_buttons_show_and_toggle_stops_except_untap_and_cleanup() -> void:
	_open(_bear_setup())
	var hero: PlayerPanel = _screen.player_panel(HERO)
	assert_true(hero.shows_stop(MmTurn.Step.PRECOMBAT_MAIN))
	assert_false(hero.shows_stop(MmTurn.Step.UPKEEP))
	assert_true(hero.step_button(MmTurn.Step.UNTAP).disabled)
	assert_true(hero.step_button(MmTurn.Step.CLEANUP).disabled)
	assert_false(hero.step_button(MmTurn.Step.UPKEEP).disabled)
	assert_eq(hero.step_button(MmTurn.Step.BEGINNING_OF_COMBAT).text, "Begin Combat")

	hero.step_button(MmTurn.Step.UPKEEP).pressed.emit()

	assert_true(_screen.player_panel(HERO).shows_stop(MmTurn.Step.UPKEEP))
	assert_false(_screen.player_panel(VILLAIN).shows_stop(MmTurn.Step.UPKEEP), "The Villain's turn has its own row.")
	assert_true(_presenter.stops.has_stop(HERO, MmTurn.Step.UPKEEP))


func test_life_totals_show_in_each_panel() -> void:
	var setup: MmEncounterSetup = _bear_setup()
	setup.villain.starting_life = 31
	_open(setup)

	assert_eq(_screen.player_panel(VILLAIN).life_text(), "31")
	assert_eq(_screen.player_panel(HERO).life_text(), "20")


func test_the_end_of_the_encounter_is_announced_with_its_reason() -> void:
	_open(_bear_setup())
	assert_eq(_screen.banner_text(), "")

	_screen.press_key(KEY_ESCAPE)
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()

	assert_eq(_screen.banner_text(), "Defeat\nThe Hero conceded.")
	assert_false(_screen.debug_panel().visible)
	assert_true(_screen.info_panel().is_dim(), "Nothing more is asked.")
	assert_true(_screen.pass_button().disabled)


func test_it_can_redraw_while_the_villain_is_thinking() -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(Scenario.setup(Rule.VILLAIN_CHOOSES), SlowAgent.new())
	_screen.begin(_presenter)
	assert_true(_presenter.is_villain_thinking())

	_screen.size = Vector2(2560, 1080)
	_screen.player_panel(HERO).step_button(MmTurn.Step.UPKEEP).pressed.emit()

	assert_eq(_screen.player_panel(VILLAIN).thinking_text(), "The Villain is thinking…", "Said in the Villain's panel (A294).")
	assert_eq(_screen.player_panel(HERO).thinking_text(), "")
	assert_true(_screen.pass_button().disabled)
	assert_false(_screen.debug_panel().visible, "Nothing is asked of the Hero.")
	assert_true(_screen.info_panel().is_dim())
	assert_eq(_screen.info_panel().prompt_text(), "")
	_presenter.wait_until_idle()
	assert_eq(_screen.player_panel(VILLAIN).thinking_text(), "", "Only while it thinks.")
	assert_true(_presenter.stops.has_stop(HERO, MmTurn.Step.UPKEEP), "The stop was still set.")


# --- 13c-1: clicking permanents, the Info Panel, the Option Menu and the Pause Menu ---


func test_clicking_a_land_at_priority_taps_it_for_mana_and_undo_takes_it_back() -> void:
	_open(_bear_setup(Scenario.mana_cost(0, [MmMana.Type.GREEN])))
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	var forest: int = _permanent("Forest")
	assert_eq(BorderEffects.glow_color(_screen.face_of(forest)), DecisionClicks.color_of(DecisionClicks.Kind.MANA))

	_click(forest)

	assert_true(_view_of(forest).is_tapped)
	assert_eq(_screen.player_panel(HERO).mana_count_text(MmMana.Type.GREEN), "(1)")
	assert_null(_screen.click_catcher(forest), "Tapped, it answers nothing more.")
	assert_null(BorderEffects.glow_color(_screen.face_of(forest)))

	_screen.press_key(KEY_Z)

	assert_false(_view_of(forest).is_tapped)
	assert_eq(_screen.player_panel(HERO).mana_count_text(MmMana.Type.GREEN), "(0)")
	assert_not_null(_screen.click_catcher(forest))


func test_only_what_a_click_answers_takes_the_mouse() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	var forest: Control = _screen.face_of(_permanent("Forest"))
	var bear: Control = _screen.face_of(_permanent("Bear"))
	var card: Control = _screen.face_of(_presenter.snapshot().view.hand[0].id)

	assert_not_null(ClickCatcher.of(forest))
	assert_null(ClickCatcher.of(bear), "A creature with nothing to activate.")
	assert_eq(bear.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_null(ClickCatcher.of(card), "Cards in hand wait for 13e.")
	assert_null(_screen.player_panel(VILLAIN).click_catcher(), "Nobody is being targeted.")
	assert_null(_screen.click_catcher(99999), "Something that is not on the screen.")


func test_a_clickable_face_brightens_under_the_cursor_and_shows_the_pointing_hand() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	var forest: Control = _screen.face_of(_permanent("Forest"))
	var catcher: ClickCatcher = ClickCatcher.of(forest)

	assert_eq(catcher.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
	assert_eq(catcher.get_parent(), forest, "A child of the face, so it turns with it.")
	catcher.mouse_entered.emit()
	assert_eq(forest.modulate, ClickCatcher.BRIGHT)
	catcher.mouse_exited.emit()
	assert_eq(forest.modulate, Color.WHITE)


func test_clicking_a_permanent_activates_it_and_clicking_a_player_targets_them() -> void:
	_open(_setup_of([_wand()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Wand")
	_presenter.wait_until_idle()
	var wand: int = _permanent("Wand")
	assert_eq(BorderEffects.glow_color(_screen.face_of(wand)), DecisionClicks.color_of(DecisionClicks.Kind.OTHER))

	_click(wand)

	assert_true(_presenter.snapshot().decision is ChooseTargetDecision, "One click, no confirmation (A285).")
	assert_eq(_screen.info_panel().prompt_text(), "Choose a target for Wand's ability")
	assert_false(_screen.debug_panel().visible, "Targets have no form any more (A290).")
	assert_false(_screen.option_menu().is_open(), "One ability needs no menu.")
	assert_not_null(_screen.player_panel(HERO).click_catcher(), "The Hero can be targeted too.")

	_screen.player_panel(VILLAIN).click_catcher().clicked.emit()
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().view.life_totals[VILLAIN], 19, "It was passed for the Hero and resolved.")
	assert_true(_presenter.snapshot().view.stack.is_empty())
	assert_null(_screen.player_panel(VILLAIN).click_catcher())


func test_holding_the_key_while_clicking_keeps_priority_and_the_info_panel_says_so() -> void:
	_open(_setup_of([_wand()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Wand")
	_presenter.wait_until_idle()
	assert_false(_screen.info_panel().shows_holding())

	_screen.set_hold_key_down(true)
	assert_true(_screen.info_panel().shows_holding(), "As soon as the key is down, before anything is held (A304).")
	_click(_permanent("Wand"))
	_screen.player_panel(VILLAIN).click_catcher().clicked.emit()
	_presenter.wait_until_idle()
	_screen.set_hold_key_down(false)

	assert_eq(_presenter.snapshot().view.stack.size(), 1, "The ability waits on the stack.")
	assert_true(_presenter.snapshot().is_holding_priority)
	assert_true(_screen.info_panel().shows_holding(), "It stays while the hold is in force.")
	assert_eq(_presenter.snapshot().view.life_totals[VILLAIN], 20)


func test_a_clicked_target_on_the_battlefield_is_chosen() -> void:
	_open(_setup_of([_free_bear(), _wand()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	_do(CastSpellAction, "Wand")
	_presenter.wait_until_idle()
	var bear: int = _permanent("Bear")
	_click(_permanent("Wand"))
	assert_eq(BorderEffects.glow_color(_screen.face_of(bear)), DecisionClicks.color_of(DecisionClicks.Kind.TARGET))

	_click(bear)
	_presenter.wait_until_idle()

	assert_eq(_view_of(bear).damage_marked, 1)


func test_mana_is_paid_by_clicking_sources_and_the_info_panel_says_what_is_owed() -> void:
	_open(_bear_setup(Scenario.mana_cost(1, [MmMana.Type.GREEN])))
	_keep()
	_reach_main_with_forests(2)
	var forests: Array[int] = _permanents("Forest")

	_do(CastSpellAction, "Bear")

	assert_true(_presenter.snapshot().decision is PayManaDecision)
	assert_eq(_screen.info_panel().prompt_text(), "Pay for Bear")
	assert_eq(_screen.info_panel().owed_pip_names(), ["1", "g"] as Array[String])
	assert_false(_screen.debug_panel().visible, "Paying has no form any more (A290).")
	assert_eq(BorderEffects.glow_color(_screen.face_of(forests[0])), DecisionClicks.color_of(DecisionClicks.Kind.MANA))

	_click(forests[0])

	assert_true(_view_of(forests[0]).is_tapped)
	assert_eq(_screen.info_panel().owed_pip_names().size(), 1, "One more to pay.")

	_click(forests[1])
	_presenter.wait_until_idle()

	assert_ne(_permanent("Bear"), -1, "Paid for, passed for the Hero, and resolved.")
	assert_eq(_screen.info_panel().owed_pip_names().size(), 0)


func test_cancel_during_payment_untaps_every_land_tapped_for_it() -> void:
	_open(_bear_setup(Scenario.mana_cost(1, [MmMana.Type.GREEN])))
	_keep()
	_reach_main_with_forests(2)
	var forests: Array[int] = _permanents("Forest")
	var hand: int = _presenter.snapshot().view.hand.size()
	_do(CastSpellAction, "Bear")
	_click(forests[0])
	assert_true(_view_of(forests[0]).is_tapped)

	_screen.info_panel().cancel_button().pressed.emit()

	assert_true(_presenter.snapshot().decision is PriorityDecision)
	assert_false(_view_of(forests[0]).is_tapped)
	assert_false(_view_of(forests[1]).is_tapped)
	assert_eq(_presenter.snapshot().view.hand.size(), hand, "The Bear is back in hand.")
	assert_eq(_permanent("Bear"), -1)


func test_a_permanent_with_two_abilities_opens_the_option_menu_where_it_was_clicked() -> void:
	_open(_setup_of([_staff()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Staff")
	_presenter.wait_until_idle()
	var staff: int = _permanent("Staff")
	assert_eq(BorderEffects.glow_color(_screen.face_of(staff)), DecisionClicks.color_of(DecisionClicks.Kind.OTHER),
		"Mana and another ability glow green (A306).")

	_click(staff)

	var menu: OptionMenu = _screen.option_menu()
	assert_true(menu.is_open())
	assert_true(_presenter.snapshot().decision is PriorityDecision, "Nothing is answered until a row is picked.")
	assert_eq(menu.rows().size(), 2)
	assert_eq(menu.rows()[0].text, "{T}: Add Mana")
	assert_eq(menu.rows()[1].text, "{T}: Deal Damage")
	assert_true(EncounterLayout.regions(SCREEN)["battlefield"].encloses(menu.box_rect()))

	menu.rows()[1].pressed.emit()

	assert_false(menu.is_open())
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision, "The second row's ability was activated.")


func test_clicking_outside_the_option_menu_closes_it_without_answering() -> void:
	_open(_setup_of([_staff()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Staff")
	_presenter.wait_until_idle()
	var before: EncounterSnapshot = _presenter.snapshot()
	_click(_permanent("Staff"))
	var outside: InputEventMouseButton = InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true

	_screen.option_menu()._gui_input(outside)

	assert_false(_screen.option_menu().is_open())
	assert_eq(_presenter.snapshot(), before)
	assert_false(_view_of(_permanent("Staff")).is_tapped)


func test_the_option_menu_shows_three_rows_of_four_and_a_new_snapshot_closes_it() -> void:
	_open(_setup_of([_scepter()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Scepter")
	_presenter.wait_until_idle()

	_click(_permanent("Scepter"))

	var menu: OptionMenu = _screen.option_menu()
	var three: Rect2 = EncounterLayout.menu_rect(Vector2.ZERO, 3, Rect2(0, 0, 4000, 4000))
	assert_eq(menu.rows().size(), 4)
	assert_eq(menu.box_rect().size, three.size, "Three rows show, and the fourth is scrolled to (A286).")

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_false(menu.is_open(), "The board it was opened on has changed.")


func test_pointing_at_an_option_menu_row_shows_it_in_the_info_panel_in_place_of_the_prompt() -> void:
	_open(_setup_of([_staff()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Staff")
	_presenter.wait_until_idle()
	_click(_permanent("Staff"))
	var info: InfoPanel = _screen.info_panel()
	var prompt: String = info.prompt_text()

	_screen.option_menu().rows()[1].mouse_entered.emit()

	assert_eq(info.option_text(), "{T}: Deal Damage")
	assert_false(info.shows_prompt())

	_screen.option_menu().rows()[1].mouse_exited.emit()

	assert_eq(info.option_text(), "")
	assert_true(info.shows_prompt())
	assert_eq(info.prompt_text(), prompt)

	_screen.option_menu().rows()[0].mouse_entered.emit()
	_screen.option_menu().close()
	assert_true(info.shows_prompt(), "Closing the menu puts the prompt back too.")


func test_the_info_panel_prompts_for_what_is_asked_in_its_own_bordered_region() -> void:
	_open(_bear_setup())
	var info: InfoPanel = _screen.info_panel()
	assert_eq(info.prompt_text(), "Keep this hand, or mulligan? (0 taken)", "A kind the panel still answers is prompted for too.")
	assert_false(info.is_dim())
	assert_true(info.has_border())
	assert_eq(info.get_global_rect(), EncounterLayout.regions(SCREEN)["info"])

	_keep_and_reach_main()

	assert_eq(info.prompt_text(), "Your priority\nMain 1, your turn")
	assert_false(info.shows_holding())
	assert_eq(info.error_text(), "")


func test_the_hand_stays_centered_on_the_battlefield_clear_of_the_info_panel() -> void:
	_open(_bear_setup())
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)
	var view: MmPlayerView = _presenter.snapshot().view
	var left: float = _screen.face_of(view.hand[0].id).position.x
	var last: Control = _screen.face_of(view.hand[view.hand.size() - 1].id)

	assert_almost_eq((left + last.position.x + last.size.x) / 2.0, regions["hero_lands"].get_center().x, 1.0)
	assert_gt(left, regions["info"].end.x)


func test_a_glowing_permanent_scrolled_out_of_sight_colors_its_lines_arrow() -> void:
	_open(_setup_of([_free_bear()]))
	_keep_and_reach_main()
	for cast: int in 7:
		_do(CastSpellAction, "Bear")
		_presenter.wait_until_idle()
	assert_null(_screen.line("hero_creatures").arrow_tint(_screen.line("hero_creatures").right_arrow()), "Nothing glows yet.")
	_pass_until(func() -> bool: return _presenter.snapshot().decision is DeclareAttackersDecision)
	var green: Color = DecisionClicks.color_of(DecisionClicks.Kind.OTHER)
	# Narrow enough that whole Bears are out of sight, not just the edge of one.
	_screen.size = Vector2(1500, 1080)
	var line: ScrollRow = _screen.line("hero_creatures")
	line.scroll_to(0.0)

	assert_eq(line.arrow_tint(line.right_arrow()), green, "A Bear that may attack is off the right end.")
	assert_null(line.arrow_tint(line.left_arrow()))

	line.scroll_by(9000.0)

	assert_null(line.arrow_tint(line.right_arrow()), "Scrolled into view, the arrow is plain again.")
	assert_eq(line.arrow_tint(line.left_arrow()), green, "Now one is off the left end.")


func test_lands_of_the_same_name_stand_together() -> void:
	_open(_setup_of([Scenario.basic_land("Mountain"), Scenario.basic_land("Island")]))
	_keep_and_reach_main()
	_do(PlayLandAction, "Mountain")
	_pass_until(_can_play_a_land)
	_do(PlayLandAction, "Island")
	_pass_until(_can_play_a_land)
	_do(PlayLandAction, "Mountain")

	var mountains: Array[int] = _permanents("Mountain")
	var island: float = _screen.face_of(_permanent("Island")).position.x
	var first: float = _screen.face_of(mountains[0]).position.x
	var second: float = _screen.face_of(mountains[1]).position.x

	assert_lt(first, second)
	assert_lt(second, island, "The second Mountain went just right of the first, so the Island is last.")


func test_the_piles_stand_in_their_evenly_spaced_regions() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	_screen.press_key(KEY_ESCAPE)
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)

	assert_eq(_screen.pile_text("villain_library"), "Library (33)")
	assert_false(regions.has("status"))
	assert_almost_eq(regions["hero_library"].position.y - regions["villain_exile"].end.y,
		regions["villain_graveyard"].position.y - regions["villain_library"].end.y, 0.01)


func test_the_debug_panel_lists_only_what_has_no_input_yet_and_has_no_concede() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	var panel: DebugDecisionPanel = _screen.debug_panel()

	assert_true(panel.visible)
	for option: Button in panel.option_buttons():
		assert_string_starts_with(option.text, "Cast ", "The land for the turn is played, and tapping the Forest is a click.")
	assert_false(panel.has_method("concede_button"))
	assert_false(panel.has_method("cancel_button"))
	assert_false(panel.has_signal("concede_requested"))


func test_the_debug_panel_hides_at_priority_with_nothing_to_cast_or_play() -> void:
	_open(_setup_of([Scenario.basic_land("Forest")]))
	_keep_and_reach_main()
	assert_true(_screen.debug_panel().visible, "A land can be played.")

	_do(PlayLandAction, "Forest")

	assert_true(_presenter.snapshot().decision is PriorityDecision)
	assert_false(_screen.debug_panel().visible, "Only tapping for mana and passing are left.")


func test_escape_opens_the_pause_menu_and_escape_again_carries_on_from_the_same_place() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	var before: EncounterSnapshot = _presenter.snapshot()
	assert_false(_screen.pause_menu().is_open())

	_screen.press_key(KEY_ESCAPE)

	assert_true(_screen.is_paused())
	assert_true(_screen.pause_menu().is_open())
	assert_true(_presenter.is_paused())
	assert_eq(_screen.pause_menu().heading_text(), "Paused")
	assert_true(EncounterLayout.regions(SCREEN)["battlefield"].encloses(_screen.pause_menu().window_rect()))
	assert_eq(_screen.pause_menu().get_index(), _screen.get_child_count() - 1, "It is over everything else.")
	assert_eq(_screen.pause_menu().mouse_filter, Control.MOUSE_FILTER_STOP, "And takes every click.")

	_screen.press_key(KEY_ESCAPE)

	assert_false(_screen.is_paused())
	assert_false(_screen.pause_menu().is_open())
	assert_false(_presenter.is_paused())
	assert_eq(_presenter.snapshot(), before)


func test_while_paused_the_board_and_the_keys_do_nothing() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	var forest: int = _permanent("Forest")
	var before: EncounterSnapshot = _presenter.snapshot()
	_screen.press_key(KEY_ESCAPE)

	_screen.press_key(KEY_SPACE)
	_screen.press_key(KEY_Z)
	_click(forest)

	assert_eq(_presenter.snapshot(), before)
	assert_eq(_screen.info_panel().error_text(), "", "The keys and the board are silent; nothing was even asked for.")

	_screen.pass_button().pressed.emit()

	assert_eq(_presenter.snapshot(), before)
	assert_false(_view_of(forest).is_tapped)
	assert_eq(_screen.info_panel().error_text(), EncounterPresenter.PAUSED, "The pass button, if reached, is refused.")

	_screen.pause_menu().button(PauseMenu.RESUME).pressed.emit()
	_screen.press_key(KEY_Z)

	assert_false(_screen.is_paused())
	assert_eq(_permanent("Forest"), -1, "Resumed, undo works again.")


func test_while_paused_a_click_does_not_open_the_option_menu() -> void:
	_open(_setup_of([_staff()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Staff")
	_presenter.wait_until_idle()
	var staff: int = _permanent("Staff")
	_click(staff)
	assert_true(_screen.option_menu().is_open())

	_screen.press_key(KEY_ESCAPE)
	assert_false(_screen.option_menu().is_open(), "Pausing closes it.")
	_click(staff)

	assert_false(_screen.option_menu().is_open())


func test_parting_the_hand_on_the_screen_keeps_every_card_inside_its_bounds() -> void:
	_open(_bear_setup())
	var hand: Rect2 = EncounterLayout.regions(SCREEN)["hero_hand"]
	var view: MmPlayerView = _presenter.snapshot().view
	var card: Vector2 = _screen.face_of(view.hand[0].id).size
	var rest: Array[Vector2] = EncounterLayout.hand_rest(7, hand, card)
	var cursor: Vector2 = rest[5] + Vector2(10.0, 40.0)
	assert_gt(EncounterLayout.hand_spread(rest, card, cursor)[6].x + card.x, hand.end.x, "Unbounded, the last card would leave.")

	var places: Array[Vector2] = _screen.hand_places(cursor)

	assert_eq(places.size(), 7)
	assert_lt(places[6].x + card.x, hand.end.x + 0.01)
	assert_gt(places[0].x, hand.position.x - 0.01)


func test_pausing_while_the_villain_thinks_holds_the_board_until_resume() -> void:
	var agent: SlowAgent = SlowAgent.new()
	agent.delay_msec = 50
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(Scenario.setup(Rule.VILLAIN_CHOOSES), agent)
	_screen.begin(_presenter)
	var during: EncounterSnapshot = _presenter.snapshot()

	_screen.press_key(KEY_ESCAPE)
	OS.delay_msec(200)
	_screen._process(0.016)

	assert_eq(_presenter.snapshot(), during, "The thought finished, and the board did not change.")
	assert_eq(_screen.player_panel(VILLAIN).thinking_text(), "The Villain is thinking…")

	_screen.press_key(KEY_ESCAPE)
	_screen._process(0.016)

	assert_ne(_presenter.snapshot(), during)
	_presenter.wait_until_idle()


func test_concede_asks_once_more_and_back_returns_to_the_menu() -> void:
	_open(_bear_setup())
	_screen.press_key(KEY_ESCAPE)
	var menu: PauseMenu = _screen.pause_menu()

	menu.button(PauseMenu.CONCEDE).pressed.emit()

	assert_eq(menu.page(), PauseMenu.Page.CONCEDE)
	assert_eq(menu.heading_text(), "Concede this encounter?")
	assert_false(_presenter.snapshot().is_over(), "Not yet.")

	menu.button(PauseMenu.BACK).pressed.emit()

	assert_eq(menu.page(), PauseMenu.Page.MENU)
	assert_false(_presenter.snapshot().is_over())

	menu.button(PauseMenu.CONCEDE).pressed.emit()
	menu.button(PauseMenu.CONCEDE).pressed.emit()

	assert_true(_presenter.snapshot().is_over())
	assert_eq(_screen.banner_text(), "Defeat\nThe Hero conceded.")
	assert_false(_screen.is_paused(), "The menu closes to show how it ended.")
	assert_false(menu.is_open())


func test_quit_asks_once_more_then_leaves_for_the_main_menu() -> void:
	_open(_bear_setup())
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	_screen.press_key(KEY_ESCAPE)
	var menu: PauseMenu = _screen.pause_menu()

	menu.button(PauseMenu.QUIT).pressed.emit()

	assert_eq(menu.page(), PauseMenu.Page.QUIT)
	assert_eq(_went_to.size(), 0, "Not yet.")

	menu.button(PauseMenu.QUIT_NOW).pressed.emit()

	assert_eq(_went_to, [EncounterScreen.MENU] as Array[String])
	assert_false(_presenter.is_villain_thinking())


func test_settings_is_shown_grayed_out_and_concede_too_once_the_encounter_is_over() -> void:
	_open(_bear_setup())
	_screen.press_key(KEY_ESCAPE)
	assert_true(_screen.pause_menu().button(PauseMenu.SETTINGS).disabled)
	assert_false(_screen.pause_menu().button(PauseMenu.CONCEDE).disabled)
	assert_false(_screen.pause_menu().button(PauseMenu.QUIT).disabled)
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()

	_screen.press_key(KEY_ESCAPE)

	assert_true(_screen.pause_menu().button(PauseMenu.CONCEDE).disabled, "There is nothing left to concede.")


func test_leaving_waits_for_the_villain_and_goes_where_asked() -> void:
	_open(_bear_setup())
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)

	_screen.leave(EncounterScreen.MENU)

	assert_eq(_went_to, [EncounterScreen.MENU] as Array[String])
	assert_false(_presenter.is_villain_thinking())


## Opens a screen on [param setup] with auto-pass off, waiting for the Hero.
func _open(setup: MmEncounterSetup) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()


## The Hero's deck alternates Forests and 2/2 Bears costing [param cost] (free unless given).
func _bear_setup(cost: MmManaCost = null) -> MmEncounterSetup:
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2, [], cost if cost != null else Scenario.mana_cost(0))
	var cards: Array[MmCardDefinition] = []
	for index: int in 20:
		cards.append_array([Scenario.basic_land("Forest"), bear])
	return Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40))


## An artifact costing {0}: "{T}: This deals 1 damage to any target."
func _wand() -> MmCardDefinition:
	return Scenario.artifact("Wand", [_ping(true)])


## An artifact costing {0} with a mana ability and the Wand's ability.
func _staff() -> MmCardDefinition:
	return Scenario.artifact("Staff", [Scenario.tap_for_mana(MmMana.Type.RED, 1), _ping(true)])


## An artifact costing {0} with four abilities.
func _scepter() -> MmCardDefinition:
	return Scenario.artifact("Scepter", [Scenario.tap_for_mana(MmMana.Type.RED, 1), _ping(true), _ping(false), _ping(false)])


func _ping(taps: bool) -> ActivatedAbility:
	var ability: ActivatedAbility = ActivatedAbility.new()
	if taps:
		ability.costs = [TapCost.new()]
	else:
		ability.mana_cost = Scenario.mana_cost(0)
	ability.targets = [Scenario.any_target()]
	ability.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
	return ability


## Clicks Game Object [param object_id], if anything takes a click on it.
func _click(object_id: int) -> void:
	var catcher: ClickCatcher = _screen.click_catcher(object_id)
	if catcher != null:
		catcher.clicked.emit()


func _view_of(object_id: int) -> MmObjectView:
	for seen: MmObjectView in _presenter.snapshot().visible_objects():
		if seen.id == object_id:
			return seen
	return null


func _permanents(card_name: String) -> Array[int]:
	var found: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			found.append(permanent.id)
	return found


func _can_play_a_land() -> bool:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	return priority != null and priority.actions.any(func(action: MmAction) -> bool: return action is PlayLandAction)


## Passes, declaring no attackers or blockers, until [param is_there] says to stop.
func _pass_until(is_there: Callable) -> void:
	for attempt: int in 200:
		if is_there.call():
			return
		var decision: MmPendingDecision = _presenter.snapshot().decision
		if decision is PriorityDecision:
			_presenter.pass_priority()
		elif decision is ChooseCardsToDiscardDecision:
			var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
			_presenter.answer(discard.candidate_ids.slice(0, discard.count))
		else:
			_presenter.answer([])
		_presenter.wait_until_idle()
	fail_test("Never got there.")


## Plays a Forest a turn until the Hero has [param count], in their main phase.
func _reach_main_with_forests(count: int) -> void:
	for turn: int in count:
		_pass_until(_can_play_a_land)
		_do(PlayLandAction, "Forest")


## The Hero's deck alternates two free instants, "Zap" and "Jolt": 2 damage to any target.
func _shock_setup() -> MmEncounterSetup:
	var cards: Array[MmCardDefinition] = []
	for index: int in 20:
		cards.append_array([Scenario.free_shock("Zap", 2), Scenario.free_shock("Jolt", 2)])
	return Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40))


func _free_bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))


## The Hero's deck is forty cards cycling through [param cards].
func _setup_of(cards: Array[MmCardDefinition]) -> MmEncounterSetup:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	return Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40))


func _last_permanent(card_name: String) -> int:
	var found: int = -1
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			found = permanent.id
	return found


func _keep() -> void:
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()


func _keep_and_reach_main() -> void:
	_keep()
	for attempt: int in 10:
		if _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


## Takes the priority action of [param kind] about the card named [param card_name].
func _do(kind: Script, card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if is_instance_of(action, kind) and DebugDecisionForm.name_of(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			return
	fail_test("No %s action for %s." % [kind.resource_path.get_file(), card_name])


func _play_a_land_or_pass() -> void:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	if priority == null:
		return
	for index: int in priority.actions.size():
		if priority.actions[index] is PlayLandAction:
			_presenter.answer(index)
			return
	_presenter.pass_priority()
	_presenter.wait_until_idle()


func _cast_at_the_villain(card_name: String) -> void:
	_do(CastSpellAction, card_name)
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	for index: int in target.candidates.size():
		if target.candidates[index].is_player() and target.candidates[index].id == VILLAIN:
			assert_eq(_presenter.answer(index), "")
			return


func _in_hand(card_name: String) -> int:
	for card: MmObjectView in _presenter.snapshot().view.hand:
		if card.name == card_name:
			return card.id
	return -1


func _permanent(card_name: String) -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			return permanent.id
	return -1
