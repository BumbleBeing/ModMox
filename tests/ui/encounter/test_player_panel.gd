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


func test_the_priority_glow_is_a_pale_glow_round_the_whole_panel() -> void:
	var hero: PlayerPanel = _panel(HERO)

	assert_eq(BorderEffects.glow_color(hero.priority_glow()), PlayerPanel.NOW_COLOR)
	assert_eq(hero.priority_glow().size, BOX.size, "Round the panel, not the portrait (A478).")
	assert_null(BorderEffects.glow_color(hero.portrait()), "The portrait glows only when its player can be chosen.")


func test_a_step_with_a_stop_that_is_the_step_it_is_now_is_green_and_glows() -> void:
	var hero: PlayerPanel = _panel(HERO)

	assert_true(hero.shows_stop(MAIN))
	assert_eq(PlayerPanel.tint_of(hero.step_button(MAIN)), PlayerPanel.STOP_COLOR)
	assert_eq(BorderEffects.glow_color(hero.step_button(MAIN)), PlayerPanel.NOW_COLOR)


func test_the_hero_is_urza_and_the_villain_charmed_stray_drawn_pixel_for_pixel() -> void:
	var hero: PlayerPanel = _panel(HERO)
	var villain: PlayerPanel = _panel(VILLAIN)

	assert_eq(hero.portrait_texture().resource_path, "res://ui/sprites/portraits/urza_academy_headmaster.png")
	assert_eq(villain.portrait_texture().resource_path, "res://ui/sprites/portraits/charmed_stray.png",
		"The placeholder, for testing.")
	var picture: TextureRect = _picture_of(hero)
	assert_eq(picture.texture, hero.portrait_texture())
	assert_eq(picture.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(picture.size, hero.portrait().size)
	assert_eq(picture.global_position, hero.portrait().global_position,
		"What glows and is clicked lies over the picture.")


func test_a_panel_given_its_players_own_portrait_draws_it_in_place_of_the_placeholder() -> void:
	var stray: Texture2D = load("res://ui/sprites/portraits/charmed_stray.png")
	var villain: PlayerPanel = PlayerPanel.new(VILLAIN, "VILLAIN")
	villain.portrait_override = stray
	add_child_autofree(villain)
	villain.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, false, false)

	assert_eq(villain.portrait_texture(), stray)


func test_a_hurt_player_shows_their_pain_portrait_for_the_hold_then_their_portrait_again() -> void:
	var hero: PlayerPanel = _panel(HERO)
	var portrait: Texture2D = hero.portrait_texture()

	hero.wince(0.5)

	assert_true(hero.is_wincing())
	assert_eq(hero.portrait_texture().resource_path, "res://ui/sprites/portraits/urza_academy_headmaster_pain.png")
	assert_eq(_picture_of(hero).texture, hero.portrait_texture(), "The picture drawn is the Pain Portrait.")
	hero.advance(0.4)
	assert_true(hero.is_wincing())
	hero.advance(0.2)
	assert_false(hero.is_wincing())
	assert_eq(hero.portrait_texture(), portrait)
	assert_eq(_picture_of(hero).texture, portrait)


func test_hurt_again_while_wincing_the_longer_hold_wins() -> void:
	var hero: PlayerPanel = _panel(HERO)

	hero.wince(1.3)
	hero.advance(0.2)
	hero.wince(0.3)
	hero.advance(0.5)
	assert_true(hero.is_wincing(), "A ping does not cut a big hit's wince short.")
	hero.advance(0.7)
	assert_false(hero.is_wincing())

	hero.wince(0.3)
	hero.advance(0.2)
	hero.wince(0.8)
	hero.advance(0.5)
	assert_true(hero.is_wincing(), "A big hit lengthens a short wince.")


func test_a_player_who_lost_keeps_wincing() -> void:
	var villain: PlayerPanel = _panel(VILLAIN)

	villain.wince(0.3, true)
	villain.advance(60.0)

	assert_true(villain.is_wincing())


func test_a_wince_outlasts_a_rebuilt_panel() -> void:
	var hero: PlayerPanel = _panel(HERO)
	hero.wince(0.5)

	hero.show_snapshot(_snapshot, DecisionClicks.new(), _stops, Rect2(BOX.position, BOX.size + Vector2(0, 40)), true, false)

	assert_eq(_picture_of(hero).texture, hero.portrait_texture())
	assert_true(hero.portrait_texture().resource_path.ends_with("_pain.png"))


func test_a_panel_not_told_to_breathe_keeps_its_portrait_at_rest() -> void:
	var hero: PlayerPanel = _panel(HERO)

	hero.advance(1.0)

	assert_eq(_picture_of(hero).size, hero.portrait().size)


func test_a_breathing_portrait_grows_and_shrinks_inside_its_square() -> void:
	var hero: PlayerPanel = _panel(HERO)
	hero.start_breathing(7)
	var sizes: Array[float] = []
	for tick: int in 40:
		hero.advance(0.1)
		sizes.append(_picture_of(hero).size.y)

	assert_gt(sizes.max(), hero.portrait().size.y, "It grows at the top of a breath.")
	assert_eq(sizes.min(), hero.portrait().size.y, "It rests at its own size.")
	assert_true(hero.breathing_portrait().clip_contents, "Cropped to its square.")


func test_a_hurt_player_is_winded_until_their_pain_portrait_is_over() -> void:
	var hero: PlayerPanel = _panel(HERO)
	hero.start_breathing(7)
	hero.advance(0.5)

	hero.wince(1.0)
	hero.advance(0.2)
	assert_true(hero.breath().is_winded())
	assert_eq(_picture_of(hero).size, hero.portrait().size, "Sunk to the bottom of the breath.")
	hero.advance(0.9)
	assert_false(hero.breath().is_winded(), "Breathing again once the wince is over.")
	assert_almost_eq(hero.breath().phase, 0.0, 0.1, "From the start of a breath.")


func test_a_player_who_lost_stops_breathing() -> void:
	var villain: PlayerPanel = _panel(VILLAIN)
	villain.start_breathing(7)
	_snapshot.view.is_over = true
	_snapshot.view.winner_id = HERO
	_show(villain, VILLAIN)

	villain.advance(3.0)

	assert_true(villain.breath().is_stopped())
	assert_eq(_picture_of(villain).size, villain.portrait().size)


func test_breathing_is_faster_at_low_life() -> void:
	var hero: PlayerPanel = _panel(HERO)
	hero.start_breathing(7)
	var calm: float = hero.breath().phase
	hero.advance(0.2)
	var calm_step: float = fposmod(hero.breath().phase - calm, 1.0)
	_snapshot.view.life_totals = {HERO: 1, VILLAIN: 18}
	_show(hero, HERO)
	var low: float = hero.breath().phase
	hero.advance(0.2)

	assert_almost_eq(fposmod(hero.breath().phase - low, 1.0), calm_step * 2.0, 0.001)


func test_a_breathing_portrait_blinks_now_and_then() -> void:
	var hero: PlayerPanel = _panel(HERO)
	var portrait: Texture2D = hero.portrait_texture()
	hero.start_breathing(7)
	var shown: Array[String] = []
	for tick: int in 800:
		hero.advance(0.01)
		var path: String = hero.portrait_texture().resource_path
		if not shown.has(path):
			shown.append(path)

	assert_has(shown, "res://ui/sprites/portraits/urza_academy_headmaster_blink.png")
	assert_eq(_picture_of(hero).texture, hero.portrait_texture())
	for tick: int in 30:
		hero.advance(0.01)
	if hero.portrait_texture() != portrait:
		hero.advance(Blink.SHUT_SECONDS)
	assert_eq(hero.portrait_texture(), portrait, "The eyes open again.")


func test_a_wincing_player_does_not_blink() -> void:
	var hero: PlayerPanel = _panel(HERO)
	hero.start_breathing(7)
	hero.wince(10.0)
	for tick: int in 800:
		hero.advance(0.01)
		assert_true(hero.portrait_texture().resource_path.ends_with("_pain.png"))
		if not hero.portrait_texture().resource_path.ends_with("_pain.png"):
			return


func test_a_portrait_with_no_blink_portrait_never_blinks() -> void:
	var villain: PlayerPanel = PlayerPanel.new(VILLAIN, "VILLAIN")
	var demon: Texture2D = load("res://ui/sprites/portraits/purple_demon.png")
	villain.portrait_override = demon
	add_child_autofree(villain)
	villain.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, false, false)
	villain.start_breathing(7)
	for tick: int in 800:
		villain.advance(0.01)

	assert_eq(villain.portrait_texture(), demon)


func test_a_portrait_with_no_pain_portrait_never_winces() -> void:
	var villain: PlayerPanel = PlayerPanel.new(VILLAIN, "VILLAIN")
	villain.portrait_override = load("res://ui/sprites/portraits/purple_demon.png")
	add_child_autofree(villain)
	villain.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, false, false)

	villain.wince(0.5)

	assert_false(villain.is_wincing())
	assert_eq(villain.portrait_texture().resource_path, "res://ui/sprites/portraits/purple_demon.png")


func test_a_player_with_no_portrait_has_a_plain_square() -> void:
	var panel: PlayerPanel = PlayerPanel.new(77, "STRANGER")
	add_child_autofree(panel)
	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, false, false)

	assert_null(panel.portrait_texture())
	assert_not_null(panel.portrait())


func test_the_heros_panel_has_a_potions_button_that_is_gray_with_none_and_takes_no_press() -> void:
	var hero: PlayerPanel = _panel(HERO)
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, BOX.size))

	var potions: Button = hero.potions_button()

	assert_eq(potions.text, "⚗  Potions (0)")
	assert_eq(Rect2(potions.position, potions.size), parts["potions"], "Between the Emblems button and the controls.")
	assert_true(potions.disabled)
	assert_eq(potions.mouse_filter, Control.MOUSE_FILTER_IGNORE, "It does not light up under the cursor (A491).")
	assert_eq(PlayerPanel.tint_of(potions), PlayerPanel.NO_ITEMS_COLOR)
	assert_null(_panel(VILLAIN).potions_button(), "Only the Hero's panel has one.")


func test_the_undo_button_names_the_key_it_is_told() -> void:
	var hero: PlayerPanel = _panel(HERO)
	assert_eq(hero.undo_button().text, "Undo [Z]")

	hero.show_undo_key("BACKSPACE")

	assert_eq(hero.undo_button().text, "Undo [BACKSPACE]")
	hero.show_snapshot(_snapshot, DecisionClicks.new(), _stops, Rect2(40, 20, 300, 480), true, true)
	assert_eq(hero.undo_button().text, "Undo [BACKSPACE]", "A panel built afresh still names it.")
	_panel(VILLAIN).show_undo_key("Q")


func test_the_priority_glow_eases_from_one_panel_to_the_other_and_a_redraw_leaves_it_be() -> void:
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
	assert_eq(BorderEffects.glow_color(hero.step_button(MAIN)), PlayerPanel.NOW_COLOR, "It glows (A477).")
	assert_null(BorderEffects.glow_color(hero.step_button(UPKEEP)))
	assert_null(BorderEffects.glow_color(villain.step_button(MAIN)), "Not on the other player's row.")

	_snapshot.view.step = UPKEEP
	_snapshot.view.active_player_id = VILLAIN
	_show(hero, HERO)
	_show(villain, VILLAIN)

	assert_false(hero.shows_now(MAIN), "The mark moved off the step it was")
	assert_null(BorderEffects.glow_color(hero.step_button(MAIN)))
	assert_true(villain.shows_now(UPKEEP), "and onto the Villain's upkeep.")
	assert_eq(BorderEffects.glow_color(villain.step_button(UPKEEP)), PlayerPanel.NOW_COLOR)
	assert_false(hero.shows_now(UPKEEP))


func test_a_stop_turns_its_step_green_and_back() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var plain: Color = PlayerPanel.tint_of(panel.step_button(UPKEEP))
	var had: bool = panel.shows_stop(UPKEEP)

	_stops.toggle(HERO, UPKEEP)
	_show(panel, HERO)

	assert_eq(panel.shows_stop(UPKEEP), not had)
	assert_ne(PlayerPanel.tint_of(panel.step_button(UPKEEP)), plain)
	var colors: Array[Color] = [PlayerPanel.STOP_COLOR, Inspector.palette().button]
	assert_true(colors.has(plain))
	_stops.toggle(HERO, UPKEEP)
	_show(panel, HERO)
	assert_eq(PlayerPanel.tint_of(panel.step_button(UPKEEP)), plain)
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
	assert_eq(PlayerPanel.tint_of(button), PlayerPanel.NO_ITEMS_COLOR)

	_snapshot.view.command = [_emblem(HERO), _emblem(VILLAIN), _emblem(HERO)]
	_show(panel, HERO)

	assert_eq(button.text, "⛨  Emblems (2)")
	assert_false(button.disabled)
	var gold: StyleBox = button.get_theme_stylebox("normal")
	assert_eq(PlayerPanel.tint_of(button), PlayerPanel.GOLD)
	_snapshot.view.command = [_emblem(HERO)]
	_show(panel, HERO)
	assert_eq(button.text, "⛨  Emblems (1)")
	assert_eq(button.get_theme_stylebox("normal"), gold, "Still gold: not restyled.")
	_snapshot.view.command = []
	_show(panel, HERO)
	assert_eq(PlayerPanel.tint_of(button), Color("#6b7280"))
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
	assert_true(panel.undo_button().disabled, "Nothing to undo.")
	assert_eq(panel.yield_button().text, "☑  Yield Turn")
	assert_true(panel.yield_button().flat)

	_snapshot.can_undo = true
	_snapshot.decision = KeepOrMulliganDecision.new(HERO, 0, 0)
	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, true, false)
	assert_false(panel.undo_button().disabled)
	assert_eq(panel.yield_button().text, "☐  Yield Turn")

	_snapshot.is_villain_thinking = true
	_show(panel, HERO)
	assert_true(panel.undo_button().disabled, "Nothing is undone while the Villain thinks.")
	for control: String in ["undo", "yield"]:
		panel.connect(control + ("_toggled" if control == "yield" else "_pressed"), func() -> void: _pressed.append(control))
	panel.undo_button().pressed.emit()
	panel.yield_button().pressed.emit()
	assert_eq(_pressed, ["undo", "yield"])
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, BOX.size))
	assert_eq(Rect2(panel.undo_button().position, panel.undo_button().size), parts["undo"])
	assert_gt(panel.yield_button().position.y, panel.undo_button().position.y, "Undo is over Yield Turn.")
	assert_false(panel.has_signal("pass_pressed"), "The Pass Button is over the Info Panel now (A489).")


func test_the_villains_panel_says_when_the_villain_is_thinking_and_has_no_controls() -> void:
	var panel: PlayerPanel = _panel(VILLAIN)
	assert_null(panel.undo_button())
	assert_null(panel.yield_button())
	assert_eq(panel.thinking_text(), "")

	_snapshot.is_villain_thinking = true
	_show(panel, VILLAIN)
	assert_eq(panel.thinking_text(), "The Villain is thinking…")
	_snapshot.is_villain_thinking = false
	_show(panel, VILLAIN)
	assert_eq(panel.thinking_text(), "")
	assert_eq(_panel(HERO).thinking_text(), "", "The Hero's panel never says it.")


func test_a_panel_that_changes_sides_is_built_afresh() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var step: Button = panel.step_button(UPKEEP)

	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, false, false)

	assert_ne(panel.step_button(UPKEEP), step)
	assert_null(panel.undo_button())


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


## The picture drawn under the panel's portrait.
func _picture_of(panel: PlayerPanel) -> TextureRect:
	return panel.breathing_portrait().picture() if panel.breathing_portrait() != null else null


func _plan(source_ids: Array[int], pool_types: Array[MmMana.Type]) -> PaymentPlan:
	var plan: PaymentPlan = PaymentPlan.new()
	plan.source_ids = source_ids
	plan.pool_types = pool_types
	return plan


func _show(panel: PlayerPanel, player_id: int) -> void:
	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, BOX, player_id == HERO, player_id == HERO)


## The Glow that says the panel's player has priority.
func _outline(panel: PlayerPanel) -> Control:
	return panel.priority_glow()


func _emblem(player_id: int) -> MmObjectView:
	var emblem: MmObjectView = MmObjectView.new()
	emblem.controller_id = player_id
	return emblem


# --- Emblems and Potions buttons (ADR 0032, A526 and A537) -------------------------------

func test_the_emblems_button_glows_green_while_an_emblem_can_be_activated() -> void:
	var panel: PlayerPanel = _panel(HERO)
	_snapshot.view.command = [_boon(30)]
	_show(panel, HERO)
	assert_false(panel.is_glowing(panel.emblems_button()))

	panel.show_snapshot(_snapshot, _clicks_using(30), _stops, BOX, true, true)

	assert_true(panel.is_glowing(panel.emblems_button()))
	assert_eq(BorderEffects.glow_color(panel.emblems_button()), DecisionClicks.color_of(DecisionClicks.Kind.PLAY))
	assert_eq(PlayerPanel.tint_of(panel.emblems_button()), PlayerPanel.GOLD,
		"The Glow is an outline round the button; the button keeps its own color.")
	_show(panel, HERO)
	assert_false(panel.is_glowing(panel.emblems_button()))


func test_the_emblems_button_goes_gray_once_every_emblem_is_used_up_but_can_still_be_pressed() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var boon: MmObjectView = _boon(30)
	boon.spent_ability_indexes = [0]
	_snapshot.view.command = [boon]

	_show(panel, HERO)

	assert_eq(PlayerPanel.tint_of(panel.emblems_button()), Color("#6b7280"))
	assert_eq(panel.emblems_button().text, "⛨  Emblems (1)")
	assert_false(panel.emblems_button().disabled, "A used-up Emblem can still be read.")
	_snapshot.view.command = [boon, _emblem(HERO)]
	_show(panel, HERO)
	assert_eq(PlayerPanel.tint_of(panel.emblems_button()), PlayerPanel.GOLD)


func test_the_potions_button_counts_potions_turns_purple_and_takes_a_press() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var potions: Button = panel.potions_button()
	panel.potions_pressed.connect(func() -> void: _pressed.append("potions"))

	_snapshot.view.potions = [_potion(40), _potion(41)]
	_show(panel, HERO)

	assert_eq(potions.text, "⚗  Potions (2)")
	assert_false(potions.disabled)
	assert_eq(potions.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(PlayerPanel.tint_of(potions), PlayerPanel.POTION_COLOR)
	assert_false(panel.is_glowing(potions))
	potions.pressed.emit()
	assert_eq(_pressed, ["potions"])
	_snapshot.view.potions = []
	_show(panel, HERO)
	assert_true(potions.disabled)
	assert_eq(PlayerPanel.tint_of(potions), PlayerPanel.NO_ITEMS_COLOR)


func test_the_potions_button_glows_green_while_a_potion_can_be_used() -> void:
	var panel: PlayerPanel = _panel(HERO)
	_snapshot.view.potions = [_potion(40)]

	panel.show_snapshot(_snapshot, _clicks_using(40), _stops, BOX, true, true)

	assert_true(panel.is_glowing(panel.potions_button()))
	assert_eq(BorderEffects.glow_color(panel.potions_button()), DecisionClicks.color_of(DecisionClicks.Kind.PLAY))


func test_the_villains_emblems_button_never_glows_for_what_the_hero_can_use() -> void:
	var villain: PlayerPanel = _panel(VILLAIN)
	_snapshot.view.command = [_boon(30)]

	villain.show_snapshot(_snapshot, _clicks_using(30), _stops, BOX, false, false)

	assert_false(villain.is_glowing(villain.emblems_button()), "It counts only its own player's Emblems.")


## The Hero's Emblem with one once-each-game ability.
func _boon(id: int) -> MmObjectView:
	var boon: MmObjectView = _emblem(HERO)
	boon.id = id
	boon.abilities = (load("res://content/emblems/electromancers_boon.tres") as MmCardDefinition).abilities
	return boon


func _potion(id: int) -> MmObjectView:
	var potion: MmObjectView = _emblem(HERO)
	potion.id = id
	potion.potion_index = 0
	potion.abilities = (load("res://content/potions/big_gulp.tres") as MmCardDefinition).abilities
	return potion


## The clicks of a priority decision that offers ability 0 of Game Object [param id].
func _clicks_using(id: int) -> DecisionClicks:
	return DecisionClicks.of(PriorityDecision.new(HERO, [PassAction.new(), ActivateAbilityAction.new(id, 0)] as Array[MmAction]),
		_snapshot.view)
