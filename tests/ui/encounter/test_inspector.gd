extends GutTest
## The Inspector (13h, ADR 0033): a card's Card Face with its Rarity's glow, See Original,
## its State List and its Reminders.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const ANGEL: int = 7
const BEARS: int = 8

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
	_inspector.show_card(ANGEL, _look("serra_angel"), _look("serra_angel"), Inspector.glow_of(MmCardDefinition.Rarity.UNCOMMON), [])
	assert_eq(BorderEffects.glow_color(_inspector.face()), Inspector.GLOWS[MmCardDefinition.Rarity.UNCOMMON])

	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	assert_null(BorderEffects.glow_color(_inspector.face()), "An Emblem or a token has no Rarity.")


func test_every_rarity_has_a_glow_of_its_own() -> void:
	var seen: Array[Color] = []
	for rarity: MmCardDefinition.Rarity in MmCardDefinition.Rarity.values():
		assert_false(seen.has(Inspector.glow_of(rarity)))
		seen.append(Inspector.glow_of(rarity))


func test_see_original_shows_the_original_in_the_cards_place() -> void:
	var pumped: CardLook = _look("grizzly_bears")
	pumped.power = 5
	_inspector.show_card(BEARS, pumped, _look("grizzly_bears"), null, [])
	assert_false(_inspector.original_button().disabled)
	assert_true(_inspector.original_button().toggle_mode)
	assert_eq(_inspector.shown_look().power, 5)

	_inspector.original_button().button_pressed = true

	assert_eq(_inspector.shown_look().power, 2)
	_inspector.original_button().button_pressed = false
	assert_eq(_inspector.shown_look().power, 5)


func test_see_original_cannot_be_pressed_for_a_card_with_no_original() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])

	assert_true(_inspector.original_button().disabled)


func test_see_original_stays_for_the_same_card_and_is_let_up_for_another() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, [])
	_inspector.original_button().button_pressed = true

	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, [])
	assert_true(_inspector.original_button().button_pressed, "A new snapshot of the same card changes nothing.")
	_inspector.show_card(ANGEL, _look("serra_angel"), _look("serra_angel"), null, [])
	assert_false(_inspector.original_button().button_pressed)


func test_see_original_is_in_the_middle_under_the_card() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), _look("grizzly_bears"), null, [])
	await wait_process_frames(2)
	var button: Button = _inspector.original_button()

	assert_almost_eq(button.global_position.x + button.size.x / 2.0, _inspector.global_position.x + _inspector.size.x / 2.0, 1.0)
	assert_gt(button.global_position.y, _inspector.face().global_position.y + _inspector.face().size.y - 1.0)


func test_the_state_list_is_drawn_as_it_is_given() -> void:
	var states: Array[StateEntry] = [StateEntry.new("Damage", "2 damage is marked on it until end of turn."),
		StateEntry.new("Giant Growth", "It gets +3/+3 until end of turn.")]

	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, states)

	assert_eq(_inspector.state_texts(), [["Damage", "2 damage is marked on it until end of turn."],
		["Giant Growth", "It gets +3/+3 until end of turn."]])
	assert_true(_inspector.state_scroll().visible)
	assert_eq(_inspector.state_scroll().horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)


func test_a_card_with_no_state_and_no_keywords_shows_neither_section() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])

	assert_false(_inspector.state_scroll().visible)
	assert_false(_inspector.reminder_scroll().visible)


func test_each_keyword_has_a_reminder_with_its_icon() -> void:
	_inspector.show_card(ANGEL, _look("serra_angel"), null, null, [])

	assert_eq(_inspector.reminder_keywords(), ["Flying", "Vigilance"])
	assert_true(_inspector.reminder_scroll().visible)
	assert_eq(_inspector.reminder_icons().size(), 2)
	assert_eq(_inspector.reminder_icons()[0].texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(_inspector.reminder_icons()[0].custom_minimum_size, Vector2(32, 32), "Twice its 16 pixels.")


func test_the_reminders_are_for_the_version_shown() -> void:
	var grounded: CardLook = _look("serra_angel")
	grounded.abilities = [] as Array[MmAbility]
	_inspector.show_card(ANGEL, grounded, _look("serra_angel"), null, [])
	assert_eq(_inspector.reminder_keywords().size(), 0)

	_inspector.original_button().button_pressed = true

	assert_eq(_inspector.reminder_keywords(), ["Flying", "Vigilance"])


func test_a_section_grows_with_what_is_in_it_up_to_its_cap_and_then_scrolls() -> void:
	var states: Array[StateEntry] = []
	for index: int in 12:
		states.append(StateEntry.new("Effect %d" % index, "It gets +1/+1 until end of turn."))
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, states)
	await wait_process_frames(3)

	assert_almost_eq(_inspector.state_scroll().size.y, Inspector.STATE_CAP, 1.0)

	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, states.slice(0, 1))
	await wait_process_frames(3)
	assert_lt(_inspector.state_scroll().size.y, Inspector.STATE_CAP)


func test_the_top_says_how_to_close_it_in_tiny_centered_text_and_there_is_no_close_button() -> void:
	_inspector.show_card(BEARS, _look("grizzly_bears"), null, null, [])
	await wait_process_frames(2)
	var hint: Label = _inspector.hint()

	assert_eq(hint.text, "[Click off to close]")
	assert_eq(hint.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_almost_eq(hint.global_position.x + hint.size.x / 2.0, _inspector.global_position.x + _inspector.size.x / 2.0, 1.0)
	assert_lt(hint.get_theme_font_size("font_size"), 14)
	assert_lt(hint.global_position.y, _inspector.face().global_position.y)
	assert_lt(_inspector.face().global_position.y - _inspector.global_position.y, 36.0, "The card is near the top.")
	assert_almost_eq(hint.global_position.y - _inspector.global_position.y, 4.0, 0.01, "One unit above it.")
	var holder: Control = hint.get_parent() as Control
	assert_almost_eq(holder.size.y - hint.size.y, 8.0, 0.01, "And one below.")
	assert_false(_inspector.has_signal("close_pressed"))
	assert_eq(_inspector.find_children("*", "Button", true, false).size(), 1, "Only See Original.")


func test_it_takes_the_mouse_so_nothing_under_it_is_clicked() -> void:
	assert_eq(_inspector.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_inspector.original_button().focus_mode, Control.FOCUS_NONE, "Space still passes priority.")


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


func _look(card: String) -> CardLook:
	return CardLook.of_definition(load(ALPHA % card) as MmCardDefinition)
