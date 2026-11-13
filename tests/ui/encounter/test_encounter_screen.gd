extends GutTest
## The Encounter Screen draws each snapshot into its Regions and windows, and passes what
## the human does to the Encounter Presenter.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SlowAgent := preload("res://tests/ui/encounter/support/slow_agent.gd")
const CombatAgent := preload("res://tests/ui/encounter/support/combat_agent.gd")
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
	_keep()

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

	var entries: Array[StackEntry] = _screen.stack_entries()
	assert_eq(_screen.stack_window().title_text(), "Stack (2)")
	assert_eq(entries[0].name_text(), "Jolt", "Cast last, so it is on top and resolves first.")
	assert_eq(entries[1].name_text(), "Zap")
	assert_eq(entries[0].detail_text(), "Hero → Villain")


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
	assert_eq(window.title_text(), "Hero's Emblems (3)")
	assert_eq(window.body().get_child_count(), 3, "Howling Winds and both Boons (A527).")
	assert_eq((window.body().get_child(0) as ZoneEntry).name_text(), "Sample Boon: Howling Winds")
	assert_false(_screen.emblems_window(VILLAIN).visible)
	assert_eq((_screen.emblems_window(VILLAIN).body().get_child(0) as ZoneEntry).name_text(), "Sample Hex: Ankh's Curse")

	window.close_button().pressed.emit()
	assert_false(window.visible)


func test_the_emblems_button_cannot_be_pressed_with_no_emblems() -> void:
	_open(_bear_setup())

	assert_true(_screen.player_panel(HERO).emblems_button().disabled)
	assert_eq(_screen.player_panel(HERO).emblems_button().text, "⛨  Emblems (0)")
	assert_eq(_screen.emblems_window(HERO).title_text(), "Hero's Emblems (0)")


func test_what_a_decision_can_choose_glows_on_the_thing_itself() -> void:
	_open(_shock_setup())
	_keep()
	var zap: int = _in_hand("Zap")

	assert_eq(BorderEffects.glow_color(_screen.face_of(zap)), DecisionClicks.color_of(DecisionClicks.Kind.PLAY))
	assert_eq(_screen.face_of(zap).get_node(BorderEffects.GLOW).get_parent(), _screen.face_of(zap),
		"The Glow is a child of the card, so it turns with it.")

	_do(CastSpellAction, "Zap")

	assert_eq(BorderEffects.glow_color(_screen.player_panel(VILLAIN).portrait()), DecisionClicks.color_of(DecisionClicks.Kind.TARGET))
	assert_eq(BorderEffects.glow_color(_screen.player_panel(HERO).portrait()), DecisionClicks.color_of(DecisionClicks.Kind.TARGET))
	assert_null(BorderEffects.glow_color(_screen.player_panel(VILLAIN)), "Only the portrait glows, never the whole panel.")
	assert_null(BorderEffects.glow_color(_screen.face_of(_in_hand("Jolt"))), "A card in hand is not a target.")


func test_the_overlays_buttons_answer_the_pregame() -> void:
	_open(_bear_setup())
	assert_eq(_screen.opening_overlay().button_texts(), ["Keep 7", "Mulligan"] as Array[String])

	_screen.opening_overlay().button("Keep 7").pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is PriorityDecision)
	assert_false(_screen.opening_overlay().visible, "At priority the hand and the board answer (13e-1).")
	assert_eq(_screen.info_panel().error_text(), "")


func test_a_rejected_answer_shows_its_reason_in_the_info_panel_until_one_is_accepted() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	var prompt: String = _screen.info_panel().prompt_text()

	_screen._answer(99)

	assert_ne(_screen.info_panel().error_text(), "")
	assert_true(_presenter.snapshot().decision is PriorityDecision, "The same decision is still asked.")
	assert_eq(_screen.info_panel().prompt_text(), prompt, "And still prompted for.")

	_do(PlayLandAction, "Forest")
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


func test_the_pass_button_works_only_with_priority_and_the_undo_button_only_with_something_to_undo() -> void:
	_open(_bear_setup())
	assert_true(_screen.pass_button().disabled, "Keeping a hand is not priority.")
	assert_true(_screen.undo_button().disabled)
	assert_true(_screen.undo_button().visible, "Undo is always there, grayed out (A245).")
	assert_eq(_screen.pass_button().text, "Pass Priority [SPACE]")
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

	assert_not_null(_screen.player_panel(HERO).undo_button())
	assert_not_null(_screen.player_panel(HERO).yield_button())
	assert_null(_screen.player_panel(VILLAIN).undo_button())
	assert_null(_screen.player_panel(VILLAIN).yield_button())
	assert_eq(_screen.pass_button().get_global_rect(), EncounterLayout.regions(SCREEN)["pass"], "The Pass Button is over the Info Panel (A489).")


func test_the_yield_box_shows_and_switches_the_yield() -> void:
	_open(_bear_setup())
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	assert_eq(_screen.yield_button().text, "☐  Yield Turn")
	var turn: int = _presenter.snapshot().view.game_turn

	_screen.yield_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_gt(_presenter.snapshot().view.game_turn, turn, "The rest of the turn was passed.")
	assert_false(_presenter.is_yielding(), "It ended with the turn.")
	assert_eq(_screen.yield_button().text, "☐  Yield Turn")


func test_the_yield_box_is_checked_while_the_yield_lasts() -> void:
	_open(_bear_setup())
	_presenter.is_hold_key_down = true

	_screen.yield_button().pressed.emit()

	assert_true(_presenter.is_yielding())
	assert_eq(_screen.yield_button().text, "☑  Yield Turn")
	_screen.yield_button().pressed.emit()
	assert_false(_presenter.is_yielding())
	assert_eq(_screen.yield_button().text, "☐  Yield Turn")


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
	assert_null(ClickCatcher.of(card), "One click on a card in hand does nothing (A371).")
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
	assert_eq(BorderEffects.glow_color(_screen.face_of(wand)), DecisionClicks.color_of(DecisionClicks.Kind.ABILITY))

	_click(wand)

	assert_true(_presenter.snapshot().decision is ChooseTargetDecision, "One click, no confirmation (A285).")
	assert_eq(_screen.info_panel().prompt_text(), "Choose a target for Wand's ability")
	assert_false(_screen.option_menu().is_open(), "One ability needs no menu.")
	assert_not_null(_screen.player_panel(HERO).click_catcher(), "The Hero can be targeted too.")
	var villain: PlayerPanel = _screen.player_panel(VILLAIN)
	assert_eq(villain.click_catcher().get_parent(), villain.portrait(), "Only the portrait takes the click.")
	assert_eq(villain.click_catcher().get_global_rect(), villain.portrait().get_global_rect())
	assert_null(ClickCatcher.of(villain), "The rest of the panel does not.")
	villain.click_catcher().mouse_entered.emit()
	assert_eq(villain.portrait().modulate, ClickCatcher.BRIGHT, "The portrait brightens under the cursor,")
	assert_eq(villain.modulate, Color.WHITE, "and the panel around it does not.")

	_screen.player_panel(VILLAIN).click_catcher().clicked.emit()
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().view.life_totals[VILLAIN], 19, "It was passed for the Hero and resolved.")
	assert_true(_presenter.snapshot().view.stack.is_empty())
	assert_null(_screen.player_panel(VILLAIN).click_catcher())


func test_holding_the_key_while_clicking_keeps_priority_and_the_hold_panel_shows_while_it_is_down() -> void:
	_open(_setup_of([_wand()]))
	_keep_and_reach_main()
	_do(CastSpellAction, "Wand")
	_presenter.wait_until_idle()
	assert_false(_screen.hold_panel().visible)

	_screen.set_hold_key_down(true)
	assert_true(_screen.hold_panel().visible, "As soon as the key is down, before anything is held (A304).")
	assert_eq(_screen.hold_panel().get_global_rect(), EncounterLayout.regions(SCREEN)["hold"])
	_click(_permanent("Wand"))
	_screen.player_panel(VILLAIN).click_catcher().clicked.emit()
	_presenter.wait_until_idle()
	_screen.set_hold_key_down(false)

	assert_eq(_presenter.snapshot().view.stack.size(), 1, "The ability waits on the stack.")
	assert_true(_presenter.snapshot().is_holding_priority)
	assert_false(_screen.hold_panel().visible, "Only while the key is down, hold in force or not.")
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
	assert_eq(BorderEffects.glow_colors(_screen.face_of(staff)),
		[DecisionClicks.color_of(DecisionClicks.Kind.ABILITY), DecisionClicks.color_of(DecisionClicks.Kind.MANA)] as Array[Color],
		"Mana and another ability glow purple and blue.")

	_click(staff)

	var menu: OptionMenu = _screen.option_menu()
	assert_true(menu.is_open())
	assert_true(_presenter.snapshot().decision is PriorityDecision, "Nothing is answered until a row is picked.")
	assert_eq(menu.rows().size(), 2)
	assert_eq(menu.rows()[0].text, "{T}: Add {R}.")
	assert_eq(menu.rows()[1].text, "{T}: This artifact deals 1 damage to any target.")
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

	assert_eq(info.option_text(), "{T}: This artifact deals 1 damage to any target.")
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
	_keep_and_reach_main()
	var info: InfoPanel = _screen.info_panel()
	assert_eq(info.prompt_text(), "Your priority\nMain 1, your turn")
	assert_false(info.is_dim())
	assert_true(info.has_border())
	assert_eq(info.get_global_rect(), EncounterLayout.regions(SCREEN)["info"])
	assert_eq(info.error_text(), "")


func test_the_hand_stays_centered_on_the_battlefield_clear_of_the_info_panel() -> void:
	_open(_bear_setup())
	_keep()
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
	var gold: Color = DecisionClicks.color_of(DecisionClicks.Kind.COMBAT)
	# Narrow enough that whole Bears are out of sight, not just the edge of one.
	_screen.size = Vector2(1500, 1080)
	var line: ScrollRow = _screen.line("hero_creatures")
	line.scroll_to(0.0)

	assert_eq(line.arrow_tint(line.right_arrow()), gold, "A Bear that may attack is off the right end.")
	assert_null(line.arrow_tint(line.left_arrow()))

	line.scroll_by(9000.0)

	assert_null(line.arrow_tint(line.right_arrow()), "Scrolled into view, the arrow is plain again.")
	assert_eq(line.arrow_tint(line.left_arrow()), gold, "Now one is off the left end.")


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
	assert_almost_eq(regions["hero_library"].position.y - regions["villain_library"].end.y,
		regions["villain_graveyard"].position.y - regions["villain_exile"].end.y, 0.01)


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
	_keep()
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


func test_the_banner_is_drawn_over_the_block_lines_and_under_the_windows() -> void:
	_open(_bear_setup())
	_keep()

	_presenter.concede()

	var banner: Control = _screen.banner()
	assert_not_null(banner)
	assert_eq(banner.get_parent(), _screen)
	assert_gt(banner.get_index(), _screen.block_lines().get_index(), "A block line never crosses it.")
	assert_lt(banner.get_index(), _screen.stack_window().get_index(), "A window can still be put over it.")
	assert_lt(banner.get_index(), _screen.pause_menu().get_index())


func test_a_redraw_after_the_end_leaves_one_banner() -> void:
	_open(_bear_setup())
	_keep()
	_presenter.concede()
	var first: Control = _screen.banner()

	_screen.size = SCREEN + Vector2(10, 0)
	_screen.size = SCREEN

	assert_true(first.is_queued_for_deletion())
	assert_false(_screen.banner().is_queued_for_deletion())
	var banners: int = 0
	for child: Node in _screen.get_children():
		if child.has_meta("text") and not child.is_queued_for_deletion():
			banners += 1
	assert_eq(banners, 1)


func test_concede_is_shown_grayed_out_once_the_encounter_is_over() -> void:
	_open(_bear_setup())
	_screen.press_key(KEY_ESCAPE)
	assert_false(_screen.pause_menu().button(PauseMenu.SETTINGS).disabled)
	assert_false(_screen.pause_menu().button(PauseMenu.CONCEDE).disabled)
	assert_false(_screen.pause_menu().button(PauseMenu.QUIT).disabled)
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()

	_screen.press_key(KEY_ESCAPE)

	assert_true(_screen.pause_menu().button(PauseMenu.CONCEDE).disabled, "There is nothing left to concede.")


# --- 13c-2: combat ---


func test_clicking_a_creature_that_may_attack_steps_it_into_the_lane_and_again_steps_it_back() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(3)
	var bears: Array[int] = _permanents("Bear")
	var rest_y: float = _screen.face_of(bears[1]).get_global_rect().get_center().y
	var rest_x: float = _screen.face_of(bears[1]).get_global_rect().position.x
	assert_eq(BorderEffects.glow_color(_screen.face_of(bears[1])), DecisionClicks.color_of(DecisionClicks.Kind.COMBAT))
	assert_eq(_screen.info_panel().prompt_text(), "Declare attackers")
	assert_eq(_screen.pass_button().text, "No attacks [SPACE]")
	assert_false(_screen.pass_button().disabled)

	_click(bears[1])

	var chosen: Control = _screen.face_of(bears[1])
	assert_true(_presenter.snapshot().decision is DeclareAttackersDecision, "Nothing is answered yet.")
	assert_almost_eq(rest_y - chosen.get_global_rect().get_center().y, EncounterLayout.COMBAT_STEP, 0.5, "It stepped into the lane,")
	assert_almost_eq(chosen.get_global_rect().position.x, rest_x, 0.5, "where it stood: nothing changes places while choosing.")
	assert_false(_view_of(bears[1]).is_tapped, "And upright: only the engine taps it (A312).")
	assert_eq(chosen.size, _screen.face_of(bears[0]).size, "Nobody shrinks until the attack is declared.")
	assert_eq(_screen.pass_button().text, "Attack with 1 [SPACE]")

	_click(bears[1])

	assert_almost_eq(_screen.face_of(bears[1]).get_global_rect().get_center().y, rest_y, 0.5)
	assert_eq(_screen.pass_button().text, "No attacks [SPACE]")


func test_confirming_declares_the_attack_and_the_attackers_move_to_the_left_in_id_order() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(3)
	var bears: Array[int] = _permanents("Bear")
	_click(bears[2])
	_click(bears[1])
	assert_eq(_screen.pass_button().text, "Attack with 2 [SPACE]")

	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_view_of(bears[1]).is_attacking)
	assert_true(_view_of(bears[2]).is_attacking)
	assert_true(_view_of(bears[1]).is_tapped)
	assert_false(_view_of(bears[0]).is_attacking)
	assert_false(_screen.selection().is_active(), "The selection went with its decision.")
	var first: float = _screen.face_of(bears[1]).get_global_rect().position.x
	var second: float = _screen.face_of(bears[2]).get_global_rect().position.x
	var home: float = _screen.face_of(bears[0]).get_global_rect().position.x
	assert_lt(first, second, "The attackers stand in ID order")
	assert_lt(second, home, "to the left of the Bear that stayed home, which was first in the row before.")
	assert_null(_screen.face_of(bears[1]).get_node_or_null("CombatTag"), "No ATTACKING tag (A316).")


func test_all_attack_chooses_every_candidate_without_confirming() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(3)

	_screen.info_panel().all_attack_button().pressed.emit()

	assert_true(_presenter.snapshot().decision is DeclareAttackersDecision, "Still to be confirmed (A311).")
	assert_eq(_screen.selection().attacker_ids().size(), 3)
	assert_eq(_screen.pass_button().text, "Attack with 3 [SPACE]")

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	for bear: int in _permanents("Bear"):
		assert_true(_view_of(bear).is_attacking)


func test_undo_takes_back_one_click_of_a_selection_before_it_undoes_an_answer() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(2)
	var bears: Array[int] = _permanents("Bear")
	assert_true(_screen.undo_button().disabled, "Nothing to take back yet.")
	_click(bears[0])
	_click(bears[1])
	assert_false(_screen.undo_button().disabled, "A click can be taken back (A320).")

	_screen.press_key(KEY_Z)

	assert_eq(_screen.selection().attacker_ids(), [bears[0]] as Array[int])
	assert_eq(_screen.pass_button().text, "Attack with 1 [SPACE]")
	assert_true(_presenter.snapshot().decision is DeclareAttackersDecision)

	_screen.undo_button().pressed.emit()

	assert_eq(_screen.selection().attacker_ids().size(), 0)
	assert_eq(_screen.info_panel().error_text(), "", "Nothing was asked of the presenter.")

	_screen.press_key(KEY_Z)

	assert_ne(_screen.info_panel().error_text(), "", "With no click left, Z goes to the presenter, which has nothing to undo here.")


func test_a_half_made_selection_survives_a_resize_and_a_pause() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(2)
	var bears: Array[int] = _permanents("Bear")
	_click(bears[1])

	_screen.size = Vector2(2560, 1080)

	assert_eq(_screen.selection().attacker_ids(), [bears[1]] as Array[int])
	assert_eq(_screen.pass_button().text, "Attack with 1 [SPACE]")

	_screen.press_key(KEY_ESCAPE)
	_click(bears[0])
	_screen.press_key(KEY_Z)
	_screen.press_key(KEY_SPACE)
	_screen.info_panel().all_attack_button().pressed.emit()
	_screen.pass_priority()
	_screen.undo()

	assert_eq(_screen.selection().attacker_ids(), [bears[1]] as Array[int], "Paused, nothing touches it.")
	assert_true(_presenter.snapshot().decision is DeclareAttackersDecision)

	_screen.press_key(KEY_ESCAPE)
	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_true(_view_of(bears[1]).is_attacking, "Resumed, it is confirmed as it was left.")


func test_a_selection_is_kept_when_the_same_decision_is_handed_out_again() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(2)
	var bears: Array[int] = _permanents("Bear")
	_click(bears[0])

	_screen.player_panel(HERO).step_button(MmTurn.Step.UPKEEP).pressed.emit()

	assert_true(_presenter.snapshot().decision is DeclareAttackersDecision)
	assert_eq(_screen.selection().attacker_ids(), [bears[0]] as Array[int], "Setting a stop made a new snapshot, not a new decision.")
	assert_eq(_screen.pass_button().text, "Attack with 1 [SPACE]")


func test_while_paused_a_blocker_in_hand_and_the_damage_steppers_stay_as_they_were() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	var bear: int = _permanents("Bear")[0]
	_click(bear)
	_screen.press_key(KEY_ESCAPE)

	_screen.click_empty_board()

	assert_eq(_screen.selection().picked_ids(), [bear] as Array[int], "Paused, a click on the board puts nothing down.")
	_screen.press_key(KEY_ESCAPE)
	_screen.click_empty_board()
	assert_eq(_screen.selection().picked_ids(), [] as Array[int])


func test_while_paused_damage_cannot_be_moved() -> void:
	_open_combat([_free_bear()])
	_reach_division(1)
	var ogres: Array[int] = _permanents("Ogre")
	_screen.press_key(KEY_ESCAPE)

	_screen.stepper_of(ogres[0]).minus_button().pressed.emit()

	assert_eq(_screen.selection().amounts(), [2, 0] as Array[int])


func test_while_paused_a_complete_selection_is_not_confirmed_and_no_error_shows() -> void:
	_open_combat([_free_bear()])
	_reach_division(1)
	_screen.press_key(KEY_ESCAPE)

	_screen.pass_priority()

	assert_true(_presenter.snapshot().decision is DivideCombatDamageDecision)
	assert_eq(_screen.info_panel().error_text(), "", "Paused, nothing is sent, so nothing is refused.")


func test_an_unfinished_selection_is_not_sent_when_the_hero_passes() -> void:
	_open_combat([_free_bear()])
	_reach_division(1)
	_screen.stepper_of(_permanents("Ogre")[0]).minus_button().pressed.emit()
	assert_false(_screen.selection().is_complete())

	_screen.pass_priority()

	assert_true(_presenter.snapshot().decision is DivideCombatDamageDecision)
	assert_eq(_screen.info_panel().error_text(), "", "Nothing is sent, so nothing is refused.")


func test_a_blocker_is_picked_up_and_paired_with_the_attacker_clicked() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	var bears: Array[int] = _permanents("Bear")
	var ogres: Array[int] = _permanents("Ogre")
	var info: InfoPanel = _screen.info_panel()
	assert_eq(info.prompt_text(), "Declare blockers")
	assert_eq(info.hint_text(), "Click one or more creatures, then the attacker they block.")
	assert_eq(_screen.pass_button().text, "No blocks [SPACE]")
	assert_null(_screen.click_catcher(ogres[0]), "An attacker is clicked only for a blocker in hand.")
	assert_null(BorderEffects.glow_color(_screen.face_of(ogres[0])))
	var rest_y: float = _screen.face_of(bears[0]).get_global_rect().get_center().y

	_click(bears[0])

	assert_true(BorderEffects.has_pointer(_screen.face_of(bears[0])), "The blocker picked up has the white outline (A313).")
	assert_eq(BorderEffects.glow_color(_screen.face_of(ogres[0])), DecisionClicks.color_of(DecisionClicks.Kind.TARGET))
	assert_not_null(_screen.click_catcher(ogres[0]))
	assert_eq(_screen.block_lines().line_count(), 0)
	assert_almost_eq(_screen.face_of(bears[0]).get_global_rect().get_center().y, rest_y, 0.5, "In hand, it has not stepped forward.")

	_click(ogres[0])

	assert_eq(_screen.selection().pairs(), [[bears[0], ogres[0]]])
	assert_false(BorderEffects.has_pointer(_screen.face_of(bears[0])), "Paired, it is put down.")
	assert_null(BorderEffects.glow_color(_screen.face_of(ogres[0])))
	assert_eq(_screen.block_lines().line_count(), 1)
	assert_eq(_screen.block_lines().line_color(0), BlockLines.CHOSEN)
	assert_almost_eq(rest_y - _screen.face_of(bears[0]).get_global_rect().get_center().y, EncounterLayout.COMBAT_STEP, 0.5,
		"The blocker stepped into the lane.")
	assert_eq(_screen.pass_button().text, "Confirm blocks [SPACE]")
	assert_eq(info.hint_text(), "", "The hint goes once a block is made (A326).")
	assert_true(_presenter.snapshot().decision is DeclareBlockersDecision)


func test_blockers_clicked_one_after_another_are_all_paired_with_the_attacker_clicked() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	var bears: Array[int] = _permanents("Bear")
	var ogre: int = _permanents("Ogre")[0]

	_click(bears[0])
	_click(bears[1])

	assert_true(BorderEffects.has_pointer(_screen.face_of(bears[0])), "Both are picked up (A430).")
	assert_true(BorderEffects.has_pointer(_screen.face_of(bears[1])))
	assert_eq(_screen.block_lines().line_count(), 0)

	_click(ogre)

	assert_eq(_screen.selection().pairs(), [[bears[0], ogre], [bears[1], ogre]])
	assert_false(BorderEffects.has_pointer(_screen.face_of(bears[0])), "Paired, they are put down.")
	assert_false(BorderEffects.has_pointer(_screen.face_of(bears[1])))
	assert_eq(_screen.block_lines().line_count(), 2)
	assert_eq(_screen.info_panel().error_text(), "")


func test_a_group_with_a_blocker_that_cannot_block_the_attacker_is_refused_with_an_error() -> void:
	var spider: MmCardDefinition = Scenario.creature("Spider", 1, 3, [ReachAbility.new()], Scenario.mana_cost(0))
	var ogre: MmCardDefinition = Scenario.creature("Ogre", 2, 2, [], Scenario.mana_cost(0))
	var drake: MmCardDefinition = Scenario.creature("Drake", 2, 2, [FlyingAbility.new()], Scenario.mana_cost(0))
	_open_combat([_free_bear(), spider], [ogre, drake])
	_cast_creatures(4)
	_pass_until(func() -> bool:
		var blocks: DeclareBlockersDecision = _presenter.snapshot().decision as DeclareBlockersDecision
		return blocks != null and _attacking("Ogre") != 0 and _attacking("Drake") != 0)
	var bear: int = _permanents("Bear")[0]
	var spider_id: int = _permanents("Spider")[0]
	var drake_id: int = _attacking("Drake")
	var ogre_id: int = _attacking("Ogre")

	_click(bear)
	_click(spider_id)

	var target: Color = DecisionClicks.color_of(DecisionClicks.Kind.TARGET)
	assert_eq(BorderEffects.glow_color(_screen.face_of(drake_id)), target, "The Spider can block it, so it glows (A431).")
	assert_eq(BorderEffects.glow_color(_screen.face_of(ogre_id)), target)

	_click(drake_id)

	assert_eq(_screen.info_panel().error_text(), "Bear cannot block Drake.", "A432.")
	assert_eq(_screen.selection().pairs().size(), 0, "Nothing is assigned, not even the Spider.")
	assert_eq(_screen.selection().picked_ids(), [bear, spider_id] as Array[int], "The group stays picked up.")
	assert_eq(_screen.block_lines().line_count(), 0)

	_click(bear)

	assert_eq(_screen.info_panel().error_text(), "", "The next click clears the error.")
	_click(drake_id)
	assert_eq(_screen.selection().pairs(), [[spider_id, drake_id]])


func test_a_block_line_runs_from_the_blocker_up_to_its_attacker() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	var bear: int = _permanents("Bear")[1]
	var ogre: int = _permanents("Ogre")[0]

	_click(bear)
	_click(ogre)

	var lines: BlockLines = _screen.block_lines()
	var blocker: Rect2 = _screen.face_of(bear).get_global_rect()
	var attacker: Rect2 = _screen.face_of(ogre).get_global_rect()
	assert_almost_eq(lines.line_from(0).x, blocker.get_center().x, 0.5)
	assert_almost_eq(lines.line_from(0).y, blocker.position.y - EncounterLayout.BLOCK_LINE_GAP, 0.5, "From the top of the Hero's creature")
	assert_almost_eq(lines.line_to(0).x, attacker.get_center().x, 0.5)
	assert_almost_eq(lines.line_to(0).y, attacker.end.y + EncounterLayout.BLOCK_LINE_GAP, 0.5, "to the bottom of the Villain's.")
	assert_gt(lines.get_index(), _screen.face_of(bear).get_parent().get_index() * 0, "It is a layer of its own.")
	assert_lt(lines.get_index(), _screen.stack_window().get_index(), "Under the windows.")


func test_blockers_declared_crossing_swap_places_so_their_lines_do_not_cross() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	var attackers: Array[int] = []
	for ogre: int in _permanents("Ogre"):
		if _view_of(ogre).is_attacking:
			attackers.append(ogre)
	attackers.sort()
	assert_eq(attackers.size(), 2, "Two Ogres attack.")
	var bears: Array[int] = _permanents("Bear")
	bears.sort()
	# The lower Bear blocks the higher Ogre: in ID order the lines would cross.
	_click(bears[0])
	_click(attackers[1])
	_click(bears[1])
	_click(attackers[0])

	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	var lines: BlockLines = _screen.block_lines()
	assert_eq(lines.line_count(), 2)
	var from_left: bool = lines.line_from(0).x < lines.line_from(1).x
	var to_left: bool = lines.line_to(0).x < lines.line_to(1).x
	assert_eq(from_left, to_left, "The blocker on the left blocks the attacker on the left.")
	assert_lt(_screen.face_of(bears[1]).get_global_rect().position.x, _screen.face_of(bears[0]).get_global_rect().position.x,
		"The Bears swapped places.")


func test_one_click_on_a_blocking_creature_takes_it_off_its_block() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	var bear: int = _permanents("Bear")[0]
	_click(bear)
	_click(_permanents("Ogre")[0])
	assert_eq(_screen.block_lines().line_count(), 1)

	_click(bear)

	assert_eq(_screen.selection().pairs().size(), 0)
	assert_eq(_screen.block_lines().line_count(), 0)
	assert_false(BorderEffects.has_pointer(_screen.face_of(bear)), "Taken off, not picked up.")
	assert_eq(_screen.pass_button().text, "No blocks [SPACE]")


func test_a_press_on_the_board_puts_a_picked_up_blocker_down_but_a_press_on_a_card_in_hand_does_not() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	var bear: int = _permanents("Bear")[0]
	_click(bear)
	assert_eq(_screen.selection().picked_ids(), [bear] as Array[int])
	var card: Control = _screen.face_of(_presenter.snapshot().view.hand[0].id)
	var on_card: InputEventMouseButton = InputEventMouseButton.new()
	on_card.button_index = MOUSE_BUTTON_LEFT
	on_card.pressed = true
	on_card.position = card.position + Vector2(30, 60)
	var on_board: InputEventMouseButton = on_card.duplicate() as InputEventMouseButton
	on_board.position = Vector2(1000, 500)

	_screen._input(on_card)
	assert_eq(_screen.selection().picked_ids(), [bear] as Array[int], "The press was the hand's.")
	assert_true(_screen.drag_card().is_pressed())
	_screen.cancel_drag()
	_screen._gui_input(on_board)
	assert_eq(_screen.selection().picked_ids(), [] as Array[int], "A314.")


func test_a_click_on_empty_board_puts_a_picked_up_blocker_down_unassigned() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	var bear: int = _permanents("Bear")[0]
	_click(bear)
	assert_true(BorderEffects.has_pointer(_screen.face_of(bear)))

	_screen.click_empty_board()

	assert_false(BorderEffects.has_pointer(_screen.face_of(bear)))
	assert_eq(_screen.selection().pairs().size(), 0)
	assert_eq(_screen.block_lines().line_count(), 0)
	assert_eq(_screen.pass_button().text, "No blocks [SPACE]")

	_screen.click_empty_board()
	assert_eq(_screen.selection().can_undo(), true, "The clicks so far can still be taken back,")
	var clicks_before: Array = _screen.selection().pairs()
	_screen.click_empty_board()
	assert_eq(_screen.selection().pairs(), clicks_before, "and a click on nothing with nothing in hand changes nothing.")


func test_confirmed_blocks_are_declared_and_drawn_white_with_the_blockers_to_the_left() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(3)
	var bears: Array[int] = _permanents("Bear")
	var ogre: int = _permanents("Ogre")[0]
	_click(bears[2])
	_click(ogre)
	_click(bears[1])
	_click(ogre)
	assert_eq(_screen.block_lines().line_count(), 2, "Two blockers on one attacker.")

	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	if _presenter.snapshot().view.battlefield.any(func(seen: MmObjectView) -> bool: return seen.id == bears[1]):
		assert_eq(_view_of(bears[1]).blocking_ids, [ogre] as Array[int])
		assert_eq(_view_of(bears[2]).blocking_ids, [ogre] as Array[int])
		assert_eq(_screen.block_lines().line_count(), 2)
		assert_eq(_screen.block_lines().line_color(0), BlockLines.DECLARED)
		assert_lt(_screen.face_of(bears[2]).get_global_rect().position.x, _screen.face_of(bears[0]).get_global_rect().position.x,
			"The blockers stand to the left of the Bear that blocks nothing.")
		assert_null(_screen.face_of(bears[1]).get_node_or_null("CombatTag"), "No BLOCKING tag (A316).")
	else:
		fail_test("The blockers should still be on the battlefield while the Hero has priority after blocking.")


func test_the_villains_blocks_are_drawn_the_same_way() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(1)
	var bear: int = _permanents("Bear")[0]
	_click(bear)

	_screen.pass_priority()
	_presenter.wait_until_idle()
	_pass_until(func() -> bool: return _presenter.snapshot().view.step != MmTurn.Step.DECLARE_ATTACKERS)

	assert_true(_presenter.snapshot().decision is DivideCombatDamageDecision or _view_of(bear).is_blocked,
		"The Villain blocked the Bear with both Ogres.")
	assert_eq(_screen.block_lines().line_count(), 2)
	assert_eq(_screen.block_lines().line_color(0), BlockLines.DECLARED)
	for line: int in 2:
		assert_almost_eq(_screen.block_lines().line_to(line).x, _screen.face_of(bear).get_global_rect().get_center().x, 0.5,
			"Each line ends at the Hero's attacker.")
	for ogre: int in _permanents("Ogre"):
		assert_null(_screen.face_of(ogre).get_node_or_null("CombatTag"))


func test_damage_is_divided_with_steppers_on_the_blockers() -> void:
	_open_combat([_free_bear()])
	_reach_division(1)
	var bear: int = _permanents("Bear")[0]
	var ogres: Array[int] = _permanents("Ogre")
	var first: DamageStepper = _screen.stepper_of(ogres[0])
	assert_eq(_screen.info_panel().prompt_text(), "Divide 2 damage from Bear")
	assert_true(BorderEffects.has_pointer(_screen.face_of(bear)), "The creature dividing has the white outline (A325).")
	assert_eq((_screen.face_of(bear).get_node("LeftChip/Text") as Label).text, "0 left")
	assert_eq(first.amount_text(), "2", "It starts by killing the first blocker (A318).")
	assert_true(first.shows_lethal())
	assert_eq(_screen.stepper_of(ogres[1]).amount_text(), "0")
	assert_false(_screen.stepper_of(ogres[1]).shows_lethal())
	assert_true(_screen.stepper_of(ogres[1]).plus_button().disabled, "Nothing is left to give.")
	assert_eq(first.get_parent(), _screen.face_of(ogres[0]), "On the creature itself.")
	assert_null(_screen.stepper_of(bear))
	assert_eq(_screen.pass_button().text, "Assign damage [SPACE]")
	assert_false(_screen.pass_button().disabled)

	first.minus_button().pressed.emit()

	assert_eq(_screen.stepper_of(ogres[0]).amount_text(), "1")
	assert_false(_screen.stepper_of(ogres[0]).shows_lethal())
	assert_eq((_screen.face_of(bear).get_node("LeftChip/Text") as Label).text, "1 left")
	assert_true(_screen.pass_button().disabled, "Grayed out until all of it is assigned.")
	_screen.press_key(KEY_SPACE)
	assert_true(_presenter.snapshot().decision is DivideCombatDamageDecision, "And Space does not confirm it either.")

	_screen.stepper_of(ogres[1]).plus_button().pressed.emit()
	assert_false(_screen.pass_button().disabled)
	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_eq(_view_of(ogres[0]).damage_marked, 1)
	assert_eq(_view_of(ogres[1]).damage_marked, 1)
	assert_null(_screen.stepper_of(ogres[0]), "The steppers go with the decision.")


func test_with_trample_the_attacked_players_portrait_has_a_stepper_too() -> void:
	_open_combat([Scenario.creature("Trampler", 6, 6, [TrampleAbility.new()] as Array[MmAbility])])
	_reach_division(1)
	var ogres: Array[int] = _permanents("Ogre")
	var villain: DamageStepper = _screen.player_stepper(VILLAIN)

	assert_not_null(villain)
	assert_eq(villain.get_parent(), _screen.player_panel(VILLAIN).portrait(), "On the portrait, where the player is clicked.")
	assert_null(_screen.player_stepper(HERO))
	assert_eq(_screen.stepper_of(ogres[0]).amount_text(), "2")
	assert_eq(_screen.stepper_of(ogres[1]).amount_text(), "2")
	assert_eq(villain.amount_text(), "2", "What is over after lethal to both goes to the player.")
	assert_true(_screen.stepper_of(ogres[0]).minus_button().disabled, "A blocker keeps lethal while the player has damage (CR 702.19b).")

	villain.minus_button().pressed.emit()
	_screen.player_stepper(VILLAIN).minus_button().pressed.emit()
	assert_false(_screen.stepper_of(ogres[0]).minus_button().disabled, "With nothing on the player, a blocker may be given less.")
	_screen.stepper_of(ogres[0]).minus_button().pressed.emit()

	assert_eq(_screen.player_stepper(VILLAIN).amount_text(), "0")
	assert_true(_screen.player_stepper(VILLAIN).plus_button().disabled, "A blocker is short of lethal.")
	assert_true(_screen.pass_button().disabled)

	for click: int in 3:
		_screen.press_key(KEY_Z)
	assert_eq(_screen.player_stepper(VILLAIN).amount_text(), "2", "Three clicks taken back.")
	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().view.life_totals[VILLAIN], 18)


func test_a_block_line_to_a_creature_scrolled_out_of_sight_ends_on_the_arrow_toward_it() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(4)
	var bears: Array[int] = _permanents("Bear")
	var ogre: int = _permanents("Ogre")[0]
	# Narrow enough that the last Bear is out of sight at the right end of its line.
	_screen.size = Vector2(1100, 1080)
	var line: ScrollRow = _screen.line("hero_creatures")
	line.scroll_to(0.0)
	assert_true(line.can_scroll())

	_click(bears[3])
	_click(ogre)

	var arrow: float = line.right_arrow().get_global_rect().get_center().x
	assert_almost_eq(_screen.block_lines().line_from(0).x, arrow, 0.5, "Drawn to the arrow that points toward the Bear (A327).")

	_screen.line("hero_creatures").scroll_by(9000.0)

	assert_almost_eq(_screen.block_lines().line_from(0).x, _screen.face_of(bears[3]).get_global_rect().get_center().x, 0.5,
		"Scrolled into view, the line ends on the Bear itself.")


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


## Opens a screen where the Hero's deck cycles through [param cards] and the Villain, who
## fights, has free 2/2 Ogres.
func _open_combat(cards: Array[MmCardDefinition], villain_cards: Array[MmCardDefinition] = []) -> void:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	var ogre: MmCardDefinition = Scenario.creature("Ogre", 2, 2, [], Scenario.mana_cost(0))
	var villain_deck: Array[MmCardDefinition] = Scenario.copies(ogre, 40)
	for index: int in villain_deck.size() if not villain_cards.is_empty() else 0:
		villain_deck[index] = villain_cards[index % villain_cards.size()]
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(Scenario.setup_with(deck, villain_deck), CombatAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_keep()


## Casts [param count] of the Hero's creatures as soon as they can be cast.
func _cast_creatures(count: int) -> void:
	_pass_until(func() -> bool:
		var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
		return priority != null and priority.actions.any(func(action: MmAction) -> bool: return action is CastSpellAction))
	for cast: int in count:
		var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
		for index: int in priority.actions.size():
			if priority.actions[index] is CastSpellAction:
				_presenter.answer(index)
				break
		_presenter.wait_until_idle()


## The Hero has [param count] creatures and is asked which of them attack.
func _reach_attackers(count: int) -> void:
	_cast_creatures(count)
	_pass_until(func() -> bool:
		var attackers: DeclareAttackersDecision = _presenter.snapshot().decision as DeclareAttackersDecision
		return attackers != null and attackers.candidate_ids.size() == count)


## The Hero has [param count] creatures and is asked how they block the Villain's Ogres.
func _reach_blockers(count: int) -> void:
	_cast_creatures(count)
	_pass_until(func() -> bool:
		var blocks: DeclareBlockersDecision = _presenter.snapshot().decision as DeclareBlockersDecision
		return blocks != null and blocks.candidate_blocker_ids.size() == count)


## The Hero attacks with their [param count] creatures, the Villain's two Ogres block the
## first, and the Hero is asked to divide its damage.
func _reach_division(count: int) -> void:
	_cast_creatures(count)
	for attempt: int in 12:
		_pass_until(func() -> bool:
			var attackers: DeclareAttackersDecision = _presenter.snapshot().decision as DeclareAttackersDecision
			return attackers != null and attackers.candidate_ids.size() == count)
		if _permanents("Ogre").size() >= 2 and _permanents("Ogre").all(func(ogre: int) -> bool: return not _view_of(ogre).is_tapped):
			break
		_presenter.answer([] as Array[int])
		_presenter.wait_until_idle()
	_presenter.answer((_presenter.snapshot().decision as DeclareAttackersDecision).candidate_ids.duplicate())
	_presenter.wait_until_idle()
	_pass_until(func() -> bool: return _presenter.snapshot().decision is DivideCombatDamageDecision)


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


## The first attacking creature named [param card_name], or 0.
func _attacking(card_name: String) -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name and permanent.is_attacking:
			return permanent.id
	return 0


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
		elif decision is DivideCombatDamageDecision:
			_presenter.answer(CombatSelection.default_split(decision as DivideCombatDamageDecision))
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
		if is_instance_of(action, kind) and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
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


func test_x_cancels_a_cast_as_the_cancel_button_does_and_does_nothing_without_one() -> void:
	_open(_shock_setup())
	_keep()
	var snapshot: EncounterSnapshot = _presenter.snapshot()

	_screen.press_key(KEY_X)

	assert_eq(_presenter.snapshot(), snapshot, "Nothing to cancel: nothing happens.")

	_do(CastSpellAction, "Zap")
	assert_eq(_screen.info_panel().cancel_button().text, "Cancel [X]")
	_screen.press_key(KEY_X)

	assert_true(_presenter.snapshot().decision is PriorityDecision)
	assert_eq(_presenter.snapshot().view.hand.size(), 7, "The spell is back in the hand.")
	assert_null(_screen.info_panel().cancel_button())


func test_a_rebound_key_passes_and_the_old_one_does_nothing_and_the_buttons_name_the_new_keys() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	var step: MmTurn.Step = _presenter.snapshot().view.step
	_screen.key_bindings().bind(KeyBindings.Action.PASS, KEY_ENTER)
	_screen.key_bindings().bind(KeyBindings.Action.UNDO, KEY_BACKSPACE)
	_screen._on_keys_changed()
	assert_eq(_screen.pass_button().text, "Pass Priority [ENTER]")
	assert_eq(_screen.undo_button().text, "Undo [BACKSPACE]")

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()
	assert_eq(_presenter.snapshot().view.step, step, "Space passes nothing any more.")

	_screen.press_key(KEY_ENTER)
	_presenter.wait_until_idle()

	assert_ne(_presenter.snapshot().view.step, step, "Enter passed.")
	assert_eq(_screen.pass_button().text, "Pass Priority [ENTER]", "A redraw still names it.")


func test_a_key_shared_by_pass_and_undo_only_passes() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	_do(PlayLandAction, "Forest")
	var step: MmTurn.Step = _presenter.snapshot().view.step
	_screen.key_bindings().bind(KeyBindings.Action.UNDO, KEY_SPACE)

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_ne(_presenter.snapshot().view.step, step, "It passed")
	assert_eq(_presenter.snapshot().view.battlefield.size(), 1, "and the land was not taken back.")


func test_the_hold_key_is_whichever_key_holding_priority_is_bound_to() -> void:
	_open(_bear_setup())
	assert_eq(_screen.hold_key(), KEY_CTRL)

	_screen.key_bindings().bind(KeyBindings.Action.HOLD, KEY_SPACE)

	assert_eq(_screen.hold_key(), KEY_SPACE, "It can share a key with a press.")
	assert_eq(_screen.key_bindings().pressed_action(KEY_SPACE), KeyBindings.Action.PASS)


func test_a_key_pressed_while_a_row_of_the_controls_page_waits_is_bound_and_does_nothing_else() -> void:
	_open(_bear_setup())
	_keep_and_reach_main()
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	_screen.press_key(KEY_ESCAPE)
	_screen.pause_menu().button(PauseMenu.SETTINGS).pressed.emit()
	_screen.pause_menu().button(PauseMenu.CONTROLS).pressed.emit()
	_screen.pause_menu().key_button(KeyBindings.Action.PASS).pressed.emit()

	_screen.press_key(KEY_ESCAPE)

	assert_true(_screen.is_paused(), "Escape only stopped the row waiting.")
	assert_false(_screen.pause_menu().is_waiting_for_key())
	assert_eq(_screen.key_bindings().key_of(KeyBindings.Action.PASS), KEY_SPACE)

	_screen.pause_menu().key_button(KeyBindings.Action.PASS).pressed.emit()
	_screen.press_key(KEY_Z)

	assert_eq(_screen.key_bindings().key_of(KeyBindings.Action.PASS), KEY_Z)
	assert_eq(_presenter.snapshot(), snapshot, "Z undid nothing: it was the row's.")
	assert_true(_screen.pause_menu().shows_shared(KeyBindings.Action.UNDO))
	_screen.press_key(KEY_Z)
	assert_eq(_presenter.snapshot(), snapshot, "And no bound key acts while the Pause Menu is open.")
	assert_eq(_screen.pass_button().text, "Pass Priority [Z]")

	_screen.press_key(KEY_ESCAPE)
	assert_false(_screen.is_paused(), "Escape closes the menu from the Controls Page.")


func test_the_pass_button_is_always_there_gray_over_the_info_panel() -> void:
	_open(_bear_setup())
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)

	assert_true(_screen.pass_button().visible, "Even through the pregame, under the overlay.")
	assert_true(_screen.pass_button().disabled)
	assert_eq(_screen.pass_button().get_global_rect(), regions["pass"])
	assert_eq(_screen.info_panel().get_global_rect(), regions["info"])
	assert_lt(_screen.pass_button().get_index(), _screen.opening_overlay().get_index(), "The opening-hand overlay covers it.")


func test_yield_turn_clicked_while_declaring_attackers_confirms_them_and_yields() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(2)
	var bears: Array[int] = _permanents("Bear")
	_click(bears[0])

	_screen.yield_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_true(_presenter.is_yielding())
	assert_false(_presenter.snapshot().decision is DeclareAttackersDecision, "The attack was declared as it stood (A494).")
	assert_true(_view_of(bears[0]).is_attacking, "The Bear that was chosen attacks")
	assert_false(_view_of(bears[1]).is_attacking, "and the other stayed home.")
	assert_true(_presenter.snapshot().decision is DivideCombatDamageDecision, "A choice that is not priority is still asked.")


func test_yield_turn_clicked_while_declaring_blockers_confirms_no_blocks_and_yields() -> void:
	_open_combat([_free_bear()])
	_reach_blockers(2)
	assert_true(_presenter.snapshot().decision is DeclareBlockersDecision)
	var turn: int = _presenter.snapshot().view.game_turn
	var life: int = _presenter.snapshot().view.life_totals[HERO]

	_screen.yield_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is DeclareBlockersDecision, "No blocks were declared.")
	assert_lt(_presenter.snapshot().view.life_totals[HERO], life, "The attackers got through")
	assert_gt(_presenter.snapshot().view.game_turn, turn, "and the rest of the turn was passed.")


func test_ending_a_yield_while_declaring_attackers_confirms_nothing() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(2)
	_presenter.set_yielding(true)
	assert_true(_presenter.snapshot().decision is DeclareAttackersDecision, "A Yield still asks for attackers.")

	_screen.yield_button().pressed.emit()

	assert_false(_presenter.is_yielding())
	assert_true(_presenter.snapshot().decision is DeclareAttackersDecision, "Only starting one confirms.")


func test_all_attack_becomes_undeclare_all_while_any_attacker_is_declared() -> void:
	_open_combat([_free_bear()])
	_reach_attackers(3)
	var bears: Array[int] = _permanents("Bear")
	assert_eq(_screen.info_panel().all_attack_button().text, "Declare All")

	_click(bears[0])

	assert_eq(_screen.info_panel().all_attack_button().text, "Undeclare All", "One is enough (A496).")

	_screen.info_panel().all_attack_button().pressed.emit()

	assert_eq(_screen.selection().attacker_ids().size(), 0)
	assert_true(_presenter.snapshot().decision is DeclareAttackersDecision, "Nothing is confirmed.")
	assert_eq(_screen.info_panel().all_attack_button().text, "Declare All", "It turns back with none declared.")
	assert_eq(_screen.pass_button().text, "No attacks [SPACE]")

	_screen.info_panel().all_attack_button().pressed.emit()
	assert_eq(_screen.selection().attacker_ids().size(), 3)
	assert_eq(_screen.info_panel().all_attack_button().text, "Undeclare All")
	_click(bears[0])
	_click(bears[1])
	_click(bears[2])
	assert_eq(_screen.info_panel().all_attack_button().text, "Declare All", "Put back one at a time, it turns back too.")
	_screen.press_key(KEY_Z)
	assert_eq(_screen.info_panel().all_attack_button().text, "Undeclare All", "And follows an undo.")
