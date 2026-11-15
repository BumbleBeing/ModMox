extends GutTest
## The sidebar takes the Inspector's treatment, in the Inspector's own colors: a Dither
## Shaded backing, each player's panel an edged, dithered panel, dithered buttons, and the
## Hero's controls on an entry's plate. Nothing in it moves or changes size for it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const UPKEEP: MmTurn.Step = MmTurn.Step.UPKEEP
const MAIN: MmTurn.Step = MmTurn.Step.PRECOMBAT_MAIN

var _stops: StepStops
var _snapshot: EncounterSnapshot
var _screen: EncounterScreen
var _presenter: EncounterPresenter


func before_each() -> void:
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


func test_the_sidebar_backing_is_dither_shaded_like_the_inspector_and_outlasts_a_redraw() -> void:
	_open()
	var sidebar: Rect2 = EncounterLayout.regions(SCREEN)["sidebar"]
	var backing: Panel = _screen.sidebar_backing()

	assert_eq(backing.get_global_rect(), sidebar)
	assert_eq(backing.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var face: StyleBoxTexture = backing.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(face, "It is a Dither Shaded plate.")
	assert_eq(face.texture.get_height(), int(sidebar.size.y), "Painted for its own height.")
	assert_true(_same(face, DitherShading.plate(Inspector.BACKGROUND.lightened(0.06), Inspector.BACKGROUND.darkened(0.3),
		Inspector.BACKGROUND, 0, 0, 0, int(sidebar.size.y))), "In the Inspector's own background.")
	assert_lt(backing.get_index(), _screen.player_panel(HERO).get_index(), "Under the panels.")
	assert_eq(backing.mouse_filter, Control.MOUSE_FILTER_IGNORE)

	_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
	_presenter.wait_until_idle()
	assert_eq(_screen.sidebar_backing(), backing, "Built once, not on every redraw.")
	assert_eq(backing.get_theme_stylebox("panel"), face, "Not painted again.")


func test_the_inspector_still_covers_the_sidebar_exactly() -> void:
	_open()
	var inspector: Inspector = _screen.inspector()
	assert_eq(Rect2(inspector.position, inspector.size), _screen.sidebar_backing().get_global_rect())


func test_each_panel_is_an_edged_dithered_panel_in_the_inspectors_colors() -> void:
	for player_id: int in [HERO, VILLAIN]:
		var panel: PlayerPanel = _panel(player_id)
		var backing: Panel = panel.backing()
		var height: int = int(_box(player_id).size.y)
		assert_eq(backing.size, _box(player_id).size)
		assert_eq(backing.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_eq(backing.get_index(), 0, "Behind everything in the panel.")
		var face: StyleBoxTexture = backing.get_theme_stylebox("panel") as StyleBoxTexture
		assert_not_null(face)
		var palette: InspectorParts.Palette = Inspector.palette()
		assert_true(_same(face, DitherShading.plate(palette.panel.lightened(0.06), palette.panel.darkened(0.3),
			palette.edge, PlayerPanel.RADIUS, palette.edge_width, 0, height)), "Panel %d." % player_id)


func test_the_name_keeps_its_size_and_color() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var name_label: Label = panel.name_label()
	assert_eq(name_label.get_theme_font_size("font_size"), 22 + UiText.RAISE)
	assert_false(name_label.has_theme_color_override("font_color"), "Not muted like a panel's title.")


func test_steps_are_dithered_gray_and_stops_green() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var upkeep: Button = panel.step_button(UPKEEP)
	var height: int = int(upkeep.size.y)
	assert_eq(upkeep.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_true(_same(upkeep.get_theme_stylebox("normal"), DitherShading.button_plate(Inspector.palette().button, false, height)))
	assert_true(_same(upkeep.get_theme_stylebox("hover"),
		DitherShading.button_plate(Inspector.palette().button.lightened(InspectorParts.HOVER_LIGHTEN), false, height)))
	assert_true(_same(upkeep.get_theme_stylebox("pressed"), DitherShading.button_plate(Inspector.palette().button, true, height)))

	_stops.toggle(HERO, UPKEEP)
	_show(panel, HERO)
	assert_true(_same(upkeep.get_theme_stylebox("normal"), DitherShading.button_plate(PlayerPanel.STOP_COLOR, false, height)),
		"A stop is dithered green.")


func test_untap_and_cleanup_lie_flat() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var untap: Button = panel.step_button(MmTurn.Step.UNTAP)
	assert_true(untap.disabled)
	assert_true(_same(untap.get_theme_stylebox("disabled"),
		DitherShading.disabled_plate(Inspector.palette().button_disabled, int(untap.size.y))))


func test_the_now_glow_and_the_priority_glow_still_show() -> void:
	var panel: PlayerPanel = _panel(HERO)
	assert_true(panel.shows_now(MAIN))
	assert_true(panel.priority_glow().visible)


func test_emblems_are_dithered_gold_and_potions_purple_with_their_lettering_kept() -> void:
	_snapshot.view.command = [_held(HERO)]
	_snapshot.view.potions = [_held(HERO)]
	var panel: PlayerPanel = _panel(HERO)
	var emblems: Button = panel.emblems_button()
	var potions: Button = panel.potions_button()
	assert_true(_same(emblems.get_theme_stylebox("normal"),
		DitherShading.button_plate(PlayerPanel.held_fill(PlayerPanel.GOLD), false, int(emblems.size.y))))
	assert_true(_same(potions.get_theme_stylebox("normal"),
		DitherShading.button_plate(PlayerPanel.held_fill(PlayerPanel.POTION_COLOR), false, int(potions.size.y))))
	assert_eq(emblems.get_theme_color("font_color"), Color("#f1dc9a"))
	assert_eq(potions.get_theme_color("font_color"), Color("#dcc6f7"))


func test_with_none_held_they_are_gray_and_lie_flat() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var potions: Button = panel.potions_button()
	assert_true(potions.disabled)
	assert_true(_same(potions.get_theme_stylebox("disabled"),
		DitherShading.disabled_plate(PlayerPanel.held_fill(PlayerPanel.NO_ITEMS_COLOR), int(potions.size.y))))


func test_the_heros_controls_sit_on_an_entry_plate_and_undo_is_dithered() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var palette: InspectorParts.Palette = Inspector.palette()
	var plate: StyleBoxFlat = panel.controls_plate().get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(plate.bg_color, palette.plate)
	assert_eq(plate.border_color, palette.edge)
	var undo: Button = panel.undo_button()
	var height: int = int(undo.size.y)
	assert_true(_same(undo.get_theme_stylebox("normal"), DitherShading.button_plate(palette.button, false, height)))
	assert_true(_same(undo.get_theme_stylebox("disabled"), DitherShading.disabled_plate(palette.button_disabled, height)))
	_snapshot.can_undo = false
	_show(panel, HERO)
	assert_true(undo.disabled, "It still grays out when nothing can be undone.")


func test_the_portrait_lies_on_a_flat_square_of_the_panels_color() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var back: Panel = panel.portrait_back()
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, _box(HERO).size))
	assert_eq(back.get_rect(), parts["portrait"])
	var flat: StyleBoxFlat = back.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(flat, "Flat, not dithered.")
	assert_eq(flat.bg_color, Inspector.palette().panel)
	assert_eq(back.get_index(), panel.portrait_edge().get_index() - 2, "Just under the picture.")


func test_the_portrait_has_the_panels_edge_and_the_mana_row_is_unchanged() -> void:
	var panel: PlayerPanel = _panel(HERO)
	var edge: StyleBoxFlat = panel.portrait_edge().get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(edge.border_color, Inspector.palette().edge)
	assert_eq(edge.border_width_top, 2)
	var mana: StyleBoxFlat = panel.mana_button(MmMana.Type.GREEN).get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(mana, "Still a flat plate.")
	assert_eq(mana.bg_color, PlayerPanel.PLAIN_COLOR)


func test_no_button_moves_or_changes_size() -> void:
	for player_id: int in [HERO, VILLAIN]:
		_snapshot.view.command = [_held(HERO), _held(VILLAIN)]
		_snapshot.view.potions = [_held(HERO)]
		var panel: PlayerPanel = _panel(player_id)
		await wait_process_frames(1)
		var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(Vector2.ZERO, _box(player_id).size))
		var buttons: Dictionary[String, Button] = {"emblems": panel.emblems_button()}
		for step: int in PlayerPanel.STEP_NAMES.size():
			buttons["step_%d" % step] = panel.step_button(step)
		if player_id == HERO:
			buttons["potions"] = panel.potions_button()
			buttons["undo"] = panel.undo_button()
			buttons["yield"] = panel.yield_button()
		for part: String in buttons:
			var at: Rect2 = buttons[part].get_rect()
			assert_true(at.position.is_equal_approx(parts[part].position) and at.size.is_equal_approx(parts[part].size),
				"%s on panel %d: %s, laid out as %s." % [part, player_id, at, parts[part]])
			assert_true(Rect2(Vector2.ZERO, _box(player_id).size).encloses(buttons[part].get_rect()))


func _open() -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	var cards: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	_presenter = EncounterPresenter.new(
		Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)), DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()


## The panel's place on a 1920 × 1080 screen.
func _box(player_id: int) -> Rect2:
	return EncounterLayout.regions(SCREEN)["hero_panel" if player_id == HERO else "villain_panel"]


func _panel(player_id: int) -> PlayerPanel:
	var panel: PlayerPanel = PlayerPanel.new(player_id, "HERO" if player_id == HERO else "VILLAIN")
	add_child_autofree(panel)
	_show(panel, player_id)
	return panel


func _show(panel: PlayerPanel, player_id: int) -> void:
	panel.show_snapshot(_snapshot, DecisionClicks.new(), _stops, _box(player_id), player_id == HERO, player_id == HERO)


## An Emblem or a Potion that [param player_id] holds.
func _held(player_id: int) -> MmObjectView:
	var held: MmObjectView = MmObjectView.new()
	held.controller_id = player_id
	return held


## Whether two Dither Shaded plates are painted alike, pixel for pixel.
func _same(a: StyleBox, b: StyleBox) -> bool:
	var left: StyleBoxTexture = a as StyleBoxTexture
	var right: StyleBoxTexture = b as StyleBoxTexture
	if left == null or right == null:
		return false
	return left.texture.get_image().get_data() == right.texture.get_image().get_data()
