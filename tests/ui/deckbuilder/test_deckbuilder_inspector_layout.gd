extends GutTest
## The deckbuilder's inspector under milestone 16 (ADR 0033, A574 to A585): View Original
## changes only the face, the inspector resets for another card, an empty panel says None
## centered and in italics, and each title sits the same distance above what is under it,
## as in the encounter's Inspector.

const Fixture: GDScript = preload("res://tests/ui/deckbuilder/support/deckbuilder_fixture.gd")
const GrantFlying: GDScript = preload("res://tests/ui/deckbuilder/support/grant_flying_modification.gd")
const FACE_HEIGHT: float = 400.0

var _fixture: Fixture
var _inspector: DeckbuilderInspector


func before_each() -> void:
	_fixture = Fixture.new()
	_inspector = DeckbuilderInspector.new()
	add_child_autofree(_inspector)
	_inspector.size = Vector2(420, 1000)


func after_each() -> void:
	await wait_process_frames(2)


func test_the_face_glows_in_the_color_of_its_rarity_as_in_the_encounter() -> void:
	_inspector.show_card(_fixture.own("shivan_dragon"), FACE_HEIGHT)
	assert_eq(BorderEffects.glow_color(_inspector.face()), Inspector.glow_of(MmCardDefinition.Rarity.RARE))

	_inspector.show_card(_fixture.own("grizzly_bears", [_winged()]), FACE_HEIGHT)
	assert_eq(BorderEffects.glow_color(_inspector.face()), Inspector.glow_of(MmCardDefinition.Rarity.COMMON))
	_inspector.original_button().button_pressed = true
	assert_eq(BorderEffects.glow_color(_inspector.face()), Inspector.glow_of(MmCardDefinition.Rarity.COMMON),
		"The Original keeps it: a Mod does not change a card's Rarity.")


func test_the_face_is_centered_across_the_inspector() -> void:
	_inspector.show_card(_fixture.own("grizzly_bears"), 360.0)
	await wait_process_frames(3)

	var face: Rect2 = _inspector.face().get_global_rect()
	assert_lt(face.size.x, _inspector.size.x - 10.0, "Narrower than the inspector, so where it sits shows.")
	assert_almost_eq(face.get_center().x, _inspector.get_global_rect().get_center().x, 1.0)


func test_card_text_puts_an_empty_line_between_abilities() -> void:
	_inspector.show_card(_fixture.own("shivan_dragon"), FACE_HEIGHT)

	assert_eq(_inspector.card_text(), "Flying\n\n{R}: This creature gets +1/+0 until end of turn.")


func test_view_original_changes_only_the_face() -> void:
	_inspector.show_card(_fixture.own("grizzly_bears", [_winged()]), FACE_HEIGHT)

	_inspector.original_button().button_pressed = true

	assert_eq(_inspector.shown_look().abilities.size(), 0, "The face is the Original.")
	assert_eq(_inspector.face().title_text().shown_text(), "Grizzly Bears")
	assert_eq(_inspector.card_text(), "Flying", "Card Text is the card with its Mods.")
	assert_eq(_inspector.mod_names(), ["Winged"] as Array[String])
	_inspector.reminders_button().button_pressed = true
	assert_eq(_inspector.reminder_keywords(), ["Flying"] as Array[String], "And so are its Reminders.")


func test_another_card_lets_both_buttons_up() -> void:
	_inspector.show_card(_fixture.own("grizzly_bears", [_winged()]), FACE_HEIGHT)
	_inspector.original_button().button_pressed = true
	_inspector.reminders_button().button_pressed = true

	_inspector.show_card(_fixture.own("serra_angel"), FACE_HEIGHT)

	assert_false(_inspector.original_button().button_pressed)
	assert_false(_inspector.reminders_button().button_pressed)
	assert_eq(_inspector.panel_titles(), ["Card Text", "Mods"] as Array[String])


func test_the_same_card_selected_again_after_none_is_reset() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears", [_winged()])
	_inspector.show_card(bears, FACE_HEIGHT)
	_inspector.reminders_button().button_pressed = true

	_inspector.show_card(null, FACE_HEIGHT)
	_inspector.show_card(bears, FACE_HEIGHT)

	assert_false(_inspector.reminders_button().button_pressed)
	assert_eq(_inspector.panel_titles(), ["Card Text", "Mods"] as Array[String])


func test_the_same_card_redrawn_keeps_its_buttons() -> void:
	var bears: DeckbuilderCard = _fixture.own("grizzly_bears", [_winged()])
	_inspector.show_card(bears, FACE_HEIGHT)
	_inspector.original_button().button_pressed = true
	_inspector.reminders_button().button_pressed = true

	_inspector.show_card(bears, FACE_HEIGHT)

	assert_true(_inspector.original_button().button_pressed)
	assert_true(_inspector.reminders_button().button_pressed)


func test_an_empty_panel_says_none_centered_and_in_italics() -> void:
	_inspector.show_card(_fixture.own("grizzly_bears"), FACE_HEIGHT)
	await wait_process_frames(3)

	for panel: PanelContainer in _inspector.panels():
		_assert_none_centered_in_italics(panel)
	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)
	_assert_none_centered_in_italics(_inspector.panels()[0])


func test_each_title_sits_a_twentieth_of_a_half_panel_above_what_is_under_it() -> void:
	_inspector.show_card(_fixture.own("serra_angel", [_winged()]), FACE_HEIGHT)
	await wait_process_frames(3)
	var gap: float = _inspector.panels()[0].size.y / 20.0

	for panel: PanelContainer in _inspector.panels():
		assert_almost_eq(_gap_under_title(panel), gap, 1.0, _title(panel).text)
	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)
	assert_almost_eq(_gap_under_title(_inspector.panels()[0]), gap, 1.0, "The same in a panel twice as tall.")


func test_card_text_mods_and_reminders_each_stand_on_a_backing() -> void:
	_inspector.show_card(_fixture.own("serra_angel", [_winged()]), FACE_HEIGHT)
	await wait_process_frames(3)

	for panel: PanelContainer in _inspector.panels():
		_assert_backed(panel, DeckbuilderLook.inspector_palette())
	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)
	_assert_backed(_inspector.panels()[0], DeckbuilderLook.inspector_palette())


func test_what_is_on_a_backing_stands_three_units_in_from_its_edges() -> void:
	_inspector.show_card(_fixture.own("shivan_dragon"), FACE_HEIGHT)
	await wait_process_frames(3)

	var backing: Rect2 = (_inspector.panels()[0].find_child("Backing", true, false) as Control).get_global_rect()
	var text: Rect2 = _inspector.card_text_label().get_global_rect()
	assert_almost_eq(text.position.x - backing.position.x, InspectorParts.INSET, 0.5, "From the left.")
	assert_almost_eq(backing.end.x - text.end.x, InspectorParts.INSET, 0.5, "From the right.")
	assert_almost_eq(text.position.y - backing.position.y, InspectorParts.INSET, 0.5, "From the top.")


func test_the_panels_and_buttons_are_dither_shaded() -> void:
	_inspector.show_card(_fixture.own("serra_angel", [_winged()]), FACE_HEIGHT)
	await wait_process_frames(3)

	for panel: PanelContainer in _inspector.panels():
		_assert_dithered_panel(panel)
	_assert_dithered_button(_inspector.original_button())
	_assert_dithered_button(_inspector.reminders_button())
	_assert_dithered_button(_inspector.apply_button())


func _winged() -> Mod:
	var mod: Mod = Mod.new()
	mod.name = "Winged"
	mod.modification = GrantFlying.new() as MmModification
	return mod


func _assert_none_centered_in_italics(panel: PanelContainer) -> void:
	var none: Label = _none_in(panel)
	assert_not_null(none, "%s says None." % _title(panel).text)
	if none == null:
		return
	assert_true(_is_italic(none), "In italics.")
	var center: Vector2 = none.get_global_rect().get_center()
	var room: Rect2 = panel.get_global_rect()
	assert_almost_eq(center.x, room.get_center().x, 1.0, "Centered across the panel.")
	var top: float = _title(panel).get_global_rect().end.y
	for inner: Node in panel.find_children("*", "PanelContainer", true, false):
		# The Mods panel's tray of bubbles stands between its title and its list.
		if inner.name != "Backing" and (inner as Control).is_visible_in_tree():
			top = maxf(top, (inner as Control).get_global_rect().end.y)
	assert_almost_eq(center.y, (top + room.end.y) / 2.0, 12.0, "And down the room it has.")


static func _none_in(panel: PanelContainer) -> Label:
	for label: Label in panel.find_children("*", "Label", true, false):
		if label.text == DeckbuilderInspector.NONE and label.is_visible_in_tree():
			return label
	return null


static func _title(panel: PanelContainer) -> Label:
	return panel.find_child("Title", true, false) as Label


static func _gap_under_title(panel: PanelContainer) -> float:
	var title: Label = _title(panel)
	var under: Control = title.get_parent().get_child(title.get_index() + 1) as Control
	return under.global_position.y - title.get_global_rect().end.y


static func _is_italic(control: Control) -> bool:
	var font: Font = control.get_theme_font("font")
	while font is FontVariation and (font as FontVariation).base_font != null:
		font = (font as FontVariation).base_font
	return font != null and font.resource_path.contains("italic")


## Checks that [param panel]'s content stands on a backing like a State Information entry's
## plate, from under its title to its bottom, with a thin edge of the panel around it.
func _assert_backed(panel: PanelContainer, palette: InspectorParts.Palette) -> void:
	var backing: PanelContainer = panel.find_child("Backing", true, false) as PanelContainer
	assert_not_null(backing, "%s has a backing." % _title(panel).text)
	if backing == null:
		return
	var style: StyleBoxFlat = backing.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.bg_color, palette.plate, "As dark as an entry's plate.")
	assert_eq(style.border_color, palette.edge)
	var inner: Rect2 = backing.get_global_rect()
	var outer: Rect2 = panel.get_global_rect()
	assert_almost_eq(inner.position.y, _title(panel).get_global_rect().end.y + _gap_under_title(panel), 1.0,
		"From under the title.")
	for side: float in [inner.position.x - outer.position.x, outer.end.x - inner.end.x, outer.end.y - inner.end.y]:
		assert_between(side, 2.0, 7.0, "A thin edge of the panel shows around it.")


## Checks that [param panel] is Dither Shaded for its own height, and what is in it is not.
func _assert_dithered_panel(panel: PanelContainer) -> void:
	var face: StyleBoxTexture = panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(face, "%s is Dither Shaded." % _title(panel).text)
	if face == null:
		return
	assert_eq(face.texture.get_height(), int(panel.size.y), "Painted for its own height.")
	assert_eq(panel.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var column: CanvasItem = panel.get_child(0) as CanvasItem
	assert_ne(column.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "What is in it is drawn as before.")


## Checks that [param button] is Dither Shaded in every state, for its own height.
func _assert_dithered_button(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var face: StyleBoxTexture = button.get_theme_stylebox(state) as StyleBoxTexture
		assert_not_null(face, "%s: %s is Dither Shaded." % [button.text, state])
		if face != null:
			assert_eq(face.texture.get_height(), int(button.size.y), "%s: %s" % [button.text, state])
	assert_eq(button.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
