extends GutTest
## The opening-hand overlay on the Encounter Screen (13e-2): play or draw, keep or mulligan
## and putting cards on the bottom are all answered on it, over everything but the sidebar.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SlowAgent := preload("res://tests/ui/encounter/support/slow_agent.gd")
const MulliganAgent := preload("res://tests/ui/encounter/support/mulligan_agent.gd")
const Rule := MmEncounterSetup.StartingPlayerRule
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const KEEP: int = KeepOrMulliganDecision.Choice.KEEP
const MULLIGAN: int = KeepOrMulliganDecision.Choice.MULLIGAN
const GREEN: Color = Color("#7be36a")

var _presenter: EncounterPresenter
var _screen: EncounterScreen
var _overlay: OpeningHandOverlay


func after_each() -> void:
	await wait_process_frames(2)


func test_the_chooser_picks_play_or_draw_on_an_overlay_with_no_cards() -> void:
	_open(Scenario.setup(Rule.HERO_CHOOSES))

	assert_true(_overlay.is_open())
	assert_eq(_overlay.heading_text(), "You choose")
	assert_eq(_overlay.shown_ids(), [] as Array[int], "The hands are not dealt yet.")
	assert_eq(_overlay.button_texts(), ["Play first", "Draw first"] as Array[String])

	_press("Play first")

	assert_true(_presenter.snapshot().decision is KeepOrMulliganDecision)
	assert_eq(_overlay.under_heading_text(), "You play first")
	assert_eq(_overlay.shown_ids().size(), 7)


func test_choosing_to_draw_lets_the_villain_play_first() -> void:
	_open(Scenario.setup(Rule.HERO_CHOOSES))

	_press("Draw first")

	assert_eq(_overlay.under_heading_text(), "The Villain plays first")
	assert_eq(_overlay.villain_text(), "Villain has kept a 7 card hand", "They decided first, being first to play.")


func test_a_coin_flip_the_hero_won_says_so() -> void:
	var seed_won: int = -1
	for encounter_seed: int in range(1, 30):
		var engine: MmEngine = MmEngine.start(Scenario.setup(Rule.RANDOM_CHOOSER, encounter_seed))
		if engine.pending_decision().player_id == HERO:
			seed_won = encounter_seed
			break

	_open(Scenario.setup(Rule.RANDOM_CHOOSER, seed_won))

	assert_eq(_overlay.heading_text(), "You won the coin flip")


func test_with_no_choice_to_make_it_opens_on_the_hand_and_says_who_plays_first() -> void:
	_open(Scenario.setup(Rule.VILLAIN_STARTS))

	assert_true(_presenter.snapshot().decision is KeepOrMulliganDecision)
	assert_eq(_overlay.under_heading_text(), "The Villain plays first")
	assert_eq(_overlay.heading_text(), "", "No mulligan has cost a card (A396).")
	assert_eq(_overlay.button_texts(), ["Keep 7", "Mulligan"] as Array[String])


func test_it_covers_everything_right_of_the_sidebar_and_the_hands_strip_is_empty_under_it() -> void:
	_open(Scenario.setup())
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)

	assert_eq(_overlay.position, Vector2(regions["sidebar"].end.x, 0))
	assert_eq(_overlay.size, Vector2(SCREEN.x - regions["sidebar"].end.x, SCREEN.y))
	assert_eq(_overlay.mouse_filter, Control.MOUSE_FILTER_STOP, "Nothing under it takes the mouse.")
	assert_gt(_overlay.get_index(), _screen.info_panel().get_index(), "It is over the Info Panel.")
	assert_gt(_overlay.get_index(), _screen.stack_window().get_index())
	assert_lt(_overlay.get_index(), _screen.pause_menu().get_index())
	for card: MmObjectView in _presenter.snapshot().view.hand:
		assert_null(_screen.face_of(card.id), "The overlay holds the cards (A384).")
		assert_not_null(_overlay.face_of(card.id))
	assert_false(_screen.press_hand(regions["hero_hand"].get_center(), false))
	assert_eq(_screen.info_panel().prompt_text(), "", "The overlay says it all.")


func test_the_cards_are_drawn_large_in_the_hand_order_fanned_as_the_layout_says() -> void:
	_open(Scenario.setup())
	var cards: Array[int] = _screen.hand_order().cards()
	var places: Array[Rect2] = EncounterLayout.opening_hand_cards(7, 7, Rect2(Vector2.ZERO, _overlay.size))
	var turns: Array[float] = EncounterLayout.opening_hand_turns(7, 7)

	assert_eq(_overlay.shown_ids().size(), 7)
	for index: int in 7:
		var face: CardFace = _overlay.face_of(_overlay.shown_ids()[index])
		assert_eq(_card_id(_overlay.shown_ids()[index]), cards[index])
		assert_eq(face.position, places[index].position)
		assert_almost_eq(face.size.y, places[index].size.y, 0.01)
		assert_almost_eq(face.rotation, turns[index], 0.0001)
		assert_almost_eq(face.pivot_offset, Vector2(face.size.x / 2.0, face.size.y), Vector2(0.01, 0.01), "It turns about the middle of its bottom edge, as in the hand.")
		assert_eq(face.mouse_filter, Control.MOUSE_FILTER_IGNORE, "The overlay works out which card the cursor is on.")
		assert_eq(face.get_index(), index, "Each lies over the one to its left.")
		assert_false(_overlay.can_go_down(_overlay.shown_ids()[index]), "Nothing to click while keeping or mulliganing.")
		assert_null(BorderEffects.glow_color(face))


func test_a_hand_of_nine_is_drawn_in_two_rows() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.opening_hand_size = 9

	_open(setup)

	var ids: Array[int] = _overlay.shown_ids()
	assert_eq(ids.size(), 9)
	assert_eq(_overlay.face_of(ids[4]).position.y, _overlay.face_of(ids[0]).position.y)
	assert_gt(_overlay.face_of(ids[5]).position.y, _overlay.face_of(ids[0]).position.y)
	assert_eq(_overlay.button_texts(), ["Keep 9", "Mulligan"] as Array[String])


func test_keeping_seven_ends_the_pregame_and_the_hand_goes_to_its_strip() -> void:
	_open(Scenario.setup())

	_press("Keep 7")

	assert_gt(_presenter.snapshot().view.game_turn, 0)
	assert_false(_overlay.visible, "Nothing fades in a test (A369).")
	assert_eq(_overlay.shown_ids(), [] as Array[int])
	for card: MmObjectView in _presenter.snapshot().view.hand:
		assert_not_null(_screen.face_of(card.id))


func test_a_mulligan_shows_the_new_hand_and_counts_the_cards_it_cost() -> void:
	_open(Scenario.setup())
	var first: Array[int] = _overlay.shown_ids()

	_press("Mulligan")

	assert_true(_presenter.snapshot().decision is KeepOrMulliganDecision)
	assert_eq(_overlay.shown_ids().size(), 7)
	assert_ne(_overlay.shown_ids(), first)
	for index: int in 7:
		assert_eq(_card_id(_overlay.shown_ids()[index]), _screen.hand_order().cards()[index])
	assert_eq(_overlay.heading_text(), "Mulligans taken: 1")
	assert_eq(_overlay.button_texts(), ["Keep 6", "Mulligan"] as Array[String])


func test_a_free_mulligan_says_so_and_costs_nothing() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.free_mulligans = 1
	_open(setup)
	assert_eq(_overlay.button_texts(), ["Keep 7", "Free Mulligan"] as Array[String])

	_press("Free Mulligan")

	assert_eq(_overlay.heading_text(), "")
	assert_eq(_overlay.button_texts(), ["Keep 7", "Mulligan"] as Array[String])
	_press("Mulligan")
	assert_eq(_overlay.heading_text(), "Mulligans taken: 1")
	assert_eq(_overlay.button_texts(), ["Keep 6", "Mulligan"] as Array[String])


func test_keeping_a_hand_that_owes_a_card_asks_for_it_with_confirm_closed() -> void:
	_open(Scenario.setup())
	_press("Mulligan")

	_press("Keep 6")

	assert_true(_presenter.snapshot().decision is ChooseCardsToBottomDecision)
	assert_eq(_overlay.heading_text(), "Put 1 card on the bottom")
	assert_eq(_overlay.under_heading_text(), "You play first", "One card has no order to explain.")
	assert_eq(_overlay.button_texts(), ["Confirm"] as Array[String], "Keeping is final (A406).")
	assert_true(_overlay.button("Confirm").disabled)
	assert_eq(_overlay.shown_ids().size(), 7)
	for id: int in _overlay.shown_ids():
		assert_eq(BorderEffects.glow_color(_overlay.face_of(id)), GREEN)
		assert_true(_overlay.can_go_down(id))
	assert_true(_screen.undo_button().disabled, "Nothing to take back, and keeping cannot be undone.")


func test_a_clicked_card_leaves_the_row_and_undo_brings_it_back_to_its_place() -> void:
	_open(Scenario.setup())
	_press("Mulligan")
	_press("Keep 6")
	var before: Array[int] = _overlay.shown_ids()
	var chosen: int = before[2]

	_click_card(chosen)

	var after: Array[int] = before.duplicate()
	after.erase(chosen)
	assert_eq(_overlay.shown_ids(), after, "It vanishes and the row closes up.")
	assert_null(_overlay.face_of(chosen))
	assert_false(_overlay.can_go_down(chosen), "A card that has left the row takes no click.")
	assert_eq(_overlay.face_of(after[0]).position, EncounterLayout.opening_hand_cards(7, 6, Rect2(Vector2.ZERO, _overlay.size))[0].position)
	assert_false(_overlay.button("Confirm").disabled)
	assert_false(_screen.undo_button().disabled)
	_overlay.stop_hovering()
	for id: int in after:
		assert_false(_overlay.can_go_down(id), "Enough are down: a click does nothing.")
		assert_null(BorderEffects.glow_color(_overlay.face_of(id)))
	_click_card(after[0])
	assert_eq(_overlay.shown_ids(), after)
	_overlay.stop_hovering()
	assert_true(_presenter.snapshot().decision is ChooseCardsToBottomDecision, "Nothing is answered yet.")

	_screen.undo_button().pressed.emit()

	assert_eq(_overlay.shown_ids(), before)
	assert_true(_overlay.button("Confirm").disabled)
	assert_true(_screen.undo_button().disabled)
	_click_card(chosen)
	_screen.press_key(KEY_Z)
	assert_eq(_overlay.shown_ids(), before, "Z undoes too.")


func test_confirm_puts_the_clicked_cards_down_in_the_order_clicked() -> void:
	_open(Scenario.setup())
	_press("Mulligan")
	_press("Mulligan")
	_press("Keep 5")
	assert_eq(_overlay.heading_text(), "Put 2 cards on the bottom")
	assert_eq(_overlay.under_heading_text(), "The last card clicked -> bottom of library")
	var first: int = _overlay.shown_ids()[4]
	var second: int = _overlay.shown_ids()[0]
	var kept: Array[int] = []
	for id: int in _overlay.shown_ids():
		if id != first and id != second:
			kept.append(_card_id(id))

	_click_card(first)
	assert_true(_overlay.button("Confirm").disabled, "One more to go.")
	_click_card(second)
	assert_eq(_screen.card_picks().answer(), [first, second])
	_press("Confirm")

	assert_gt(_presenter.snapshot().view.game_turn, 0, "Both players have kept.")
	assert_false(_overlay.visible)
	assert_eq(_screen.hand_order().cards(), kept, "The five that stayed, in their order.")


func test_space_confirms_the_cards_put_down_once_there_are_enough() -> void:
	_open(Scenario.setup())
	_press("Mulligan")
	_press("Keep 6")

	_screen.press_key(KEY_SPACE)
	assert_true(_presenter.snapshot().decision is ChooseCardsToBottomDecision, "None is down yet.")
	_click_card(_overlay.shown_ids()[0])
	_screen.press_key(KEY_SPACE)

	assert_gt(_presenter.snapshot().view.game_turn, 0)


func test_a_hand_mulliganed_to_nothing_is_kept_without_asking_and_all_put_down_in_order() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.opening_hand_size = 2
	_open(setup)

	_press("Mulligan")
	assert_eq(_overlay.button_texts(), ["Keep 1", "Mulligan"] as Array[String])
	_press("Mulligan")

	assert_true(_presenter.snapshot().decision is ChooseCardsToBottomDecision, "It is not asked to keep nothing.")
	assert_eq(_overlay.heading_text(), "Put 2 cards on the bottom")
	var ids: Array[int] = _overlay.shown_ids()
	_click_card(ids[1])
	_click_card(ids[0])
	assert_eq(_overlay.shown_ids(), [] as Array[int])
	_press("Confirm")
	assert_gt(_presenter.snapshot().view.game_turn, 0)
	assert_eq(_presenter.snapshot().view.hand.size(), 0)


func test_while_the_villain_decides_there_are_no_buttons_and_the_overlay_says_so() -> void:
	var agent: SlowAgent = SlowAgent.new()
	agent.delay_msec = 100
	_open(Scenario.setup(), agent)

	_press_without_waiting("Mulligan")

	assert_true(_presenter.snapshot().is_villain_thinking)
	assert_true(_overlay.is_open())
	assert_eq(_overlay.button_texts(), [] as Array[String])
	assert_eq(_overlay.villain_text(), "Villain is deciding…")
	assert_eq(_overlay.shown_ids().size(), 7, "The Hero's hand stays up.")
	_presenter.wait_until_idle()
	assert_eq(_overlay.villain_text(), "Villain has kept a 7 card hand")
	assert_eq(_overlay.button_texts(), ["Keep 6", "Mulligan"] as Array[String])


func test_it_says_how_many_mulligans_the_villain_has_taken() -> void:
	var agent: MulliganAgent = MulliganAgent.new()
	agent.mulligans = 2
	_open(Scenario.setup(Rule.VILLAIN_STARTS), agent)
	assert_eq(_overlay.villain_text(), "Villain has taken 1 mulligan", "Said as soon as they chose, before the hand is redrawn.")

	_press_without_waiting("Keep 7")

	assert_eq(_overlay.villain_text(), "Villain is deciding…", "Their new hand, once the Hero has kept.")
	assert_eq(_overlay.button_texts(), [] as Array[String], "The Hero has kept and owes nothing.")
	assert_true(_overlay.is_open(), "The overlay stays until the first turn (A388).")
	_presenter.wait_until_idle()
	assert_gt(_presenter.snapshot().view.game_turn, 0)
	assert_eq(_screen.opening_hand().villain_text(), "Villain has kept a 5 card hand", "Two mulligans, and each cost a card.")
	assert_false(_overlay.visible)


func test_the_emblems_windows_open_over_the_overlay() -> void:
	_open(Scenario.setup())

	_screen.player_panel(HERO).emblems_pressed.emit()

	assert_true(_screen.emblems_window(HERO).visible)
	assert_gt(_screen.emblems_window(HERO).get_index(), _overlay.get_index())
	assert_gt(_screen.emblems_window(VILLAIN).get_index(), _overlay.get_index())


func test_escape_opens_the_pause_menu_over_it_and_nothing_is_answered_while_paused() -> void:
	_open(Scenario.setup())
	_press("Mulligan")
	_press("Keep 6")
	var id: int = _overlay.shown_ids()[0]

	_screen.press_key(KEY_ESCAPE)

	assert_true(_screen.pause_menu().is_open())
	_click_card(id)
	assert_eq(_screen.card_picks().picked(), [] as Array[int])
	_overlay.confirmed.emit()
	_overlay.answered.emit(MULLIGAN)
	assert_true(_presenter.snapshot().decision is ChooseCardsToBottomDecision)
	_screen.press_key(KEY_ESCAPE)
	_click_card(id)
	assert_eq(_screen.card_picks().picked(), [id] as Array[int])


func test_a_button_answers_nothing_while_paused_and_nothing_once_the_pregame_is_over() -> void:
	_open(Scenario.setup())

	_screen.press_key(KEY_ESCAPE)
	_overlay.answered.emit(MULLIGAN)
	assert_eq(_presenter.snapshot().view.hand.size(), 7)
	assert_eq((_presenter.snapshot().decision as KeepOrMulliganDecision).mulligans_taken, 0, "Paused: no mulligan was taken.")
	_screen.press_key(KEY_ESCAPE)
	_press("Keep 7")
	assert_true(_presenter.snapshot().decision is PriorityDecision)
	var before: EncounterSnapshot = _presenter.snapshot()

	_overlay.answered.emit(0)
	_overlay.confirmed.emit()
	_overlay.card_clicked.emit(_presenter.snapshot().view.hand[0].id)

	assert_eq(_presenter.snapshot(), before, "A stray press from a frame that is gone answers nothing at priority.")
	assert_eq(_screen.info_panel().error_text(), "")


func test_confirming_before_enough_cards_are_down_sends_nothing() -> void:
	_open(Scenario.setup())
	_press("Mulligan")
	_press("Mulligan")
	_press("Keep 5")
	_click_card(_overlay.shown_ids()[0])
	var asked: EncounterSnapshot = _presenter.snapshot()

	_overlay.confirmed.emit()
	_screen.press_key(KEY_SPACE)

	assert_eq(_presenter.snapshot(), asked, "No answer was sent, so none was refused.")
	assert_eq(_screen.info_panel().error_text(), "")
	assert_eq(_screen.card_picks().picked().size(), 1)


func test_a_card_glows_white_under_the_cursor_and_goes_back_to_its_own_glow_after() -> void:
	_open(Scenario.setup())
	var first: int = _overlay.shown_ids()[0]
	var plain: CardFace = _overlay.face_of(first)

	_overlay.hover_at(_overlay.center_of(first))
	assert_eq(_overlay.hovered_id(), first)
	assert_eq(BorderEffects.glow_color(plain), Color.WHITE)
	assert_eq(_overlay.mouse_default_cursor_shape, Control.CURSOR_ARROW, "It answers nothing, so the cursor does not say it does.")
	_overlay.stop_hovering()
	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE)
	assert_null(BorderEffects.glow_color(plain))

	_press("Mulligan")
	_press("Keep 6")
	var id: int = _overlay.shown_ids()[0]
	var candidate: CardFace = _overlay.face_of(id)
	_overlay.hover_at(_overlay.center_of(id))
	assert_eq(BorderEffects.glow_color(candidate), Color.WHITE)
	assert_eq(_overlay.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
	_overlay.hover_at(Vector2(5, 5))
	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE, "Off every card.")
	assert_eq(BorderEffects.glow_color(candidate), GREEN)
	assert_eq(_overlay.mouse_default_cursor_shape, Control.CURSOR_ARROW)


func test_the_card_under_the_cursor_comes_to_the_front_and_stands_upright_to_be_read() -> void:
	_open(Scenario.setup())
	var ids: Array[int] = _overlay.shown_ids()
	var face: CardFace = _overlay.face_of(ids[1])
	var turn: float = EncounterLayout.opening_hand_turns(7, 7)[1]

	_overlay.hover_at(_overlay.center_of(ids[1]))

	assert_eq(face.z_index, 1, "Over the card to its right, which otherwise covers its corner.")
	assert_eq(_overlay.face_of(ids[2]).z_index, 0)
	assert_almost_eq(face.rotation, turn, 0.0001, "It does not jump.")
	_overlay.ease_cards(0.5)
	assert_almost_eq(face.rotation, turn / 2.0, 0.0001, "It eases upright.")
	_overlay.ease_cards(1.0)
	assert_almost_eq(face.rotation, 0.0, 0.0001)
	assert_almost_eq(_overlay.face_of(ids[2]).rotation, EncounterLayout.opening_hand_turns(7, 7)[2], 0.0001, "The rest stay as they were.")

	_overlay.hover_at(_overlay.center_of(ids[5]))

	assert_eq(face.z_index, 0)
	assert_eq(_overlay.face_of(ids[5]).z_index, 1)
	_overlay.ease_cards(1.0)
	assert_almost_eq(face.rotation, turn, 0.0001, "And it leans back into the fan.")
	assert_almost_eq(_overlay.face_of(ids[5]).rotation, 0.0, 0.0001)
	_overlay.stop_hovering()
	assert_eq(_overlay.face_of(ids[5]).z_index, 0)


func test_a_card_is_found_where_it_is_drawn_turned_as_it_is() -> void:
	_open(Scenario.setup())
	var ids: Array[int] = _overlay.shown_ids()
	var last: CardFace = _overlay.face_of(ids[6])
	# The top right corner of the rightmost card swings out past where it would stand upright.
	var swung: Vector2 = last.get_transform() * Vector2(last.size.x - 4.0, 4.0)
	var upright_corner: Vector2 = last.position + Vector2(last.size.x - 4.0, 4.0)

	assert_gt(swung.x, last.position.x + last.size.x, "Outside the card's own unturned box.")
	assert_eq(_overlay.card_at(swung), ids[6])
	assert_eq(_overlay.card_at(upright_corner), OpeningHandOverlay.NONE, "And where that corner would be if it stood upright, there is nothing.")
	assert_eq(_overlay.card_at(Vector2(5, 5)), OpeningHandOverlay.NONE)
	for id: int in ids:
		assert_eq(_overlay.card_at(_overlay.center_of(id)), id)


func test_where_two_cards_overlap_the_one_on_top_is_found_unless_the_other_is_already_under_the_cursor() -> void:
	_open(Scenario.setup())
	var ids: Array[int] = _overlay.shown_ids()
	var left: CardFace = _overlay.face_of(ids[2])
	var right: CardFace = _overlay.face_of(ids[3])
	# Just inside the left card's bottom right corner, which the card to its right covers.
	var shared: Vector2 = left.get_transform() * Vector2(left.size.x - 3.0, left.size.y - 12.0)
	assert_true(Rect2(Vector2.ZERO, right.size).has_point(right.get_transform().affine_inverse() * shared), "Both cards are there.")

	_overlay.hover_at(shared)
	assert_eq(_overlay.hovered_id(), ids[3], "Coming from nowhere, it is the one drawn on top.")

	_overlay.hover_at(_overlay.center_of(ids[2]))
	_overlay.hover_at(shared)
	assert_eq(_overlay.hovered_id(), ids[2], "Coming from the left card, which is in front while the cursor is on it, it stays that one.")


func test_a_redraw_of_the_same_cards_lights_the_one_under_the_cursor_again() -> void:
	_open(Scenario.setup())
	var id: int = _overlay.shown_ids()[2]
	_overlay.hover_at(_overlay.center_of(id))
	var old_face: CardFace = _overlay.face_of(id)

	_screen._redraw()

	var face: CardFace = _overlay.face_of(id)
	assert_ne(face, old_face, "The frame was built again.")
	assert_eq(_overlay.hovered_id(), id)
	assert_eq(BorderEffects.glow_color(face), Color.WHITE, "The new face is lit, not just remembered as lit.")
	assert_eq(face.z_index, 1)
	_overlay.stop_hovering()


func test_the_white_glow_eases_in_and_out_and_a_redraw_does_not_ease_it_in_again() -> void:
	_open(Scenario.setup())
	_screen.set_ease_seconds(0.2)
	_screen._redraw()
	_overlay.set_process(false)
	var id: int = _overlay.shown_ids()[2]

	_overlay.hover_at(_overlay.center_of(id))

	assert_eq(_overlay.face_of(id).get_node(BorderEffects.GLOW).modulate.a, 0.0, "It eases in.")
	await wait_seconds(0.3)
	_screen._redraw()
	assert_eq(_overlay.face_of(id).get_node(BorderEffects.GLOW).modulate.a, 1.0, "Lit as it was.")

	_overlay.stop_hovering()

	assert_null(BorderEffects.glow_color(_overlay.face_of(id)))
	assert_eq(_overlay.face_of(id).get_child(-1).name, StringName(BorderEffects.LEAVING), "It eases out.")
	await wait_seconds(0.3)


func test_the_pointing_hand_goes_when_the_card_under_the_cursor_is_put_down_and_none_takes_its_place() -> void:
	_open(Scenario.setup())
	_press("Mulligan")
	_press("Keep 6")
	var last: CardFace = _overlay.face_of(_overlay.shown_ids()[6])
	# Near the right edge of the rightmost card, where nothing will be once it has gone.
	var at: Vector2 = last.get_transform() * Vector2(last.size.x - 10.0, last.size.y / 2.0)
	_overlay.hover_at(at)
	assert_eq(_overlay.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)

	_overlay.click_at(at)

	assert_eq(_overlay.card_at(at), OpeningHandOverlay.NONE, "The row closed up toward the middle, away from the cursor.")
	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE)
	assert_eq(_overlay.mouse_default_cursor_shape, Control.CURSOR_ARROW)
	_overlay.stop_hovering()


func test_closing_forgets_the_card_the_cursor_was_on() -> void:
	_open(Scenario.setup())
	_overlay.hover_at(_overlay.center_of(_overlay.shown_ids()[0]))

	_press("Keep 7")

	assert_false(_overlay.visible)
	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE)


func test_a_redraw_finds_the_card_under_the_resting_cursor_again() -> void:
	_open(Scenario.setup())
	_press("Mulligan")
	_press("Mulligan")
	_press("Keep 5")
	var at: Vector2 = _overlay.center_of(_overlay.shown_ids()[3])

	_overlay.click_at(at)

	assert_eq(_screen.card_picks().picked().size(), 1)
	var under: int = _overlay.card_at(at)
	assert_ne(under, OpeningHandOverlay.NONE, "The row closed up, and another card is under the cursor.")
	assert_eq(_overlay.hovered_id(), under, "Without the mouse moving.")
	assert_eq(BorderEffects.glow_color(_overlay.face_of(under)), Color.WHITE)
	assert_eq(_overlay.face_of(under).z_index, 1)
	_overlay.stop_hovering()
	_screen._redraw()
	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE, "Once the cursor has left, a redraw finds nothing.")


func test_a_real_cursor_lights_the_card_it_is_on_stands_it_upright_and_lets_it_go_for_a_button() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_open(Scenario.setup(), DefaultAnswerAgent.new(), window)
	var id: int = _overlay.shown_ids()[1]
	var face: CardFace = _overlay.face_of(id)

	window.push_input(_motion(_overlay.position + _overlay.center_of(id)))
	await wait_seconds(0.4)

	assert_eq(_overlay.hovered_id(), id)
	assert_eq(BorderEffects.glow_color(face), Color.WHITE)
	assert_eq(face.z_index, 1)
	assert_almost_eq(face.rotation, 0.0, 0.005, "It eased upright by itself.")

	window.push_input(_motion(_center(_overlay.button("Keep 7"))))
	await wait_seconds(0.4)

	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE, "On a button the cursor is on no card.")
	assert_null(BorderEffects.glow_color(face))
	assert_almost_eq(face.rotation, EncounterLayout.opening_hand_turns(7, 7)[1], 0.005, "And the card leans back into the fan.")

	window.push_input(_motion(_overlay.position + _overlay.center_of(id)))
	await wait_process_frames(2)
	assert_eq(_overlay.hovered_id(), id)
	window.push_input(_motion(EncounterLayout.regions(SCREEN)["hero_panel"].get_center()))
	await wait_process_frames(2)
	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE, "Nor in the sidebar.")


func test_the_overlay_fades_out_when_the_game_is_paced() -> void:
	_open(Scenario.setup(), DefaultAnswerAgent.new(), null, 0.05)
	_press("Mulligan")
	_press("Keep 6")
	_click_card(_overlay.shown_ids()[0])
	_press("Confirm")
	assert_true(_overlay.visible, "It fades out (A410).")
	assert_true(_overlay.is_closing())
	assert_false(_overlay.is_open())
	assert_eq(_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "And is out of the mouse's way at once.")
	assert_false(_screen._is_covered(Vector2(900, 500)))
	await wait_seconds(0.15)
	assert_false(_overlay.visible)


func test_an_overlay_is_hidden_and_stops_the_mouse_from_the_moment_it_is_made() -> void:
	var fresh: OpeningHandOverlay = OpeningHandOverlay.new()
	add_child_autofree(fresh)

	assert_false(fresh.visible)
	assert_false(fresh.is_open())
	assert_eq(fresh.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_null(fresh.scrim())
	fresh.close(0.05)
	assert_false(fresh.is_closing(), "There is nothing to fade away.")
	assert_eq(fresh.heading_text(), "")


func test_the_scrim_covers_the_whole_overlay_and_lets_the_mouse_through_to_it() -> void:
	_open(Scenario.setup())

	var scrim: ColorRect = _overlay.scrim()
	assert_eq(scrim.color, OpeningHandOverlay.SCRIM)
	assert_eq(scrim.size, _overlay.size)
	assert_eq(scrim.position, Vector2.ZERO)
	assert_eq(scrim.mouse_filter, Control.MOUSE_FILTER_IGNORE, "The overlay itself stops the mouse.")
	assert_eq(scrim.get_parent(), _overlay)
	assert_eq(_overlay.row().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_gt(_overlay.row().get_index(), scrim.get_index(), "The cards are over it.")


func test_the_words_are_centered_in_the_rows_the_layout_gives_them() -> void:
	_open(Scenario.setup(MmEncounterSetup.StartingPlayerRule.VILLAIN_STARTS))
	var parts: Dictionary[String, Rect2] = EncounterLayout.opening_hand(7, Rect2(Vector2.ZERO, _overlay.size))
	var labels: Dictionary[String, Label] = {
		"heading": _overlay.heading_label(), "under_heading": _overlay.under_heading_label(), "villain": _overlay.villain_label(),
	}

	for key: String in labels:
		var label: Label = labels[key]
		assert_eq(label.get_parent(), _overlay, key)
		assert_almost_eq(label.position, parts[key].position, Vector2(0.001, 0.001), key)
		assert_almost_eq(label.size, parts[key].size, Vector2(0.001, 0.001), key)
		assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, key)
		assert_eq(label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, key)
		assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, key)
	assert_eq(_overlay.villain_label().get_theme_color("font_color"), OpeningHandOverlay.VILLAIN_COLOR)
	assert_eq(_overlay.heading_label().get_theme_color("font_color"), Color.WHITE)
	assert_gt(_overlay.heading_label().get_theme_font_size("font_size"), _overlay.under_heading_label().get_theme_font_size("font_size"),
			"The heading is the largest line.")


func test_the_buttons_stand_side_by_side_about_the_middle_and_say_what_they_do() -> void:
	_open(Scenario.setup(Rule.HERO_CHOOSES))
	var inside: Rect2 = Rect2(Vector2.ZERO, _overlay.size)
	var size: Vector2 = EncounterLayout.OPENING_BUTTON
	var middle: float = inside.get_center().x

	var play: Button = _overlay.button("Play first")
	var draw: Button = _overlay.button("Draw first")
	var choice_row: Rect2 = EncounterLayout.opening_hand(0, inside)["middle"]
	assert_eq(play.text, "Play first")
	assert_eq(draw.text, "Draw first")
	assert_almost_eq(play.size, size, Vector2(0.01, 0.01))
	assert_almost_eq(draw.size, size, Vector2(0.01, 0.01))
	assert_almost_eq(play.position, Vector2(middle - size.x - 12.0, choice_row.position.y), Vector2(0.01, 0.01))
	assert_almost_eq(draw.position, Vector2(middle + 12.0, choice_row.position.y), Vector2(0.01, 0.01))
	assert_eq(play.focus_mode, Control.FOCUS_NONE, "Space must pass, never press a button.")
	assert_eq(play.get_parent(), _overlay)

	_press("Play first")
	_press("Mulligan")
	var keep_row: Rect2 = EncounterLayout.opening_hand(7, inside)["buttons"]
	assert_eq(_overlay.button("Keep 6").text, "Keep 6")
	assert_almost_eq(_overlay.button("Keep 6").position, Vector2(middle - size.x - 12.0, keep_row.position.y), Vector2(0.01, 0.01))
	assert_almost_eq(_overlay.button("Mulligan").position, Vector2(middle + 12.0, keep_row.position.y), Vector2(0.01, 0.01))
	_press("Keep 6")
	var confirm: Button = _overlay.button("Confirm")
	assert_almost_eq(confirm.size, size, Vector2(0.01, 0.01))
	assert_almost_eq(confirm.get_rect().get_center(), keep_row.get_center(), Vector2(0.01, 0.01), "Alone, it is in the middle.")


func test_every_button_is_shaded_in_its_own_color_and_confirm_is_gray_until_enough_cards_are_down() -> void:
	_open(Scenario.setup(Rule.VILLAIN_STARTS))
	_is_shaded("Keep 7", OpeningHandOverlay.KEEP_COLOR)
	_is_shaded("Mulligan", OpeningHandOverlay.MULLIGAN_COLOR)
	assert_gt(OpeningHandOverlay.KEEP_COLOR.b, OpeningHandOverlay.KEEP_COLOR.r, "Blue.")
	assert_gt(OpeningHandOverlay.MULLIGAN_COLOR.r, OpeningHandOverlay.MULLIGAN_COLOR.g, "Orange.")
	assert_gt(OpeningHandOverlay.MULLIGAN_COLOR.g, OpeningHandOverlay.MULLIGAN_COLOR.b, "Orange.")

	_press("Mulligan")
	_press("Keep 6")
	_is_shaded("Confirm", OpeningHandOverlay.CONFIRM_COLOR)
	assert_gt(OpeningHandOverlay.CONFIRM_COLOR.g, OpeningHandOverlay.CONFIRM_COLOR.r, "Green.")
	assert_gt(OpeningHandOverlay.CONFIRM_COLOR.g, OpeningHandOverlay.CONFIRM_COLOR.b, "Green.")
	var confirm: Button = _overlay.button("Confirm")
	assert_true(confirm.disabled, "A card is still owed,")
	assert_eq(confirm.get_theme_stylebox("disabled"), ButtonShading.box(ButtonShading.DISABLED, roundi(confirm.size.y)), "so it is gray.")

	_open(Scenario.setup(Rule.HERO_CHOOSES))
	_is_shaded("Play first", OpeningHandOverlay.CHOICE_COLOR)
	_is_shaded("Draw first", OpeningHandOverlay.CHOICE_COLOR)


## The button reading [param text] is drawn in [param color], and is no larger or smaller
## under the cursor or held down.
func _is_shaded(text: String, color: Color) -> void:
	var shaded: Button = _overlay.button(text)
	var height: int = roundi(shaded.size.y)
	var size_before: Vector2 = shaded.size
	assert_eq(shaded.get_theme_stylebox("normal"), ButtonShading.box(color, height), text)
	assert_eq(shaded.get_theme_stylebox("hover"), ButtonShading.box(ButtonShading.hover_color(color), height), text)
	assert_eq(shaded.get_theme_stylebox("pressed"), ButtonShading.box(ButtonShading.pressed_color(color), height), text)
	assert_eq(shaded.size, size_before, "%s keeps the size the layout gave it." % text)
	assert_eq(shaded.scale, Vector2.ONE)


func test_on_a_taller_screen_the_words_and_buttons_are_larger_in_step() -> void:
	_open(Scenario.setup())
	var heading: int = _overlay.heading_label().get_theme_font_size("font_size")
	var under: int = _overlay.under_heading_label().get_theme_font_size("font_size")
	var villain: int = _overlay.villain_label().get_theme_font_size("font_size")

	_screen.size = Vector2(2560, 1440)

	var scale: float = 1440.0 / 1080.0
	assert_almost_eq(_overlay.button("Keep 7").size, EncounterLayout.OPENING_BUTTON * scale, Vector2(0.01, 0.01))
	assert_gt(_overlay.heading_label().get_theme_font_size("font_size"), heading)
	assert_gt(_overlay.under_heading_label().get_theme_font_size("font_size"), under)
	assert_gt(_overlay.villain_label().get_theme_font_size("font_size"), villain)
	var middle: float = _overlay.size.x / 2.0
	assert_almost_eq(_overlay.button("Keep 7").position.x + _overlay.button("Keep 7").size.x, middle - 12.0 * scale, 0.01)
	_press("Mulligan")
	_press("Keep 6")
	assert_almost_eq(_overlay.button("Confirm").size, EncounterLayout.OPENING_BUTTON * scale, Vector2(0.01, 0.01))
	assert_almost_eq(_overlay.button("Confirm").get_rect().get_center().x, middle, 0.01)


func test_a_redraw_frees_the_frame_it_replaces_and_closing_leaves_nothing_behind() -> void:
	_open(Scenario.setup())
	var old_face: CardFace = _overlay.face_of(_overlay.shown_ids()[0])
	var old_heading: Label = _overlay.heading_label()

	_screen._redraw()
	await wait_process_frames(2)

	assert_false(is_instance_valid(old_face), "Freed, not left as an orphan.")
	assert_false(is_instance_valid(old_heading))
	_press("Keep 7")
	assert_false(_overlay.visible)
	assert_null(_overlay.row())
	assert_null(_overlay.heading_label())
	assert_null(_overlay.under_heading_label())
	assert_null(_overlay.villain_label())
	assert_eq(_overlay.heading_text(), "")
	assert_eq(_overlay.under_heading_text(), "")
	assert_eq(_overlay.villain_text(), "")
	assert_eq(_overlay.button_texts(), [] as Array[String])
	assert_eq(_overlay.get_child_count(), 0)


func test_while_it_fades_out_nothing_on_it_takes_the_mouse_and_then_it_is_empty() -> void:
	_open(Scenario.setup(), DefaultAnswerAgent.new(), null, 0.1)
	_press("Mulligan")
	_press("Keep 6")
	_click_card(_overlay.shown_ids()[0])
	var left: CardFace = _overlay.face_of(_overlay.shown_ids()[1])
	var confirm: Button = _overlay.button("Confirm")

	_press("Confirm")

	assert_true(_overlay.is_closing())
	assert_eq(confirm.mouse_filter, Control.MOUSE_FILTER_IGNORE, "A click meant for the board must not land on a fading button.")
	_overlay.hover_at(_overlay.center_of(_overlay.shown_ids()[1]))
	assert_eq(_overlay.hovered_id(), OpeningHandOverlay.NONE, "Nor does a fading card answer to the cursor.")
	assert_null(BorderEffects.glow_color(left))
	assert_eq(_overlay.modulate.a, 1.0, "It starts whole.")
	await wait_seconds(0.05)
	assert_lt(_overlay.modulate.a, 1.0, "And fades.")
	assert_gt(_overlay.modulate.a, 0.0)
	assert_true(_overlay.visible)
	await wait_seconds(0.12)
	assert_false(_overlay.visible)
	assert_false(_overlay.is_closing(), "Done.")
	assert_null(_overlay.row())
	assert_eq(_overlay.get_child_count(), 0)


func test_an_overlay_shown_again_while_it_fades_out_is_whole_and_stays() -> void:
	_open(Scenario.setup(), DefaultAnswerAgent.new(), null, 0.1)
	var asked: EncounterSnapshot = _presenter.snapshot()
	var area: Rect2 = Rect2(_overlay.position, _overlay.size)
	await wait_seconds(0.15)
	_press("Keep 7")
	assert_true(_overlay.is_closing())
	await wait_seconds(0.03)
	var again: OpeningHand = OpeningHand.new()
	again.read(asked)

	_overlay.show_frame(again, asked, CardPicks.new(), _screen.hand_order().cards(), area)

	assert_true(_overlay.is_open())
	assert_false(_overlay.is_closing())
	assert_eq(_overlay.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_overlay.modulate.a, 1.0)
	await wait_seconds(0.15)
	assert_true(_overlay.visible, "The fade that was under way was stopped.")
	assert_eq(_overlay.modulate.a, 1.0)
	assert_eq(_overlay.button_texts(), ["Keep 7", "Mulligan"] as Array[String])
	_overlay.close(0.0)


func test_real_clicks_reach_the_overlays_buttons_and_cards_with_the_cursor_resting_on_them() -> void:
	# The first build of the hover glow raised an error on every real click: taking a card
	# from under the cursor told it the cursor had left while it was being removed.
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_open(Scenario.setup(), DefaultAnswerAgent.new(), window)

	await _real_click(window, _center(_overlay.button("Mulligan")))
	_presenter.wait_until_idle()
	assert_eq(_overlay.heading_text(), "Mulligans taken: 1")
	await _real_click(window, _center(_overlay.button("Mulligan")))
	_presenter.wait_until_idle()
	await _real_click(window, _center(_overlay.button("Keep 5")))
	_presenter.wait_until_idle()
	assert_true(_presenter.snapshot().decision is ChooseCardsToBottomDecision)

	# Only the left button going down puts a card down: not the right one, and not a release.
	var first: Vector2 = _overlay.position + _overlay.center_of(_overlay.shown_ids()[0])
	window.push_input(_motion(first))
	await wait_process_frames(2)
	for is_down: bool in [true, false]:
		var other: InputEventMouseButton = InputEventMouseButton.new()
		other.button_index = MOUSE_BUTTON_RIGHT
		other.pressed = is_down
		other.position = first
		other.global_position = first
		window.push_input(other)
	assert_eq(_screen.card_picks().picked().size(), 0, "A right-click is left free for the inspector.")
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = first
	down.global_position = first
	window.push_input(down)
	assert_eq(_screen.card_picks().picked().size(), 1, "It goes down as the button does.")
	var up: InputEventMouseButton = down.duplicate() as InputEventMouseButton
	up.pressed = false
	window.push_input(up)
	assert_eq(_screen.card_picks().picked().size(), 1, "And letting go is not a second click.")
	_screen.undo()

	for click: int in 2:
		var id: int = _overlay.shown_ids()[0]
		var at: Vector2 = _overlay.position + _overlay.center_of(id)
		window.push_input(_motion(at))
		await wait_process_frames(2)
		assert_eq(BorderEffects.glow_color(_overlay.face_of(id)), Color.WHITE, "The cursor is resting on it.")
		await _real_click(window, at)
		assert_eq(_screen.card_picks().picked().size(), click + 1)
	assert_eq(_overlay.shown_ids().size(), 5)
	await _real_click(window, _center(_overlay.button("Confirm")))
	_presenter.wait_until_idle()
	assert_gt(_presenter.snapshot().view.game_turn, 0)


func test_a_real_press_where_the_hand_would_be_reaches_nothing_under_the_overlay() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_open(Scenario.setup(), DefaultAnswerAgent.new(), window)
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)
	var before: EncounterSnapshot = _presenter.snapshot()

	await _real_click(window, regions["hero_hand"].get_center())
	await _real_click(window, regions["battlefield"].get_center() + Vector2(0, -300))

	assert_eq(_presenter.snapshot(), before)
	assert_false(_screen.drag_card().is_pressed())
	assert_true(_screen._is_covered(regions["hero_hand"].get_center()))
	assert_false(_screen._is_covered(regions["hero_panel"].get_center()), "The sidebar is not under it.")


func test_a_real_click_on_the_emblems_button_opens_its_window_while_the_overlay_is_up() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.emblems = [Scenario.vanilla("Boon")] as Array[MmCardDefinition]
	_open(setup, DefaultAnswerAgent.new(), window)
	assert_false(_screen.emblems_window(HERO).visible)

	await _real_click(window, _center(_screen.player_panel(HERO).emblems_button()))

	assert_true(_screen.emblems_window(HERO).visible)
	await _real_click(window, _center(_screen.emblems_window(HERO).close_button()))
	assert_false(_screen.emblems_window(HERO).visible, "And its window takes clicks over the scrim.")


func _open(setup: MmEncounterSetup, agent: MmAgent = DefaultAnswerAgent.new(), parent: Node = null, fade_seconds: float = 0.0) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	if parent == null:
		add_child_autofree(_screen)
	else:
		parent.add_child(_screen)
	_screen.size = SCREEN
	_screen.face_motion().seconds = fade_seconds
	_presenter = EncounterPresenter.new(setup, agent)
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	_overlay = _screen.opening_overlay()


func _press(text: String) -> void:
	_press_without_waiting(text)
	_presenter.wait_until_idle()


func _press_without_waiting(text: String) -> void:
	assert_not_null(_overlay.button(text), "There is a button reading \"%s\"." % text)
	if _overlay.button(text) != null:
		_overlay.button(text).pressed.emit()


## Clicks the middle of the card, as the mouse would: the overlay finds the card there.
func _click_card(object_id: int) -> void:
	if _overlay.face_of(object_id) != null:
		_overlay.click_at(_overlay.center_of(object_id))


func _card_id(object_id: int) -> int:
	for card: MmObjectView in _presenter.snapshot().view.hand:
		if card.id == object_id:
			return card.card_id
	return -1


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


func _real_click(window: SubViewport, at: Vector2) -> void:
	window.push_input(_motion(at))
	await wait_process_frames(2)
	for is_down: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_down
		click.position = at
		click.global_position = at
		window.push_input(click)
		await wait_process_frames(1)
