extends GutTest
## The Inspector (13h and milestone 16, ADR 0033): a card's Card Face with its Rarity's
## glow, View Original and Reminders side by side under it, and two bordered, titled panels
## that fill the rest, Card Text and State Information, with one Reminders panel in place
## of both while Reminders is pressed. An Emblem and a Potion have a layout of their own.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const ANGEL: int = 7
const BEARS: int = 8
const ELVES: int = 9
const TWO_PANELS: Array[String] = ["Card Text", "State Information"]

var _inspector: Inspector


func before_each() -> void:
	_inspector = Inspector.new()
	add_child_autofree(_inspector)
	_inspector.size = Vector2(EncounterLayout.SIDEBAR_WIDTH, 1080)


func after_each() -> void:
	await wait_process_frames(2)


func test_it_shows_the_cards_face_as_wide_as_it_can() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [])

	assert_eq(_inspector.face().title_text().shown_text(), "Serra Angel")
	assert_almost_eq(_inspector.face().size.x, EncounterLayout.SIDEBAR_WIDTH - 2.0 * Inspector.PAD, 0.01)
	assert_eq(_inspector.shown_key(), ANGEL)


func test_the_face_glows_in_the_color_of_its_rarity() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), _look("serra_angel"), MmCardDefinition.Rarity.UNCOMMON, [])
	assert_eq(BorderEffects.glow_color(_inspector.face()), Inspector.GLOWS[MmCardDefinition.Rarity.UNCOMMON])

	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	assert_null(BorderEffects.glow_color(_inspector.face()), "A token has no Rarity.")


func test_every_rarity_has_a_glow_of_its_own() -> void:
	var seen: Array[Color] = []
	for rarity: MmCardDefinition.Rarity in MmCardDefinition.Rarity.values():
		assert_false(seen.has(Inspector.glow_of(rarity)))
		seen.append(Inspector.glow_of(rarity))


# --- The layout (A566 to A568) ----------------------------------------------------------

func test_view_original_and_reminders_stand_side_by_side_under_the_face() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, [])
	await wait_process_frames(3)
	var original: Button = _inspector.original_button()
	var reminders: Button = _inspector.reminders_button()

	assert_eq(original.text, "View Original")
	assert_eq(reminders.text, "Reminders")
	assert_true(original.toggle_mode)
	assert_true(reminders.toggle_mode)
	assert_eq(reminders.focus_mode, Control.FOCUS_NONE, "Space still passes priority.")
	assert_almost_eq(original.global_position.y, reminders.global_position.y, 0.5)
	assert_lt(original.global_position.x, reminders.global_position.x, "View Original on the left.")
	assert_almost_eq(original.size.x, reminders.size.x, 1.0, "Each takes half the row.")
	assert_gt(original.global_position.y, _inspector.face().get_global_rect().end.y - 1.0)
	assert_almost_eq(original.global_position.x, _inspector.global_position.x + Inspector.PAD, 1.0)
	assert_almost_eq(reminders.get_global_rect().end.x, _inspector.get_global_rect().end.x - Inspector.PAD, 1.0)


func test_each_title_is_centered_between_the_top_of_its_panel_and_what_is_under_it() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [StateEntry.new("Damage", "1 damage.")])
	await wait_process_frames(3)

	for panel: PanelContainer in _inspector.panels():
		assert_almost_eq(_room_over_title(panel), _gap_under_title(panel), 1.0, _title(panel).text)
	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)
	assert_almost_eq(_room_over_title(_inspector.panels()[0]), _gap_under_title(_inspector.panels()[0]), 1.0, "Reminders")


func test_a_panel_with_nothing_in_it_sets_its_title_as_one_with_something_would() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [])
	await wait_process_frames(3)

	var panels: Array[PanelContainer] = _inspector.panels()
	assert_almost_eq(_room_over_title(panels[1]), _room_over_title(panels[0]), 1.0)
	assert_almost_eq(_gap_under_title(panels[1]), _gap_under_title(panels[0]), 1.0)


func test_card_text_and_state_information_are_equally_tall_and_fill_the_rest() -> void:
	var states: Array[StateEntry] = [StateEntry.new("Damage", "2 damage is marked on it until end of turn."),
		StateEntry.new("Giant Growth", "It gets +3/+3 until end of turn.")]

	_inspector.show_card(ELVES, _look("llanowar_elves"), null, null, states)
	await wait_process_frames(3)

	assert_eq(_inspector.panel_titles(), TWO_PANELS)
	var panels: Array[PanelContainer] = _inspector.panels()
	assert_almost_eq(panels[0].size.y, panels[1].size.y, 1.0)
	assert_gt(panels[0].global_position.y, _inspector.reminders_button().get_global_rect().end.y - 1.0)
	assert_almost_eq(panels[1].get_global_rect().end.y, _inspector.get_global_rect().end.y - Inspector.PAD, 1.0,
		"Down to the bottom of the Inspector.")
	assert_almost_eq(panels[0].size.x, EncounterLayout.SIDEBAR_WIDTH - 2.0 * Inspector.PAD, 1.0)


func test_card_text_is_the_printed_rules_text_with_its_symbols_drawn() -> void:
	_inspector.show_card(ELVES, _look("llanowar_elves"), null, null, [])

	assert_eq(_inspector.card_text(), "{T}: Add {G}.")
	assert_eq(_inspector.card_text_label().symbols(), ["t", "g"] as Array[String])

	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [])
	assert_false(_inspector.card_text().contains("("), "Card Text never has reminder text.")
	assert_string_contains(_inspector.card_text(), "Flying")


func test_the_state_information_is_drawn_as_it_is_given() -> void:
	var states: Array[StateEntry] = [StateEntry.new("Damage", "2 damage is marked on it until end of turn."),
		StateEntry.new("Giant Growth", "It gets +3/+3 until end of turn.")]

	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, states)

	assert_eq(_inspector.state_texts(), [["Damage", "2 damage is marked on it until end of turn."],
		["Giant Growth", "It gets +3/+3 until end of turn."]])
	assert_null(_none_in(_inspector.panels()[1]))


func test_each_state_entry_is_on_a_dark_gray_edged_plate_titled_in_bold_underlined_and_centered() -> void:
	var states: Array[StateEntry] = [StateEntry.new("Damage", "2 damage is marked on it until end of turn."),
		StateEntry.new("Giant Growth", "It gets +3/+3 until end of turn.")]
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, states)
	await wait_process_frames(3)

	var plates: Array[PanelContainer] = _inspector.state_plates()
	assert_eq(plates.size(), 2)
	for index: int in plates.size():
		var style: StyleBoxFlat = plates[index].get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(style.border_color, Inspector.palette().edge, "Edged in the panels' gray.")
		assert_gt(style.border_width_top, 0)
		assert_lt(style.bg_color.v, Inspector.palette().panel.v, "Darker than the panel it is in.")
		var title: RichTextLabel = plates[index].find_child("EntryTitle", true, false) as RichTextLabel
		assert_eq(title.get_parsed_text(), states[index].title)
		assert_string_contains(title.text, "[b]")
		assert_string_contains(title.text, "[u]")
		assert_true(title.text.begins_with("[center]"), "Centered at the top.")
		assert_almost_eq(title.get_global_rect().get_center().x, plates[index].get_global_rect().get_center().x, 1.0)
		assert_lt(title.global_position.y, (plates[index].find_child("Sentence", true, false) as Control).global_position.y)


func test_card_text_puts_an_empty_line_between_abilities() -> void:
	_inspector.show_card(BEARS, _look("shivan_dragon"), null, null, [])

	assert_eq(_inspector.card_text(), "Flying\n\n{R}: This creature gets +1/+0 until end of turn.")


func test_a_card_with_no_state_says_none_centered_and_in_italics() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	await wait_process_frames(3)

	assert_eq(_inspector.panel_titles(), TWO_PANELS, "The panels are drawn whatever the card has.")
	_assert_none_centered_in_italics(_inspector.panels()[1])


func test_a_card_with_no_rules_text_says_none_in_its_card_text() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	await wait_process_frames(3)

	assert_eq(_inspector.card_text(), "None")
	_assert_none_centered_in_italics(_inspector.panels()[0])


func test_reminders_puts_one_panel_in_place_of_both_with_each_keyword() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [])

	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)

	assert_eq(_inspector.panel_titles(), ["Reminders"] as Array[String])
	assert_eq(_inspector.reminder_keywords(), ["Flying", "Vigilance"])
	assert_eq(_inspector.reminder_icons().size(), 2)
	assert_eq(_inspector.reminder_icons()[0].texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(_inspector.reminder_icons()[0].custom_minimum_size, Vector2(32, 32), "Twice its 16 pixels.")
	var panel: PanelContainer = _inspector.panels()[0]
	assert_almost_eq(panel.get_global_rect().end.y, _inspector.get_global_rect().end.y - Inspector.PAD, 1.0)

	_inspector.reminders_button().button_pressed = false
	assert_eq(_inspector.panel_titles(), TWO_PANELS)


func test_a_card_with_no_keywords_says_none_in_its_reminders() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])

	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)

	assert_eq(_inspector.reminder_keywords().size(), 0)
	_assert_none_centered_in_italics(_inspector.panels()[0])


func test_what_does_not_fit_scrolls_inside_its_panel_and_the_panels_keep_their_heights() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	await wait_process_frames(3)
	var heights: Array[float] = [_inspector.panels()[0].size.y, _inspector.panels()[1].size.y]
	var states: Array[StateEntry] = []
	for index: int in 20:
		states.append(StateEntry.new("Effect %d" % index, "It gets +1/+1 until end of turn."))

	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, states)
	await wait_process_frames(3)

	assert_almost_eq(_inspector.panels()[0].size.y, heights[0], 1.0)
	assert_almost_eq(_inspector.panels()[1].size.y, heights[1], 1.0)
	var scroll: ScrollContainer = _scroll_in(_inspector.panels()[1])
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.size.y, "It has more than it can show.")


func test_each_title_sits_a_twentieth_of_a_cards_panel_above_what_is_under_it() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [StateEntry.new("Damage", "1 damage.")])
	await wait_process_frames(3)
	var gap: float = _inspector.panels()[0].size.y / 20.0

	for panel: PanelContainer in _inspector.panels():
		assert_almost_eq(_gap_under_title(panel), gap, 1.0, _title(panel).text)
	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)
	assert_almost_eq(_gap_under_title(_inspector.panels()[0]), gap, 1.0, "The same in a panel twice as tall.")


func test_card_text_and_reminders_stand_on_a_backing_and_state_information_on_its_plates() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [StateEntry.new("Damage", "1 damage.")])
	await wait_process_frames(3)

	_assert_backed(_inspector.panels()[0], Inspector.palette())
	assert_null(_inspector.panels()[1].find_child("Backing", true, false), "Its entries have plates of their own.")
	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)
	_assert_backed(_inspector.panels()[0], Inspector.palette())


func test_what_is_on_a_backing_stands_three_units_in_from_its_edges() -> void:
	_inspector.show_card(BEARS, _look("shivan_dragon"), null, null, [])
	await wait_process_frames(3)

	var backing: Rect2 = (_inspector.panels()[0].find_child("Backing", true, false) as Control).get_global_rect()
	var text: Rect2 = _inspector.card_text_label().get_global_rect()
	assert_almost_eq(text.position.x - backing.position.x, InspectorParts.INSET, 0.5, "From the left.")
	assert_almost_eq(backing.end.x - text.end.x, InspectorParts.INSET, 0.5, "From the right.")
	assert_almost_eq(text.position.y - backing.position.y, InspectorParts.INSET, 0.5, "From the top.")
	assert_eq(InspectorParts.INSET, 12.0, "Three units.")


func test_an_entrys_sentence_stands_in_from_its_plates_sides_and_bottom() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [StateEntry.new("Damage", "2 damage is marked on it until end of turn.")])
	await wait_process_frames(3)

	var plate: PanelContainer = _inspector.state_plates()[0]
	var sentence: Rect2 = (plate.find_child("Sentence", true, false) as Control).get_global_rect()
	var outer: Rect2 = plate.get_global_rect()
	assert_gte(sentence.position.x - outer.position.x, InspectorParts.INSET, "From the left.")
	assert_gte(outer.end.x - sentence.end.x, InspectorParts.INSET, "From the right.")
	assert_gte(outer.end.y - sentence.end.y, InspectorParts.INSET, "From the bottom.")
	var title: Control = plate.find_child("EntryTitle", true, false) as Control
	assert_almost_eq(title.get_global_rect().get_center().x, outer.get_center().x, 1.0, "The title is still centered.")


func test_the_panels_and_buttons_are_dither_shaded_and_follow_a_panels_height() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), _look("serra_angel"), null, [])
	await wait_process_frames(3)

	for panel: PanelContainer in _inspector.panels():
		_assert_dithered_panel(panel)
	_assert_dithered_button(_inspector.original_button())
	_assert_dithered_button(_inspector.reminders_button())
	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)
	_assert_dithered_panel(_inspector.panels()[0])
	assert_null(_inspector.panels()[0].find_child("Backing", true, false).get_theme_stylebox("panel") as StyleBoxTexture,
		"A backing is content, and stays flat.")


func test_the_inspectors_own_background_is_dither_shaded_for_its_height() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	await wait_process_frames(3)

	var face: StyleBoxTexture = _inspector.get_theme_stylebox("panel") as StyleBoxTexture
	assert_not_null(face, "Dither Shaded (A598).")
	if face == null:
		return
	assert_eq(face.texture.get_height(), int(_inspector.size.y))
	assert_eq(_inspector.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_ne(_inspector.contents().texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "What is on it is drawn as before.")
	_inspector.size = Vector2(EncounterLayout.SIDEBAR_WIDTH, 900)
	await wait_process_frames(2)
	assert_eq((_inspector.get_theme_stylebox("panel") as StyleBoxTexture).texture.get_height(), 900, "Painted again for a new height.")


func test_the_titles_are_centered() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	await wait_process_frames(3)

	for panel: PanelContainer in _inspector.panels():
		var title: Label = _title(panel)
		assert_almost_eq(title.get_global_rect().get_center().x, panel.get_global_rect().get_center().x, 1.0)


# --- View Original (A574) ---------------------------------------------------------------

func test_view_original_shows_the_original_on_the_face() -> void:
	var pumped: CardLook = _look("grizzly_bears")
	pumped.power = 5
	_inspector.show_card(BEARS, pumped, _look("grizzly_bears"), null, [])
	assert_false(_inspector.original_button().disabled)
	assert_eq(_inspector.shown_look().power, 5)

	_inspector.original_button().button_pressed = true

	assert_eq(_inspector.shown_look().power, 2)
	_inspector.original_button().button_pressed = false
	assert_eq(_inspector.shown_look().power, 5)


func test_view_original_changes_only_the_face() -> void:
	var flying: CardLook = _look("grizzly_bears")
	flying.abilities = [FlyingAbility.new()] as Array[MmAbility]
	flying.rules_text = "Flying"
	var states: Array[StateEntry] = [StateEntry.new("Jump", "It gains flying until end of turn.")]
	_inspector.show_card(BEARS, flying, _look("grizzly_bears"), null, states)

	_inspector.original_button().button_pressed = true

	assert_eq(_inspector.shown_look().abilities.size(), 0, "The face is the Original.")
	assert_eq(_inspector.card_text(), "Flying", "Card Text is the creature as it is now.")
	assert_eq(_inspector.state_texts(), [["Jump", "It gains flying until end of turn."]])
	_inspector.reminders_button().button_pressed = true
	assert_eq(_inspector.reminder_keywords(), ["Flying"], "And so are its Reminders.")


func test_view_original_cannot_be_pressed_for_a_card_with_no_original() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])

	assert_true(_inspector.original_button().disabled)


# --- Resetting (A575, A583) -------------------------------------------------------------

func test_another_card_lets_both_buttons_up_and_scrolls_to_the_top() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, _many_states())
	await wait_process_frames(3)
	var scroll: ScrollContainer = _scroll_in(_inspector.panels()[1])
	scroll.scroll_vertical = 40
	_inspector.original_button().button_pressed = true

	_inspector.show_card(ANGEL, _look("serra_angel"), _look("serra_angel"), null, _many_states())
	await wait_process_frames(3)

	assert_false(_inspector.original_button().button_pressed)
	assert_eq(_scroll_in(_inspector.panels()[1]).scroll_vertical, 0)
	_inspector.reminders_button().button_pressed = true
	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, [])
	assert_false(_inspector.reminders_button().button_pressed)
	assert_eq(_inspector.panel_titles(), TWO_PANELS)


func test_the_same_card_in_a_new_snapshot_keeps_its_buttons_and_its_place() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, _many_states())
	await wait_process_frames(3)
	_scroll_in(_inspector.panels()[1]).scroll_vertical = 40
	_inspector.original_button().button_pressed = true

	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, _many_states())
	await wait_process_frames(3)

	assert_true(_inspector.original_button().button_pressed)
	assert_eq(_scroll_in(_inspector.panels()[1]).scroll_vertical, 40)
	_inspector.reminders_button().button_pressed = true
	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, [])
	assert_true(_inspector.reminders_button().button_pressed)


# --- The hint (A569, A576) --------------------------------------------------------------

func test_the_top_says_how_to_close_it_in_small_centered_italics_and_there_is_no_close_button() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	await wait_process_frames(3)
	var hint: Label = _inspector.hint()

	assert_eq(hint.text, "[Click off to close]")
	assert_true(_is_italic(hint))
	assert_eq(hint.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_almost_eq(hint.global_position.x + hint.size.x / 2.0, _inspector.global_position.x + _inspector.size.x / 2.0, 1.0)
	assert_lt(hint.get_theme_font_size("font_size"), 14)
	assert_lt(hint.global_position.y, _inspector.face().global_position.y)
	assert_almost_eq(hint.global_position.y - _inspector.global_position.y, 8.0, 0.01, "Two units above it.")
	var holder: Control = hint.get_parent() as Control
	assert_almost_eq(holder.size.y - hint.size.y, 16.0, 0.01, "And two below.")
	assert_false(_inspector.has_signal("close_pressed"))
	assert_eq(_inspector.find_children("*", "Button", true, false).size(), 2, "Only View Original and Reminders.")


func test_it_takes_the_mouse_so_nothing_under_it_is_clicked() -> void:
	assert_eq(_inspector.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_inspector.original_button().focus_mode, Control.FOCUS_NONE, "Space still passes priority.")


# --- Easing -----------------------------------------------------------------------------

func test_another_card_eases_out_before_the_next_eases_in() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [], 0.1)
	assert_eq(_inspector.shown_key(), BEARS, "The first card has nothing to wait for.")

	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [], 0.1)
	assert_eq(_inspector.shown_key(), BEARS, "The old card is still fading out.")
	await wait_seconds(0.2)

	assert_eq(_inspector.shown_key(), ANGEL)
	assert_almost_eq(_inspector.contents().modulate.a, 1.0, 0.001)


func test_the_same_card_changed_is_redrawn_at_once() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [], 0.1)
	var pumped: CardLook = _look("grizzly_bears")
	pumped.power = 5

	_inspector.show_card(BEARS, pumped, null, null, [], 0.1)

	assert_eq(_inspector.shown_look().power, 5)


func test_with_no_time_another_card_is_shown_at_once() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])

	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [])

	assert_eq(_inspector.shown_key(), ANGEL)


# --- An Emblem and a Potion (A572, A580, A581, A587, A588) ------------------------------

func test_an_emblem_has_its_face_a_full_width_reminders_button_and_one_card_text_panel() -> void:
	_inspector.show_card(BEARS, _emblem_look([]), null, null, [])
	await wait_process_frames(3)

	var face: EmblemFace = _inspector.emblem_face()
	assert_null(_inspector.face())
	assert_null(_inspector.potion_readout())
	assert_almost_eq(face.size.x, EncounterLayout.SIDEBAR_WIDTH - 2.0 * Inspector.PAD, 0.01)
	assert_eq(face.name_text(), "Electromancer's Boon")
	assert_eq(face.type_line_text(), "Emblem")
	assert_false(_inspector.original_button().visible, "An Emblem has no Original.")
	_assert_reminders_spans_the_row()
	assert_eq(_inspector.panel_titles(), ["Card Text"] as Array[String], "No State Information.")
	assert_eq(_inspector.card_text(), "{R}: This emblem deals 3 damage to any target. Activate only once each game.")
	_assert_one_panel_fills_the_rest()


func test_an_emblems_spent_ability_is_marked_used_in_its_card_text() -> void:
	_inspector.show_card(BEARS, _emblem_look([0]), null, null, [])

	assert_eq(_inspector.card_text(),
		"{R}: This emblem deals 3 damage to any target. Activate only once each game." + EmblemFace.USED_SUFFIX)


func test_a_potion_has_its_icon_its_name_its_rarity_and_potion_and_one_card_text_panel() -> void:
	_inspector.show_card(BEARS, _potion_look(), null, MmCardDefinition.Rarity.COMMON, [])
	await wait_process_frames(3)

	var view: PotionReadout = _inspector.potion_readout()
	assert_null(_inspector.face())
	assert_null(_inspector.emblem_face())
	assert_eq(view.name_text(), "Big Gulp")
	assert_eq(view.type_line_text(), "Common Potion")
	assert_false(view.art().is_small(), "The large art: the circle fills the icon's grid.")
	assert_eq(view.art().key(), "big_gulp")
	assert_eq(fmod(view.art().icon_rect().size.x, PotionArt.CELLS), 0.0, "A whole number of pixels to each art pixel.")
	assert_eq(view.glow_color(), Inspector.glow_of(MmCardDefinition.Rarity.COMMON))
	for label: Label in view.find_children("*", "Label", true, false):
		assert_false(label.text.contains("Target creature"), "The readout leaves its rules text to Card Text.")
	assert_false(_inspector.original_button().visible, "A Potion has no Original.")
	_assert_reminders_spans_the_row()
	assert_eq(_inspector.panel_titles(), ["Card Text"] as Array[String])
	assert_eq(_inspector.card_text(), "Target creature gets +2/+2 until end of turn.")
	_assert_one_panel_fills_the_rest()


func test_a_potions_type_line_names_its_rarity() -> void:
	_inspector.show_card(BEARS, _potion_look(), null, MmCardDefinition.Rarity.RARE, [])

	assert_eq(_inspector.potion_readout().type_line_text(), "Rare Potion")


func test_reminders_puts_its_panel_in_place_of_an_emblems_or_a_potions_card_text() -> void:
	_inspector.show_card(BEARS, _potion_look(), null, MmCardDefinition.Rarity.COMMON, [])
	_inspector.reminders_button().button_pressed = true
	await wait_process_frames(3)
	assert_eq(_inspector.panel_titles(), ["Reminders"] as Array[String])
	_assert_none_centered_in_italics(_inspector.panels()[0])

	var winged: CardLook = _held_look("res://content/emblems/electromancers_boon.tres", "", CardLook.Kind.EMBLEM, [])
	winged.abilities = [FlyingAbility.new()] as Array[MmAbility]
	_inspector.show_card(ANGEL, winged, null, null, [])
	_inspector.reminders_button().button_pressed = true
	assert_eq(_inspector.reminder_keywords(), ["Flying"])


func test_an_emblems_and_a_potions_titles_sit_where_a_cards_do() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [])
	await wait_process_frames(3)
	var gap: float = _gap_under_title(_inspector.panels()[0])

	_inspector.show_card(BEARS, _emblem_look([]), null, null, [])
	await wait_process_frames(3)
	assert_almost_eq(_gap_under_title(_inspector.panels()[0]), gap, 1.0, "An Emblem's.")
	_inspector.show_card(ELVES, _potion_look(), null, MmCardDefinition.Rarity.COMMON, [])
	await wait_process_frames(3)
	assert_almost_eq(_gap_under_title(_inspector.panels()[0]), gap, 1.0, "A Potion's.")


func test_a_card_shown_after_an_emblem_gets_its_card_face_and_both_panels_back() -> void:
	_inspector.show_card(BEARS, _emblem_look([]), null, null, [])

	_inspector.show_card(ANGEL, _look("serra_angel"), _look("serra_angel"), null, [])

	assert_null(_inspector.emblem_face())
	assert_eq(_inspector.face().title_text().shown_text(), "Serra Angel")
	assert_true(_inspector.original_button().visible)
	assert_eq(_inspector.panel_titles(), TWO_PANELS)


# --- helpers ----------------------------------------------------------------------------

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
	var disabled: StyleBox = button.get_theme_stylebox("disabled")
	assert_eq(disabled.content_margin_top, disabled.content_margin_bottom, "%s: a disabled button has no lip." % button.text)


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



func _look(card: String) -> CardLook:
	return CardLook.of_definition(load(ALPHA % card) as MmCardDefinition)


func _emblem_look(spent: Array[int]) -> CardLook:
	return _held_look("res://content/emblems/electromancers_boon.tres", "emblems/electromancers_boon", CardLook.Kind.EMBLEM, spent)


func _potion_look() -> CardLook:
	return _held_look("res://content/potions/big_gulp.tres", "big_gulp", CardLook.Kind.POTION, [])


## The look of the Emblem or Potion authored at [param path], as a view would show it.
func _held_look(path: String, art_key: String, kind: CardLook.Kind, spent: Array[int]) -> CardLook:
	var definition: MmCardDefinition = load(path)
	var seen: MmObjectView = MmObjectView.new()
	seen.name = definition.name
	seen.abilities = definition.abilities
	seen.spent_ability_indexes = spent
	return CardLook.of_held(seen, art_key, kind)


func _many_states() -> Array[StateEntry]:
	var states: Array[StateEntry] = []
	for index: int in 20:
		states.append(StateEntry.new("Effect %d" % index, "It gets +1/+1 until end of turn."))
	return states


func _assert_reminders_spans_the_row() -> void:
	var button: Button = _inspector.reminders_button()
	assert_true(button.visible)
	assert_almost_eq(button.size.x, EncounterLayout.SIDEBAR_WIDTH - 2.0 * Inspector.PAD, 1.0, "The whole row.")


func _assert_one_panel_fills_the_rest() -> void:
	var panel: PanelContainer = _inspector.panels()[0]
	assert_gt(panel.global_position.y, _inspector.reminders_button().get_global_rect().end.y - 1.0)
	assert_almost_eq(panel.get_global_rect().end.y, _inspector.get_global_rect().end.y - Inspector.PAD, 1.0)


func _assert_none_centered_in_italics(panel: PanelContainer) -> void:
	var none: Label = _none_in(panel)
	assert_not_null(none, "%s says None." % _title(panel).text)
	if none == null:
		return
	assert_true(_is_italic(none), "In italics.")
	var center: Vector2 = none.get_global_rect().get_center()
	var room: Rect2 = panel.get_global_rect()
	var below_title: float = _title(panel).get_global_rect().end.y
	assert_almost_eq(center.x, room.get_center().x, 1.0, "Centered across the panel.")
	assert_almost_eq(center.y, (below_title + room.end.y) / 2.0, 12.0, "And down what is under its title.")


## The dim "None" a panel shows when it has nothing to say, or null.
static func _none_in(panel: PanelContainer) -> Label:
	for label: Label in panel.find_children("*", "Label", true, false):
		if label.text == "None" and label.is_visible_in_tree():
			return label
	return null


static func _title(panel: PanelContainer) -> Label:
	return panel.find_child("Title", true, false) as Label


## The room between the top of a panel and its title.
static func _room_over_title(panel: PanelContainer) -> float:
	return _title(panel).global_position.y - panel.global_position.y


## The room between a panel's title and what is under it.
static func _gap_under_title(panel: PanelContainer) -> float:
	var title: Label = _title(panel)
	var column: Node = title.get_parent()
	var under: Control = column.get_child(title.get_index() + 1) as Control
	return under.global_position.y - title.get_global_rect().end.y


static func _scroll_in(panel: PanelContainer) -> ScrollContainer:
	return panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer


## Whether [param control] is set in an italic face.
static func _is_italic(control: Control) -> bool:
	var font: Font = control.get_theme_font("font")
	while font is FontVariation and (font as FontVariation).base_font != null:
		font = (font as FontVariation).base_font
	return font != null and font.resource_path.contains("italic")
