extends GutTest
## A player's panel is built once and then only changed: each snapshot alters what it shows
## differently and leaves the rest of its thirty-odd buttons alone, because building them
## took six to nine milliseconds a panel on every redraw.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const BOX: Rect2 = Rect2(10, 10, 300, 520)
const UPKEEP: MmTurn.Step = MmTurn.Step.UPKEEP
const MAIN: MmTurn.Step = MmTurn.Step.PRECOMBAT_MAIN

var _stops: StepStops
var _snapshot: EncounterSnapshot
var _pressed: Array = []


func before_each() -> void:
	_pressed.clear()
	_stops = StepStops.new()
	_snapshot = EncounterSnapshot.new()
	_snapshot.view = MmPlayerView.new()
	_snapshot.view.viewer_id = HERO
	_snapshot.view.life_totals = {HERO: 20, VILLAIN: 18}
	_snapshot.view.mana_pools = {HERO: [], VILLAIN: []}
	_snapshot.view.active_player_id = HERO
	_snapshot.view.priority_player_id = HERO
	_snapshot.view.step = MAIN
	_snapshot.decision = PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])


func after_each() -> void:
	await wait_process_frames(2)


func test_a_panel_keeps_its_buttons_from_one_snapshot_to_the_next() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var kept: Array[Node] = panel.get_children()
	var step: Button = panel.step_button(UPKEEP)
	var style: StyleBox = step.get_theme_stylebox("normal")
	var emblem_style: StyleBox = panel.emblems_button().get_theme_stylebox("normal")

	_snapshot.view.life_totals[HERO] = 17
	_snapshot.view.step = MmTurn.Step.END
	_snapshot.view.priority_player_id = VILLAIN
	_snapshot.is_villain_thinking = true
	_show(panel, HERO)

	assert_eq(panel.get_children(), kept, "Nothing was rebuilt.")
	assert_eq(panel.step_button(UPKEEP), step)
	assert_eq(step.get_theme_stylebox("normal"), style, "A step that looks the same is not even restyled.")
	assert_eq(panel.emblems_button().get_theme_stylebox("normal"), emblem_style)
	assert_eq(panel.life_text(), "17")


func test_a_panel_of_another_size_is_built_afresh() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var step: Button = panel.step_button(UPKEEP)

	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, Rect2(40, 20, 300, 480), true, true)

	assert_ne(panel.step_button(UPKEEP), step)
	assert_true(step.is_queued_for_deletion())
	assert_eq(panel.position, Vector2(40, 20))
	assert_eq(panel.size, Vector2(300, 480))
	assert_eq(panel.life_text(), "20", "And shows the same things.")
	assert_true(panel.shows_now(MAIN))
	var moved: Button = panel.step_button(UPKEEP)
	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, Rect2(0, 0, 300, 480), true, true)
	assert_eq(panel.step_button(UPKEEP), moved, "Only moved, it is kept.")
	assert_eq(panel.position, Vector2.ZERO)


func test_it_shows_life_and_who_has_priority() -> void:
	var hero: PlayerPanel = _panel(HERO)
	var villain: PlayerPanel = _panel(VILLAIN)

	assert_eq(hero.life_text(), "20")
	assert_eq(villain.life_text(), "18")
	assert_true(_outline(hero).visible, "The Hero has priority.")
	assert_false(_outline(villain).visible)
	_snapshot.view.priority_player_id = VILLAIN
	_snapshot.view.life_totals[VILLAIN] = 0
	_show(hero, HERO)
	_show(villain, VILLAIN)
	assert_false(_outline(hero).visible)
	assert_true(_outline(villain).visible)
	assert_eq(villain.life_text(), "0")


func test_the_priority_outline_eases_from_one_panel_to_the_other_and_a_redraw_leaves_it_be() -> void:
	var hero: PlayerPanel = _panel(HERO)
	var villain: PlayerPanel = _panel(VILLAIN)
	assert_eq(_outline(hero).modulate.a, 1.0, "A panel just built shows it at once.")
	hero.glow_seconds = 0.2
	villain.glow_seconds = 0.2

	_snapshot.view.priority_player_id = VILLAIN
	_show(hero, HERO)
	_show(villain, VILLAIN)

	assert_false(Easing.is_shown(_outline(hero)), "Gone from the Hero at once.")
	assert_true(_outline(hero).visible, "But drawn while it fades.")
	assert_eq(_outline(villain).modulate.a, 0.0, "The Villain's eases in.")
	assert_true(_outline(villain).visible)
	await wait_seconds(0.3)
	assert_false(_outline(hero).visible)
	assert_eq(_outline(villain).modulate.a, 1.0)

	_show(villain, VILLAIN)

	assert_eq(_outline(villain).modulate.a, 1.0, "Still the Villain's: left as it is.")


func test_the_step_it_is_now_is_marked_on_the_active_players_panel_only() -> void:
	var hero: PlayerPanel = _panel(HERO)
	var villain: PlayerPanel = _panel(VILLAIN)

	assert_true(hero.shows_now(MAIN))
	assert_false(hero.shows_now(UPKEEP))
	assert_false(villain.shows_now(MAIN))
	assert_eq((hero.step_button(MAIN).get_theme_stylebox("normal") as StyleBoxFlat).border_color, PlayerPanel.NOW_COLOR)
	assert_eq((hero.step_button(MAIN).get_theme_stylebox("normal") as StyleBoxFlat).border_width_left, 3)
	assert_eq((hero.step_button(UPKEEP).get_theme_stylebox("normal") as StyleBoxFlat).border_width_left, 0)

	_snapshot.view.step = UPKEEP
	_snapshot.view.active_player_id = VILLAIN
	_show(hero, HERO)
	_show(villain, VILLAIN)

	assert_false(hero.shows_now(MAIN), "The mark moved off the step it was")
	assert_eq((hero.step_button(MAIN).get_theme_stylebox("normal") as StyleBoxFlat).border_width_left, 0)
	assert_true(villain.shows_now(UPKEEP), "and onto the Villain's upkeep.")
	assert_false(hero.shows_now(UPKEEP))


func test_a_stop_turns_its_step_green_and_back() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var plain: Color = (panel.step_button(UPKEEP).get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	var had: bool = panel.shows_stop(UPKEEP)

	_stops.toggle(HERO, UPKEEP)
	_show(panel, HERO)

	assert_eq(panel.shows_stop(UPKEEP), not had)
	assert_ne((panel.step_button(UPKEEP).get_theme_stylebox("normal") as StyleBoxFlat).bg_color, plain)
	var colors: Array[Color] = [PlayerPanel.STOP_COLOR, PlayerPanel.PLAIN_COLOR]
	assert_true(colors.has(plain))
	assert_eq((panel.step_button(UPKEEP).get_theme_stylebox("hover") as StyleBoxFlat).bg_color,
			(PlayerPanel.PLAIN_COLOR if had else PlayerPanel.STOP_COLOR).lightened(0.18))
	assert_eq((panel.step_button(UPKEEP).get_theme_stylebox("disabled") as StyleBoxFlat).bg_color, Color("#2c323c"))
	_stops.toggle(HERO, UPKEEP)
	_show(panel, HERO)
	assert_eq((panel.step_button(UPKEEP).get_theme_stylebox("normal") as StyleBoxFlat).bg_color, plain)
	assert_eq(panel.shows_stop(UPKEEP), had)

	panel.stop_toggled.connect(func(step: MmTurn.Step) -> void: _pressed.append(step))
	panel.step_button(UPKEEP).pressed.emit()
	assert_eq(_pressed, [UPKEEP])
	assert_true(panel.step_button(MmTurn.Step.UNTAP).disabled, "Untap never holds a stop.")
	assert_false(panel.step_button(UPKEEP).disabled)


func test_mana_buttons_show_the_pool_and_can_be_pressed_only_while_that_color_pays() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var red: Button = panel.mana_button(MmMana.Type.RED)
	panel.mana_pressed.connect(func(answer: int) -> void: _pressed.append(answer))
	assert_eq(panel.mana_count_text(MmMana.Type.RED), "(0)")
	assert_almost_eq(red.modulate.a, 0.55, 0.001, "Dim with none.")
	assert_true(red.disabled)
	red.pressed.emit()
	assert_eq(_pressed, [], "Nothing to pay with.")

	_snapshot.view.mana_pools[HERO] = [MmMana.new(MmMana.Type.RED, 0), MmMana.new(MmMana.Type.RED, 0), MmMana.new(MmMana.Type.GREEN, 0)]
	var paying: DecisionClicks = DecisionClicks.new()
	paying.pool_answers[MmMana.Type.RED] = 4
	panel.show_snapshot(_snapshot, paying, _stops, BOX, true, true)

	assert_eq(panel.mana_button(MmMana.Type.RED), red)
	assert_eq(panel.mana_count_text(MmMana.Type.RED), "(2)")
	assert_eq(panel.mana_count_text(MmMana.Type.GREEN), "(1)")
	assert_eq(red.modulate.a, 1.0)
	assert_false(red.disabled)
	assert_eq(BorderEffects.glow_color(red), DecisionClicks.color_of(DecisionClicks.Kind.MANA))
	assert_null(BorderEffects.glow_color(panel.mana_button(MmMana.Type.GREEN)), "Green cannot pay for this.")
	assert_true(panel.mana_button(MmMana.Type.GREEN).disabled)
	red.pressed.emit()
	assert_eq(_pressed, [4])
	var glow: Node = red.get_node(BorderEffects.GLOW)
	panel.show_snapshot(_snapshot, paying, _stops, BOX, true, true)
	assert_eq(red.get_node(BorderEffects.GLOW), glow, "A button that still glows keeps its Glow.")

	_show(panel, HERO)
	assert_null(BorderEffects.glow_color(red), "Paying is over.")
	assert_true(red.disabled)
	red.pressed.emit()
	assert_eq(_pressed, [4])


func test_pool_mana_about_to_be_spent_glows_without_taking_a_press() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var red: Button = panel.mana_button(MmMana.Type.RED)
	var green: Button = panel.mana_button(MmMana.Type.GREEN)
	panel.mana_pressed.connect(func(answer: int) -> void: _pressed.append(answer))
	_snapshot.view.mana_pools[HERO] = [MmMana.new(MmMana.Type.RED, 0), MmMana.new(MmMana.Type.GREEN, 0)]
	_show(panel, HERO)

	panel.mark_pool([MmMana.Type.RED] as Array[MmMana.Type])

	assert_eq(BorderEffects.glow_color(red), DecisionClicks.color_of(DecisionClicks.Kind.MANA), "The Tap Preview marks it.")
	assert_null(BorderEffects.glow_color(green))
	assert_true(red.disabled, "It is shown, not offered.")
	red.pressed.emit()
	assert_eq(_pressed, [])
	var glow: Node = red.get_node(BorderEffects.GLOW)
	panel.mark_pool([MmMana.Type.RED, MmMana.Type.GREEN] as Array[MmMana.Type])
	assert_eq(red.get_node(BorderEffects.GLOW), glow, "A button that still glows keeps its Glow.")
	assert_not_null(BorderEffects.glow_color(green))

	panel.mark_pool([] as Array[MmMana.Type])
	assert_null(BorderEffects.glow_color(red))
	assert_null(BorderEffects.glow_color(green))

	panel.mark_pool([MmMana.Type.RED] as Array[MmMana.Type])
	_show(panel, HERO)
	assert_null(BorderEffects.glow_color(red), "The next snapshot says what glows.")
	var paying: DecisionClicks = DecisionClicks.of_payment(_plan([], [MmMana.Type.GREEN]))
	panel.show_snapshot(_snapshot, paying, _stops, BOX, true, true)
	assert_not_null(BorderEffects.glow_color(green), "What Auto-tap has still to spend glows while it pays.")
	assert_true(green.disabled)
	var villain: PlayerPanel = _panel(VILLAIN)
	villain.show_snapshot(_snapshot, paying, _stops, BOX, false, false)
	assert_null(BorderEffects.glow_color(villain.mana_button(MmMana.Type.GREEN)), "Only the Hero's pool is marked.")


func test_the_villains_mana_buttons_are_never_pressed() -> void:
	var paying: DecisionClicks = DecisionClicks.new()
	paying.pool_answers[MmMana.Type.RED] = 4
	var panel: PlayerPanel = _panel(VILLAIN)
	panel.mana_pressed.connect(func(answer: int) -> void: _pressed.append(answer))

	panel.show_snapshot(_snapshot, paying, _stops, BOX, false, false)

	assert_true(panel.mana_button(MmMana.Type.RED).disabled)
	assert_null(BorderEffects.glow_color(panel.mana_button(MmMana.Type.RED)))
	panel.mana_button(MmMana.Type.RED).pressed.emit()
	assert_eq(_pressed, [])


func test_the_emblems_button_counts_emblems_and_turns_gold_with_any() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var button: Button = panel.emblems_button()
	assert_eq(button.text, "⛨  Emblems (0)")
	assert_true(button.disabled)
	var gray: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(gray.border_color, Color("#6b7280"))

	_snapshot.view.command = [_emblem(HERO), _emblem(VILLAIN), _emblem(HERO)]
	_show(panel, HERO)

	assert_eq(button.text, "⛨  Emblems (2)")
	assert_false(button.disabled)
	var gold: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(gold.border_color, PlayerPanel.GOLD)
	assert_eq(gold.bg_color, Color(PlayerPanel.GOLD, 0.25))
	assert_eq((button.get_theme_stylebox("hover") as StyleBoxFlat).bg_color, Color(PlayerPanel.GOLD, 0.45))
	assert_eq(gold.border_width_left, 1)
	_snapshot.view.command = [_emblem(HERO)]
	_show(panel, HERO)
	assert_eq(button.text, "⛨  Emblems (1)")
	assert_eq(button.get_theme_stylebox("normal"), gold, "Still gold: not restyled.")
	_snapshot.view.command = []
	_show(panel, HERO)
	assert_eq((button.get_theme_stylebox("normal") as StyleBoxFlat).border_color, Color("#6b7280"))
	assert_true(button.disabled)
	panel.emblems_pressed.connect(func() -> void: _pressed.append("emblems"))
	button.pressed.emit()
	assert_eq(_pressed, ["emblems"])


func test_the_portrait_glows_and_is_clicked_while_its_player_can_be_chosen() -> void:
	var panel: PlayerPanel = _panel(VILLAIN)
	var portrait: Panel = panel.portrait()
	panel.player_clicked.connect(func(answer: int) -> void: _pressed.append(answer))
	assert_null(panel.click_catcher())
	assert_null(BorderEffects.glow_color(portrait))

	var target: DecisionClicks = DecisionClicks.new()
	target.players[VILLAIN] = DecisionClicks.Kind.TARGET
	target.player_answers[VILLAIN] = 2
	panel.show_snapshot(_snapshot, target, _stops, BOX, false, false)

	assert_eq(panel.portrait(), portrait, "The same portrait.")
	assert_eq(BorderEffects.glow_color(portrait), DecisionClicks.color_of(DecisionClicks.Kind.TARGET))
	panel.click_catcher().clicked.emit()
	assert_eq(_pressed, [2])
	target.player_answers[VILLAIN] = 5
	portrait.modulate = ClickCatcher.BRIGHT
	panel.show_snapshot(_snapshot, target, _stops, BOX, false, false)
	assert_eq(portrait.get_child_count(), 2, "One Glow and one catcher, not one more of each.")
	assert_eq(portrait.modulate, Color.WHITE, "A portrait that was under the cursor is not left bright.")
	panel.click_catcher().clicked.emit()
	assert_eq(_pressed, [2, 5], "The click answers what the new decision asks.")

	_show(panel, VILLAIN)
	assert_null(panel.click_catcher())
	assert_null(BorderEffects.glow_color(portrait))


func test_what_was_drawn_on_the_portrait_from_outside_is_cleared_by_the_next_snapshot() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var stepper: Control = Control.new()
	panel.portrait().add_child(stepper)

	_show(panel, HERO)

	assert_eq(panel.portrait().get_child_count(), 0)
	assert_true(stepper.is_queued_for_deletion())


func test_the_heros_controls_follow_the_snapshot() -> void:
	var panel: PlayerPanel = _panel(HERO)
	assert_eq(panel.pass_button().text, "Pass [SPACE]")
	assert_false(panel.pass_button().disabled)
	assert_true(panel.undo_button().disabled, "Nothing to undo.")
	assert_eq(panel.yield_button().text, "☑  Yield Turn")
	assert_true(panel.yield_button().flat)

	_snapshot.can_undo = true
	_snapshot.decision = KeepOrMulliganDecision.new(HERO, 0, 0)
	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, true, false)
	assert_false(panel.undo_button().disabled)
	assert_true(panel.pass_button().disabled, "Keeping a hand is not priority.")
	assert_eq(panel.yield_button().text, "☐  Yield Turn")

	_snapshot.is_villain_thinking = true
	_show(panel, HERO)
	assert_true(panel.undo_button().disabled, "Nothing is undone while the Villain thinks.")
	for control: String in ["pass", "undo", "yield"]:
		panel.connect(control + ("_toggled" if control == "yield" else "_pressed"), func() -> void: _pressed.append(control))
	panel.pass_button().pressed.emit()
	panel.undo_button().pressed.emit()
	panel.yield_button().pressed.emit()
	assert_eq(_pressed, ["pass", "undo", "yield"])


func test_the_confirm_button_is_a_pass_button_again_at_the_next_snapshot() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var pass_button: Button = panel.pass_button()

	panel.show_confirm("Attack with 2", false, true)
	assert_eq(pass_button.text, "Attack with 2")
	assert_true(pass_button.disabled)
	assert_eq(pass_button.get_theme_font_size("font_size"), 19)
	assert_false(panel.undo_button().disabled, "There is a click to take back.")
	_show(panel, HERO)

	assert_eq(panel.pass_button(), pass_button)
	assert_eq(pass_button.text, "Pass [SPACE]")
	assert_eq(pass_button.get_theme_font_size("font_size"), 21)
	assert_false(pass_button.disabled)
	assert_true(panel.undo_button().disabled)


func test_the_villains_panel_says_when_the_villain_is_thinking_and_has_no_controls() -> void:
	var panel: PlayerPanel = _panel(VILLAIN)
	assert_null(panel.pass_button())
	assert_null(panel.undo_button())
	assert_null(panel.yield_button())
	assert_eq(panel.thinking_text(), "")
	panel.show_confirm("Attack with 2", true, true)

	_snapshot.is_villain_thinking = true
	_show(panel, VILLAIN)
	assert_eq(panel.thinking_text(), PlayerPanel.THINKING)
	_snapshot.is_villain_thinking = false
	_show(panel, VILLAIN)
	assert_eq(panel.thinking_text(), "")
	assert_eq(_panel(HERO).thinking_text(), "", "The Hero's panel never says it.")


func test_a_panel_that_changes_sides_is_built_afresh() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var step: Button = panel.step_button(UPKEEP)

	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, false, false)

	assert_ne(panel.step_button(UPKEEP), step)
	assert_null(panel.pass_button())


func test_a_panel_is_headed_with_its_players_name_in_capitals() -> void:
	var panel: PlayerPanel = _panel(VILLAIN)
	assert_eq(panel.name_text(), "VILLAIN")

	_snapshot.names = PlayerNames.new("Jackson", "Mishra")
	_snapshot.is_villain_thinking = true
	_show(panel, VILLAIN)

	assert_eq(panel.name_text(), "MISHRA")
	assert_eq(panel.thinking_text(), "Mishra is thinking…")
	var mine: PlayerPanel = _panel(HERO)
	_show(mine, HERO)
	assert_eq(mine.name_text(), "JACKSON")


func _panel(player_id: int) -> PlayerPanel:
	var panel: PlayerPanel = PlayerPanel.new(player_id, "HERO" if player_id == HERO else "VILLAIN")
	add_child_autofree(panel)
	_show(panel, player_id)
	return panel


func _plan(source_ids: Array[int], pool_types: Array[MmMana.Type]) -> PaymentPlan:
	var plan: PaymentPlan = PaymentPlan.new()
	plan.source_ids = source_ids
	plan.pool_types = pool_types
	return plan


func _show(panel: PlayerPanel, player_id: int) -> void:
	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, player_id == HERO, player_id == HERO)


## The border that says the panel's player has priority.
func _outline(panel: PlayerPanel) -> Control:
	return panel.get_child(1) as Control


func _emblem(player_id: int) -> MmObjectView:
	var emblem: MmObjectView = MmObjectView.new()
	emblem.controller_id = player_id
	return emblem
