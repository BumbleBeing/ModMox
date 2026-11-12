extends GutTest
## The Stack Window on the Encounter Screen (13d-1): colored entries, what the entry under
## the cursor marks, spells clicked as targets, arrows between spells, triggers put in
## order, and the window that asks which replacement effect applies first.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const TARGET: Color = Color("#ff5a2a")

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


# --- Entries ---------------------------------------------------------------------------

func test_a_spells_entry_has_its_name_its_controller_and_target_and_its_own_color() -> void:
	_open([Scenario.free_shock("Zap", 2)])
	_presenter.is_hold_key_down = true

	_cast("Zap", MmReference.to_player(VILLAIN))

	var zap: MmObjectView = _presenter.snapshot().view.stack[0]
	var entry: StackEntry = _screen.stack_entries()[0]
	assert_eq(entry.name_text(), "Zap")
	assert_eq(entry.detail_text(), "Hero → Villain")
	assert_true(entry.is_cut())
	assert_eq(entry.color(), StackColors.HUES[zap.id % StackColors.HUES.size()])
	assert_eq(entry.border_color(), entry.color())
	assert_eq(entry.stripe_color(), entry.color())
	assert_eq(_screen.stack_entry_of(zap.id), entry)
	assert_null(_screen.stack_entry_of(zap.id + 500))


func test_an_abilitys_entry_leads_with_what_it_does() -> void:
	_open([_wand()])
	_cast("Wand")
	_presenter.is_hold_key_down = true

	_click(_permanent("Wand"))
	_choose(MmReference.to_player(VILLAIN))

	var entry: StackEntry = _screen.stack_entries()[0]
	assert_eq(entry.name_text(), "This artifact deals 1 damage to any target.")
	assert_eq(entry.detail_text(), "Hero → Villain")


func test_each_object_keeps_its_color_while_others_join_it() -> void:
	_open([Scenario.free_shock("Zap", 2), Scenario.free_shock("Jolt", 2)])
	_presenter.is_hold_key_down = true
	_cast("Zap", MmReference.to_player(VILLAIN))
	var zap: int = _presenter.snapshot().view.stack[0].id
	var before: Color = _screen.stack_entry_of(zap).color()

	_cast("Jolt", MmReference.to_player(VILLAIN))

	var jolt: int = _presenter.snapshot().view.stack[1].id
	assert_eq(_screen.stack_entry_of(zap).color(), before)
	assert_ne(_screen.stack_entry_of(jolt).color(), before, "Each has a color of its own.")
	assert_eq(_screen.stack_entries()[0], _screen.stack_entry_of(jolt), "The top of the stack is listed first.")


# --- Hovering --------------------------------------------------------------------------

func test_hovering_an_ability_marks_its_source_solid_and_its_target_player_dashed_on_the_portrait() -> void:
	_open([_wand()])
	_cast("Wand")
	_presenter.is_hold_key_down = true
	_click(_permanent("Wand"))
	_choose(MmReference.to_player(VILLAIN))
	var entry: StackEntry = _screen.stack_entries()[0]
	var wand: Control = _screen.face_of(_permanent("Wand"))
	var portrait: Control = _screen.player_panel(VILLAIN).portrait()
	var info: InfoPanel = _screen.info_panel()
	var prompt: String = info.prompt_text()

	entry.hovered.emit(true)

	assert_eq(BorderEffects.mark_color(wand), entry.color(), "The source, in the entry's color.")
	assert_false(BorderEffects.is_mark_dashed(wand), "Solid: it is set in stone.")
	assert_eq(BorderEffects.mark_color(portrait), entry.color())
	assert_true(BorderEffects.is_mark_dashed(portrait), "Dashed: it is about to happen.")
	assert_null(BorderEffects.mark_color(_screen.player_panel(VILLAIN)), "The portrait only, not the whole panel.")
	assert_null(BorderEffects.mark_color(_screen.player_panel(HERO).portrait()))
	assert_eq(info.option_text(), "Wand's ability — This artifact deals 1 damage to any target.")
	assert_false(info.shows_prompt())

	entry.hovered.emit(false)

	assert_null(BorderEffects.mark_color(wand))
	assert_null(BorderEffects.mark_color(portrait))
	assert_eq(info.option_text(), "")
	assert_true(info.shows_prompt())
	assert_eq(info.prompt_text(), prompt)


func test_hovering_a_spell_marks_the_permanent_it_targets_and_no_source() -> void:
	_open([_free_bear(), Scenario.free_shock("Zap", 2)])
	_cast("Bear")
	_presenter.is_hold_key_down = true
	_cast("Zap", MmReference.to_object(_permanent("Bear")))
	var entry: StackEntry = _screen.stack_entries()[0]
	var bear: Control = _screen.face_of(_permanent("Bear"))

	entry.hovered.emit(true)

	assert_eq(entry.detail_text(), "Hero → Bear")
	assert_eq(BorderEffects.mark_color(bear), entry.color())
	assert_true(BorderEffects.is_mark_dashed(bear))
	assert_eq(_screen.info_panel().option_text(), "Zap — Zap deals 2 damage to any target.")


func test_a_redraw_takes_the_marks_away_even_from_a_portrait() -> void:
	_open([Scenario.free_shock("Zap", 2)])
	_presenter.is_hold_key_down = true
	_cast("Zap", MmReference.to_player(VILLAIN))
	var portrait: Control = _screen.player_panel(VILLAIN).portrait()
	_screen.stack_entries()[0].hovered.emit(true)
	assert_not_null(BorderEffects.mark_color(portrait))

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_null(BorderEffects.mark_color(portrait), "The spell has resolved, and its entry is gone.")


func test_a_hovered_target_that_answers_a_decision_loses_its_glow_but_still_takes_the_click() -> void:
	_open([_free_bear(), _wand(), Scenario.free_shock("Zap", 2)])
	_cast("Bear")
	_cast("Wand")
	_presenter.is_hold_key_down = true
	var bear_id: int = _permanent("Bear")
	_click(_permanent("Wand"))
	_choose(MmReference.to_object(bear_id))
	_do(CastSpellAction, "Zap")
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision)
	var entry: StackEntry = _screen.stack_entry_of(_presenter.snapshot().view.stack[0].id)
	var bear: Control = _screen.face_of(bear_id)
	assert_eq(BorderEffects.glow_color(bear), TARGET)
	assert_true(BorderEffects.is_glow_showing(bear))

	entry.hovered.emit(true)

	assert_eq(BorderEffects.mark_color(bear), entry.color())
	assert_false(BorderEffects.is_glow_showing(bear), "The stack's color wins while the entry is hovered (A346).")
	assert_not_null(_screen.click_catcher(bear_id))

	entry.hovered.emit(false)

	assert_true(BorderEffects.is_glow_showing(bear), "The Glow is back.")
	_click(bear_id)
	assert_false(_presenter.snapshot().decision is ChooseTargetDecision, "The click chose it.")


# --- Spells as targets, and arrows ---------------------------------------------------------

func test_a_spell_that_can_be_targeted_glows_on_its_entry_and_is_clicked_there() -> void:
	_open([Scenario.free_shock("Zap", 2), Scenario.free_counter("Counter")])
	_presenter.is_hold_key_down = true
	_cast("Zap", MmReference.to_player(VILLAIN))
	var zap: int = _presenter.snapshot().view.stack[0].id
	var own_color: Color = _screen.stack_entry_of(zap).color()
	assert_null(_screen.stack_entry_of(zap).click_catcher(), "Nothing asks for a spell yet.")
	assert_eq(_screen.stack_arrows().arrow_count(), 0)
	assert_eq(_screen.stack_arrows().custom_minimum_size.x, 0.0, "No arrows, no margin for them.")

	_do(CastSpellAction, "Counter")

	var entry: StackEntry = _screen.stack_entry_of(zap)
	assert_eq(_screen.info_panel().prompt_text(), "Choose a target for Counter")
	assert_eq(entry.border_color(), TARGET)
	assert_eq(entry.stripe_color(), own_color)
	assert_not_null(entry.click_catcher())
	var counter: int = _presenter.snapshot().view.stack[1].id
	assert_null(_screen.stack_entry_of(counter).click_catcher(), "A spell cannot target itself.")

	entry.click_catcher().clicked.emit()

	assert_false(_presenter.snapshot().decision is ChooseTargetDecision)
	assert_eq(_screen.stack_entry_of(counter).detail_text(), "Hero → Zap")
	assert_eq(_screen.stack_entry_of(zap).border_color(), own_color, "Its own color again.")


func test_an_arrow_runs_from_a_spell_to_the_spell_it_targets_in_its_own_color() -> void:
	_open([Scenario.free_shock("Zap", 2), Scenario.free_counter("Counter")])
	_presenter.is_hold_key_down = true
	_cast("Zap", MmReference.to_player(VILLAIN))
	var zap: int = _presenter.snapshot().view.stack[0].id

	_cast("Counter", MmReference.to_object(zap))

	var counter: int = _presenter.snapshot().view.stack[1].id
	var arrows: StackArrows = _screen.stack_arrows()
	assert_eq(arrows.arrow_count(), 1)
	assert_eq(arrows.arrow_color(0), _screen.stack_entry_of(counter).color())
	assert_eq(arrows.custom_minimum_size.x, StackArrows.width_for(1))
	await wait_process_frames(2)
	assert_lt(arrows.arrow_from(0).y, arrows.arrow_to(0).y, "From the Counter on top down to the Zap.")


func test_two_spells_that_target_spells_have_an_arrow_each() -> void:
	_open([Scenario.free_shock("Zap", 2), Scenario.free_counter("Counter")])
	_presenter.is_hold_key_down = true
	_cast("Zap", MmReference.to_player(VILLAIN))
	_cast("Counter", MmReference.to_object(_presenter.snapshot().view.stack[0].id))
	var first: int = _presenter.snapshot().view.stack[1].id

	_cast("Counter", MmReference.to_object(first))

	var second: int = _presenter.snapshot().view.stack[2].id
	var arrows: StackArrows = _screen.stack_arrows()
	assert_eq(arrows.arrow_count(), 2)
	assert_eq(arrows.arrow_color(0), _screen.stack_entry_of(second).color(), "The top spell's arrow first.")
	assert_eq(arrows.arrow_color(1), _screen.stack_entry_of(first).color())
	assert_eq(arrows.custom_minimum_size.x, StackArrows.width_for(2))


func test_while_paused_a_spell_cannot_be_chosen() -> void:
	_open([Scenario.free_shock("Zap", 2), Scenario.free_counter("Counter")])
	_presenter.is_hold_key_down = true
	_cast("Zap", MmReference.to_player(VILLAIN))
	_do(CastSpellAction, "Counter")
	_screen.press_key(KEY_ESCAPE)

	_screen.stack_entries()[1].click_catcher().clicked.emit()

	assert_true(_presenter.snapshot().decision is ChooseTargetDecision)
	assert_eq(_screen.info_panel().error_text(), "")


# --- Ordering triggers -----------------------------------------------------------------

func test_triggers_to_order_stand_dashed_above_the_stack_with_their_whole_text() -> void:
	_reach_trigger_order()

	var entries: Array[StackEntry] = _screen.trigger_entries()
	assert_true(_screen.stack_window().visible, "Though nothing is on the stack yet.")
	assert_eq(_screen.stack_window().title_text(), "Stack (0)")
	assert_eq(entries.size(), 2)
	assert_eq(entries[0].name_text(), "At the beginning of your upkeep, you gain 1 life.")
	assert_eq(entries[1].name_text(), "At the beginning of your upkeep, you gain 2 life.")
	assert_eq(entries[0].detail_text(), "Hero")
	assert_true(entries[0].is_dashed())
	assert_eq(entries[0].color(), StackColors.PLAIN)
	for entry: StackEntry in entries:
		assert_not_null(entry.grip(), "Each is dragged by its grip, or anywhere else on it (A393).")
		assert_eq(entry.find_children("*", "Button", true, false).size(), 0, "No move buttons.")
	assert_eq(_screen.trigger_list().get_parent(), _screen.stack_window().body())
	var says: Label = _screen.stack_window().body().get_child(0) as Label
	assert_eq(says.text, "Triggers to order: drag them, the top one resolves first")
	assert_eq(_screen.trigger_list().get_index(), 1, "The list is under the line that says what to do.")
	assert_eq(_screen.info_panel().prompt_text(), "Order your triggers")
	assert_eq(_screen.pass_button().text, "Confirm order")
	assert_false(_screen.pass_button().disabled)
	assert_null(BorderEffects.glow_color(_screen.face_of(_permanent("Chime"))), "Their sources take no click, so they do not glow.")


func test_dragging_a_trigger_down_and_confirming_makes_the_new_top_one_resolve_first() -> void:
	_reach_trigger_order()
	_presenter.is_hold_key_down = true
	var entries: Array[StackEntry] = _screen.trigger_entries()

	_drag_trigger(0, 1)

	assert_eq(_screen.trigger_order().order(), [1, 0] as Array[int])
	assert_eq(_screen.trigger_entries()[0].name_text(), "At the beginning of your upkeep, you gain 2 life.")
	assert_eq(_screen.trigger_entries(), [entries[1], entries[0]] as Array[StackEntry], "The same entries: nothing was rebuilt (A394).")
	assert_true(_presenter.snapshot().decision is OrderTriggersDecision, "Nothing is answered until it is confirmed.")
	assert_false(_screen.undo_button().disabled)
	assert_eq(_screen.pass_button().text, "Confirm order")
	assert_false(_screen.pass_button().disabled, "The new order can be confirmed at once.")

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_eq(_screen.trigger_entries().size(), 0)
	assert_null(_screen.trigger_list())
	assert_eq(_screen.stack_entries().size(), 2)
	assert_eq(_screen.stack_entries()[0].name_text(), "You gain 2 life.", "On top, so it resolves first.")
	assert_eq(_screen.stack_entries()[1].name_text(), "You gain 1 life.")
	assert_false(_screen.stack_entries()[0].is_dashed())
	assert_ne(_screen.stack_entries()[0].color(), StackColors.PLAIN, "On the stack, each has its color.")
	assert_ne(_screen.pass_button().text, "Confirm order")


func test_confirming_without_a_move_keeps_the_order_shown() -> void:
	_reach_trigger_order()
	_presenter.is_hold_key_down = true

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_eq(_screen.stack_entries()[0].name_text(), "You gain 1 life.")
	assert_eq(_screen.stack_entries()[1].name_text(), "You gain 2 life.")


func test_undo_takes_back_a_drag_of_a_trigger_before_anything_else_and_rebuilds_nothing() -> void:
	_reach_trigger_order()
	var entries: Array[StackEntry] = _screen.trigger_entries()
	assert_true(_screen.undo_button().disabled)
	_drag_trigger(1, 0)
	assert_eq(_screen.trigger_order().order(), [1, 0] as Array[int])
	assert_false(_screen.undo_button().disabled)

	_screen.undo()

	assert_eq(_screen.trigger_order().order(), [0, 1] as Array[int])
	assert_true(_presenter.snapshot().decision is OrderTriggersDecision)
	assert_eq(_screen.trigger_entries(), entries, "The entries ease back; none is made again.")
	assert_eq(_screen.trigger_entries()[0].name_text(), "At the beginning of your upkeep, you gain 1 life.")
	assert_true(_screen.undo_button().disabled, "One drag was one step.")
	assert_eq(_screen.pass_button().text, "Confirm order")


func test_a_trigger_let_go_where_it_started_or_right_clicked_is_no_move() -> void:
	_reach_trigger_order()
	var list: TriggerList = _screen.trigger_list()
	var top: Vector2 = Vector2(40, 20)

	list.press(0, top)
	list.drag_to(top + Vector2(0, 10))
	list.release()
	assert_eq(_screen.trigger_order().order(), [0, 1] as Array[int])
	assert_true(_screen.undo_button().disabled, "Nothing to take back.")

	list.press(0, top)
	list.drag_to(top + Vector2(0, list.entry_height() + 20.0))
	list.cancel()
	assert_eq(_screen.trigger_order().order(), [0, 1] as Array[int])
	assert_false(list.is_pressed())


func test_a_move_is_kept_when_the_same_decision_is_handed_out_again() -> void:
	_reach_trigger_order()
	_drag_trigger(1, 0)

	_screen.player_panel(HERO).step_button(MmTurn.Step.DRAW).pressed.emit()

	assert_true(_presenter.snapshot().decision is OrderTriggersDecision)
	assert_eq(_screen.trigger_order().order(), [1, 0] as Array[int], "Setting a stop made a new snapshot, not a new decision.")
	assert_eq(_screen.trigger_list().order(), [1, 0] as Array[int], "And the list made again shows it.")
	assert_eq(_screen.trigger_entries()[0].name_text(), "At the beginning of your upkeep, you gain 2 life.")


func test_a_real_press_drag_and_release_reorder_the_triggers_through_the_input_pipeline() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_reach_trigger_order(window)
	await wait_process_frames(3)
	var list: TriggerList = _screen.trigger_list()
	var entries: Array[StackEntry] = _screen.trigger_entries()
	var from: Vector2 = entries[0].get_global_rect().get_center()
	var to: Vector2 = entries[1].get_global_rect().get_center() + Vector2(0, 12)

	window.push_input(_mouse_motion(from))
	window.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true, from))
	assert_true(list.is_pressed(), "The press reached the entry.")
	assert_false(list.is_holding())
	window.push_input(_mouse_motion(from + Vector2(2, 0)))
	assert_false(list.is_holding(), "Not yet three pixels.")
	window.push_input(_mouse_motion(Vector2(200, to.y)))
	assert_true(list.is_holding(), "The mouse is followed wherever it goes, off the window too.")
	assert_almost_eq(entries[0].position.x, 0.0, 0.01, "It moves up and down only.")
	window.push_input(_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(200, to.y)))

	assert_false(list.is_pressed())
	assert_eq(_screen.trigger_order().order(), [1, 0] as Array[int])
	assert_false(_screen.drag_card().is_pressed(), "No card of the hand was touched.")

	# The entries ease to their new places over the next frames.
	await wait_seconds(0.4)
	assert_almost_eq(entries[1].get_global_rect().get_center().y, from.y, 1.0, "The other one is on top now.")
	window.push_input(_mouse_motion(from))
	window.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true, from))
	window.push_input(_mouse_motion(to))
	assert_true(list.is_holding())
	window.push_input(_mouse_button(MOUSE_BUTTON_RIGHT, true, to))
	assert_false(list.is_pressed(), "A right-click puts it back.")
	window.push_input(_mouse_button(MOUSE_BUTTON_LEFT, false, to))
	assert_eq(_screen.trigger_order().order(), [1, 0] as Array[int])
	await _leave_the_window(window)


func test_a_real_release_counts_where_the_button_came_up_even_with_no_move_reported_there() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_reach_trigger_order(window)
	await wait_process_frames(3)
	var entries: Array[StackEntry] = _screen.trigger_entries()
	var from: Vector2 = entries[0].get_global_rect().get_center()
	var to: Vector2 = entries[1].get_global_rect().get_center() + Vector2(0, 12)

	window.push_input(_mouse_motion(from))
	window.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true, from))
	window.push_input(_mouse_motion(from + Vector2(0, 5)))
	assert_true(_screen.trigger_list().is_holding())
	window.push_input(_mouse_button(MOUSE_BUTTON_LEFT, false, to))

	assert_eq(_screen.trigger_order().order(), [1, 0] as Array[int], "Events can arrive together in a slow frame; none is lost.")
	await _leave_the_window(window)


func test_a_real_hover_over_a_trigger_still_marks_its_source() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_reach_trigger_order(window)
	await wait_process_frames(3)
	var bell: Control = _screen.face_of(_permanent("Bell"))

	window.push_input(_mouse_motion(_screen.trigger_entries()[1].get_global_rect().get_center()))
	await wait_process_frames(2)

	assert_eq(BorderEffects.mark_color(bell), Color.WHITE)
	await _leave_the_window(window)
	assert_null(BorderEffects.mark_color(bell), "And leaving it takes the mark off.")


func test_hovering_a_trigger_marks_its_source_in_white_and_shows_it_in_full() -> void:
	_reach_trigger_order()
	var chime: Control = _screen.face_of(_permanent("Chime"))
	var bell: Control = _screen.face_of(_permanent("Bell"))

	_screen.trigger_entries()[1].hovered.emit(true)

	assert_eq(BorderEffects.mark_color(bell), Color.WHITE)
	assert_false(BorderEffects.is_mark_dashed(bell))
	assert_null(BorderEffects.mark_color(chime))
	assert_eq(_screen.info_panel().option_text(), "At the beginning of your upkeep, you gain 2 life.")

	_screen.trigger_entries()[1].hovered.emit(false)

	assert_null(BorderEffects.mark_color(bell))
	assert_eq(_screen.info_panel().option_text(), "")


func test_while_paused_triggers_cannot_be_dragged_or_confirmed() -> void:
	_reach_trigger_order()
	_screen.press_key(KEY_ESCAPE)

	_drag_trigger(0, 1)
	_screen.pass_priority()

	assert_eq(_screen.trigger_order().order(), [0, 1] as Array[int])
	assert_eq(_screen.trigger_list().order(), [0, 1] as Array[int], "The list goes back to the order that stands.")
	assert_true(_presenter.snapshot().decision is OrderTriggersDecision)
	assert_eq(_screen.info_panel().error_text(), "")


func test_triggers_that_are_all_alike_are_ordered_without_asking() -> void:
	var chime: MmCardDefinition = _chime("Chime", 1)
	_open([chime])
	_cast("Chime")
	_cast("Chime")
	_presenter.is_hold_key_down = true

	_pass_until(func() -> bool: return _presenter.snapshot().view.stack.size() == 2)

	assert_true(_presenter.snapshot().decision is PriorityDecision, "The Hero was never asked for an order (A344).")
	assert_eq(_screen.trigger_entries().size(), 0)
	assert_eq(_screen.stack_entries()[0].name_text(), "You gain 1 life.")


# --- Choosing a replacement effect -------------------------------------------------------

func test_the_choice_window_is_there_only_while_the_hero_is_asked() -> void:
	_open([_free_bear(), Scenario.free_shield("Ward", 1), Scenario.free_shield("Aegis", 2), Scenario.free_shock("Zap", 2)])
	assert_false(_screen.choice_window().visible)

	_reach_choice()

	var window: ZoneWindow = _screen.choice_window()
	assert_true(window.visible)
	assert_null(window.close_button(), "It cannot be closed while the choice is asked.")
	assert_eq(window.title_text(), "2 damage to Bear: which applies first?")
	assert_true(EncounterLayout.regions(SCREEN)["battlefield"].encloses(Rect2(window.position, window.size)))
	assert_eq(_screen.info_panel().prompt_text(), "Choose which applies first")
	var entries: Array[ZoneEntry] = _screen.choice_entries()
	assert_eq(entries.size(), 2)
	assert_eq(entries[0].name_text(), "Ward")
	assert_eq(entries[0].detail_text(), "Prevent the next 1 damage that would be dealt to Bear this turn.")
	assert_eq(entries[1].name_text(), "Aegis")
	assert_eq(entries[1].detail_text(), "Prevent the next 2 damage that would be dealt to Bear this turn.")


func test_the_choice_window_is_kept_inside_the_battlefield() -> void:
	_open([_free_bear(), Scenario.free_shield("Ward", 1), Scenario.free_shield("Aegis", 2), Scenario.free_shock("Zap", 2)])
	_reach_choice()
	var window: ZoneWindow = _screen.choice_window()

	assert_eq(window.bounds, _screen.stack_window().bounds)
	assert_true(window.bounds.has_area())
	assert_true(window.bounds.encloses(Rect2(window.position, window.size)))


func test_clicking_an_entry_chooses_that_effect_and_the_window_goes() -> void:
	_open([_free_bear(), Scenario.free_shield("Ward", 1), Scenario.free_shield("Aegis", 2), Scenario.free_shock("Zap", 2)])
	_reach_choice()
	var bear: int = _permanent("Bear")

	_screen.choice_catcher(1).clicked.emit()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseReplacementEffectDecision)
	assert_false(_screen.choice_window().visible)
	assert_eq(_screen.choice_entries().size(), 0)
	assert_eq(_view_of(bear).damage_marked, 0, "The Aegis prevented both.")
	var left: Array[int] = []
	for shield: ActiveReplacementEffect in _view_of(bear).replacement_effects:
		left.append(shield.remaining)
	assert_eq(left, [1] as Array[int], "The Ward was never used.")


func test_while_paused_no_effect_can_be_chosen() -> void:
	_open([_free_bear(), Scenario.free_shield("Ward", 1), Scenario.free_shield("Aegis", 2), Scenario.free_shock("Zap", 2)])
	_reach_choice()
	_screen.press_key(KEY_ESCAPE)

	_screen.choice_catcher(0).clicked.emit()

	assert_true(_presenter.snapshot().decision is ChooseReplacementEffectDecision)
	assert_eq(_screen.info_panel().error_text(), "")


func test_hovering_an_entry_shows_it_in_full_and_marks_a_source_on_the_battlefield() -> void:
	# The shields differ, or the engine would not need to ask which goes first.
	_open([_free_bear(), Scenario.healer("Healer"), Scenario.free_shield("Ward", 2), Scenario.free_shock("Zap", 2)])
	_cast("Bear")
	_cast("Healer")
	var bear: int = _permanent("Bear")
	var healer: int = _permanent("Healer")
	_pass_until(func() -> bool:
		var view: MmPlayerView = _presenter.snapshot().view
		return view.game_turn >= 3 and view.step == MmTurn.Step.PRECOMBAT_MAIN and _presenter.snapshot().decision is PriorityDecision)
	_click(healer)
	_choose(MmReference.to_object(bear))
	_cast("Ward", MmReference.to_object(bear))
	_cast("Zap", MmReference.to_object(bear))
	_pass_until(func() -> bool: return _presenter.snapshot().decision is ChooseReplacementEffectDecision)
	assert_eq(_screen.choice_entries()[0].name_text(), "Healer")

	_screen.choice_catcher(0).mouse_entered.emit()

	assert_eq(BorderEffects.mark_color(_screen.face_of(healer)), Color.WHITE)
	assert_false(BorderEffects.is_mark_dashed(_screen.face_of(healer)))
	assert_eq(_screen.info_panel().option_text(), "Healer — Prevent the next 1 damage that would be dealt to Bear this turn.")

	_screen.choice_catcher(0).mouse_exited.emit()

	assert_null(BorderEffects.mark_color(_screen.face_of(healer)))
	assert_eq(_screen.info_panel().option_text(), "")
	_screen.choice_catcher(1).mouse_entered.emit()
	assert_null(BorderEffects.mark_color(_screen.face_of(healer)), "The Ward is in the graveyard, so nothing is marked.")
	assert_eq(_screen.info_panel().option_text(), "Ward — Prevent the next 2 damage that would be dealt to Bear this turn.")


# --- Helpers ----------------------------------------------------------------------------

## Opens a screen where the Hero's deck cycles through [param cards], the Villain does
## nothing, and the Hero has kept and reached their first main phase.
func _open(cards: Array[MmCardDefinition], parent: Node = null) -> void:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	if parent == null:
		add_child_autofree(_screen)
	else:
		parent.add_child(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40)), DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_pass_until(func() -> bool: return _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN)


## The Hero controls a Chime and a Bell, whose upkeep triggers differ, and is asked to
## order them.
func _reach_trigger_order(parent: Node = null) -> void:
	_open([_chime("Chime", 1), _chime("Bell", 2)], parent)
	_cast("Chime")
	_cast("Bell")
	_pass_until(func() -> bool: return _presenter.snapshot().decision is OrderTriggersDecision)


## Drags the trigger at place [param from] and lets it go at place [param to], as the
## mouse would: pressed on its entry, moved, and released.
func _drag_trigger(from: int, to: int) -> void:
	var list: TriggerList = _screen.trigger_list()
	var height: float = list.entry_height()
	var grabbed: Vector2 = Vector2(40, EncounterLayout.trigger_slot(from, height) + height / 2.0)
	list.press(list.order()[from], grabbed)
	list.drag_to(Vector2(40, EncounterLayout.trigger_slot(to, height) + height / 2.0))
	list.release()


## Takes the cursor off the Stack Window and lets the Stack Mark it left be freed, so the
## test does not end with a mark taken off a face but not yet gone.
func _leave_the_window(window: SubViewport) -> void:
	window.push_input(_mouse_motion(Vector2(700, 300)))
	await wait_process_frames(3)


func _mouse_motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


func _mouse_button(button: MouseButton, is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = button
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click


## The Hero's Bear has a Ward and an Aegis on it and is about to be dealt 2 damage.
func _reach_choice() -> void:
	_cast("Bear")
	var bear: MmReference = MmReference.to_object(_permanent("Bear"))
	_cast("Ward", bear)
	_cast("Aegis", bear)
	_cast("Zap", bear)
	_pass_until(func() -> bool: return _presenter.snapshot().decision is ChooseReplacementEffectDecision)


## An artifact costing {0}: "At the beginning of your upkeep, you gain [param life] life."
func _chime(card_name: String, life: int) -> MmCardDefinition:
	return Scenario.artifact(card_name, [Scenario.triggered(Scenario.at_step(MmTurn.Step.UPKEEP, MmTrigger.Whose.YOU),
		[Scenario.gain_life(life, Scenario.you())])])


## An artifact costing {0}: "{T}: This artifact deals 1 damage to any target."
func _wand() -> MmCardDefinition:
	var ability: ActivatedAbility = ActivatedAbility.new()
	ability.costs = [TapCost.new()]
	ability.targets = [Scenario.any_target()]
	ability.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
	return Scenario.artifact("Wand", [ability])


func _free_bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))


## Casts the card named [param card_name] from the Hero's hand, at [param target] if given.
## Unless the hold key is down, it resolves at once.
func _cast(card_name: String, target: MmReference = null) -> void:
	_do(CastSpellAction, card_name)
	if target != null:
		_choose(target)
	_presenter.wait_until_idle()


func _choose(target: MmReference) -> void:
	var decision: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	assert_not_null(decision, "No target is being asked for.")
	if decision == null:
		return
	for index: int in decision.candidates.size():
		if decision.candidates[index].equals(target):
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("%s cannot be targeted." % target.describe())


func _do(kind: Script, card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	assert_not_null(priority, "The Hero does not have priority.")
	if priority == null:
		return
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if is_instance_of(action, kind) and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			return
	fail_test("No %s action for %s." % [kind.resource_path.get_file(), card_name])


func _click(object_id: int) -> void:
	var catcher: ClickCatcher = _screen.click_catcher(object_id)
	assert_not_null(catcher, "Nothing takes a click on object %d." % object_id)
	if catcher != null:
		catcher.clicked.emit()


func _permanent(card_name: String) -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			return permanent.id
	return -1


func _view_of(object_id: int) -> MmObjectView:
	for seen: MmObjectView in _presenter.snapshot().visible_objects():
		if seen.id == object_id:
			return seen
	return null


## Passes priority until [param is_there] says to stop, discarding down when asked.
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
