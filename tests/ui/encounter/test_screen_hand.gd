extends GutTest
## Playing from the hand on the Encounter Screen (13e-1): a card is dragged out of the hand
## or double-clicked to play it, and dragged along the hand to rearrange it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SlowAgent := preload("res://tests/ui/encounter/support/slow_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const FIELD: Vector2 = Vector2(1000, 500)

var _presenter: EncounterPresenter
var _screen: EncounterScreen
var _regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)


func after_each() -> void:
	await wait_process_frames(2)


func test_the_hand_is_drawn_in_the_heros_order_and_a_drawn_card_joins_at_the_right() -> void:
	_open(_forests_and_bears())
	var before: Array[int] = _screen.hand_order().cards()
	assert_eq(before.size(), 7)
	assert_true(_is_left_to_right(before))
	var first: Control = _face(before[0])
	assert_eq(first.pivot_offset, Vector2(first.size.x / 2.0, first.size.y), "A card turns about the middle of its bottom edge.")
	assert_eq(first.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_almost_eq(first.rotation, EncounterLayout.fan_angle(0, 7), 0.0001)
	assert_eq(first.position, EncounterLayout.hand_rest(7, _regions["hero_hand"], first.size)[0])

	_screen.hand_order().place(before[6], 0)
	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	var moved: Array[int] = _screen.hand_order().cards()
	assert_eq(moved[0], before[6])
	assert_true(_is_left_to_right(moved), "A redraw draws the hand in the Hero's order.")
	var turn: int = _presenter.snapshot().view.game_turn
	_pass_until(func() -> bool:
		return _presenter.snapshot().view.game_turn > turn + 1 and _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN)
	var later: Array[int] = _screen.hand_order().cards()
	assert_eq(later.size(), 8, "A card was drawn.")
	assert_eq(later.slice(0, 7), moved)
	assert_true(_is_left_to_right(later))


func test_one_click_on_a_card_does_nothing() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	var before: EncounterSnapshot = _presenter.snapshot()

	assert_true(_screen.press_hand(_on(forest), false), "The press landed on a card.")
	_screen.release_hand(_on(forest))

	assert_eq(_presenter.snapshot(), before, "A371.")
	assert_false(_screen.drag_card().is_pressed())
	assert_null(_screen.lifted_face())
	assert_null(ClickCatcher.of(_face(forest)))
	assert_eq(_screen.info_panel().error_text(), "")


func test_a_press_off_the_hand_is_not_a_press_on_a_card() -> void:
	_open(_forests_and_bears())

	assert_false(_screen.press_hand(FIELD, false))
	assert_false(_screen.press_hand(FIELD, true))
	assert_eq(_screen.hand_card_at(FIELD), DragCard.NONE)
	assert_false(_screen.drag_card().is_pressed())
	assert_eq(_screen.hand_card_at(_on(_card("Forest"))), _card("Forest"))
	var first: int = _screen.hand_order().cards()[0]
	assert_eq(_screen.hand_card_at(_face(first).position + Vector2(30, -5)), first, "A card is a little bigger to the mouse than it looks.")
	assert_eq(_screen.hand_card_at(_face(first).position + Vector2(30, -9)), first, "Above it too, where it rises to under the cursor.")
	var rise: float = _face(first).size.y * EncounterLayout.HAND_RISE
	assert_eq(_screen.hand_card_at(_face(first).position + Vector2(30, -rise - 7.0)), first)
	assert_eq(_screen.hand_card_at(_face(first).position + Vector2(30, -rise - 9.0)), DragCard.NONE, "But no higher than it rises.")


func test_a_double_click_plays_a_land_and_casts_a_spell() -> void:
	_open(_forests_and_bears())

	_screen.press_hand(_on(_card("Forest")), true)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1)
	assert_false(_screen.drag_card().is_pressed(), "A double-click starts no drag.")

	_screen.press_hand(_on(_card("Bear")), true)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Bear").size(), 1, "The Bear was cast, and the Hero's own spell is passed for them.")


func test_a_double_click_on_a_card_that_cannot_be_played_does_nothing() -> void:
	_open(_forests_and_bears())
	_screen.press_hand(_on(_card("Forest")), true)
	_presenter.wait_until_idle()
	var second: int = _card("Forest")
	var before: EncounterSnapshot = _presenter.snapshot()
	assert_null(BorderEffects.glow_color(_face(second)), "One land a turn.")

	assert_true(_screen.press_hand(_on(second), true))

	assert_eq(_presenter.snapshot(), before)
	assert_eq(_screen.info_panel().error_text(), "")
	assert_false(_screen.option_menu().is_open())
	assert_true(_screen.drag_card().is_pressed(), "But it is a press, so a second try at a drag is not swallowed.")
	_screen.cancel_drag()


func test_a_press_becomes_a_drag_after_three_pixels_and_lifts_the_cards_own_face() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	var face: Control = _face(forest)
	var at: Vector2 = _on(forest)
	var grabbed: Vector2 = at - face.position
	var row: Node = face.get_parent()

	face.z_index = 1
	_screen.press_hand(at, false)
	_screen.drag_to(at + Vector2(2, 0))
	assert_null(_screen.lifted_face())
	assert_eq(face.get_parent(), row)
	_screen.drag_to(at + Vector2(0, -3))
	assert_eq(face.z_index, 0, "A card that had risen under the cursor must not be drawn over the Option Menu.")
	assert_eq((face.get_parent() as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)

	assert_eq(_screen.lifted_face(), face, "Nothing was rebuilt: it is the same face.")
	assert_ne(face.get_parent(), row)
	assert_gt(face.get_parent().get_index(), _screen.stack_window().get_index(), "Over the windows")
	assert_lt(face.get_parent().get_index(), _screen.option_menu().get_index(), "and under the Option Menu.")
	assert_eq(face.rotation, 0.0, "Upright.")
	assert_eq(face.position, at + Vector2(0, -3) - grabbed, "Under the cursor as it was grabbed.")
	assert_eq(_screen.face_of(_seen(forest).id), face)
	assert_eq(_screen.hand_card_at(at), DragCard.NONE if _row_cards().is_empty() else _screen.hand_card_at(at))
	assert_false(_row_cards().has(forest), "It is out of the row.")
	assert_eq(_row_cards().size(), 6)
	_screen.drag_to(Vector2(1200, 300))
	assert_eq(face.position, Vector2(1200, 300) - grabbed)
	_screen.cancel_drag()


func test_the_hand_makes_room_where_the_held_card_hovers_and_closes_up_above_the_strip() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var hand: Rect2 = _regions["hero_hand"]
	var size: Vector2 = _face(cards[0]).size
	var seven: Array[Vector2] = EncounterLayout.hand_rest(7, hand, size)
	_screen.press_hand(_on(cards[3]), false)

	_screen.drag_to(seven[1] + Vector2(size.x / 2.0, 60))
	assert_eq(_screen.drag_card().gap(), 1)
	assert_eq(_screen.hand_places(Vector2.ZERO), EncounterLayout.hand_row(6, 1, hand, size))
	assert_eq(_face(cards[1]).get_parent(), _face(cards[0]).get_parent(), "The others stay in the row")
	_settle_hand()
	assert_almost_eq(_face(cards[1]).position, seven[2], Vector2(0.5, 0.5), "and ease to their new places.")
	assert_almost_eq(_face(cards[1]).rotation, EncounterLayout.fan_angle(2, 7), 0.001)
	assert_almost_eq(_face(cards[0]).position, seven[0], Vector2(0.5, 0.5))

	_screen.drag_to(FIELD)
	assert_false(_screen.drag_card().has_gap())
	assert_eq(_screen.hand_places(Vector2.ZERO), EncounterLayout.hand_rest(6, hand, size))
	_screen.cancel_drag()


func test_the_hand_does_not_part_around_the_cursor_while_a_card_is_held() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var over: Vector2 = _on(cards[2])
	assert_ne(_screen.hand_places(over), _screen.hand_places(Vector2.ZERO), "At rest the hand parts under the cursor.")

	_screen.press_hand(_on(cards[5]), false)
	_screen.drag_to(FIELD)

	assert_eq(_screen.hand_places(over), _screen.hand_places(Vector2.ZERO))
	_screen.cancel_drag()


func test_a_card_let_go_over_the_strip_is_put_down_where_the_hand_made_room() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var size: Vector2 = _face(cards[0]).size
	var seven: Array[Vector2] = EncounterLayout.hand_rest(7, _regions["hero_hand"], size)
	var face: Control = _face(cards[5])
	var before: EncounterSnapshot = _presenter.snapshot()
	_screen.press_hand(_on(cards[5]), false)

	_screen.release_hand(seven[1] + Vector2(size.x / 2.0, 60))

	assert_eq(_screen.hand_order().cards(), [cards[0], cards[5], cards[1], cards[2], cards[3], cards[4], cards[6]] as Array[int])
	assert_eq(_row_cards(), _screen.hand_order().cards())
	assert_eq(_face(cards[5]), face, "The same face went back into the row.")
	assert_eq(face.get_parent(), _face(cards[0]).get_parent())
	assert_eq(face.get_index(), _face(cards[0]).get_index() + 1, "Drawn over the card to its left")
	assert_eq(face.get_index(), _face(cards[1]).get_index() - 1, "and under the one to its right.")
	assert_null(_screen.lifted_face())
	assert_false(_screen.drag_card().is_lifted())
	assert_eq(_presenter.snapshot(), before, "Rearranging answers nothing.")
	_settle_hand()
	assert_almost_eq(face.position, seven[1], Vector2(0.5, 0.5), "It eases into its place from where it was let go.")
	assert_almost_eq(face.rotation, EncounterLayout.fan_angle(1, 7), 0.001)
	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)
	assert_true(_is_left_to_right(_screen.hand_order().cards()), "A redraw draws the same order.")


func test_a_card_let_go_past_either_end_or_over_the_info_panel_goes_to_that_end() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()

	_screen.press_hand(_on(cards[2]), false)
	_screen.release_hand(_regions["info"].get_center())
	assert_eq(_screen.hand_order().cards()[0], cards[2], "The Info Panel is in the strip (A382).")
	assert_eq(_face(cards[2]).get_index(), _face(cards[0]).get_index() - 1, "Drawn under the card that was first.")

	_settle_hand()
	_screen.press_hand(_on(cards[2]), false)
	_screen.release_hand(Vector2(_regions["hero_hand"].end.x + 100.0, 1000))
	assert_eq(_screen.hand_order().cards()[6], cards[2])
	assert_eq(_face(cards[2]).get_index(), _face(cards[6]).get_index() + 1, "Drawn over the card that was last.")


func test_a_playable_card_let_go_above_the_strip_is_played() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")

	_screen.press_hand(_on(forest), false)
	_screen.release_hand(FIELD)
	_presenter.wait_until_idle()

	assert_eq(_permanents("Forest").size(), 1)
	assert_false(_screen.hand_order().cards().has(forest))
	assert_null(_screen.lifted_face(), "Nothing is left under the cursor (A378).")
	assert_false(_screen.drag_card().is_lifted())
	assert_eq(_row_cards().size(), 6)

	var bear: int = _card("Bear")
	_screen.press_hand(_on(bear), false)
	_screen.release_hand(_regions["hero_graveyard"].get_center())
	_presenter.wait_until_idle()
	assert_eq(_permanents("Bear").size(), 1, "Anywhere above the strip counts, the piles too (A372).")


func test_a_card_that_cannot_be_played_goes_back_to_its_place_without_a_word() -> void:
	_open(_forests_and_bears())
	_screen.press_hand(_on(_card("Forest")), true)
	_presenter.wait_until_idle()
	var cards: Array[int] = _screen.hand_order().cards()
	var second: int = _card("Forest")
	var before: EncounterSnapshot = _presenter.snapshot()

	_screen.press_hand(_on(second), false)
	_screen.drag_to(FIELD)
	assert_null(BorderEffects.glow_color(_screen.lifted_face()), "It does not glow")
	assert_eq(_screen.info_panel().option_text(), "", "and nothing says it can be played.")
	_screen.release_hand(FIELD)

	assert_eq(_presenter.snapshot(), before)
	assert_eq(_screen.info_panel().error_text(), "", "A380: silently.")
	assert_eq(_screen.hand_order().cards(), cards)
	assert_eq(_row_cards(), cards)
	assert_null(_screen.lifted_face())


func test_a_card_let_go_while_the_villain_thinks_goes_back_to_its_place() -> void:
	var agent: SlowAgent = SlowAgent.new()
	agent.delay_msec = 150
	_open(_forests_and_bears(), agent)
	var cards: Array[int] = _screen.hand_order().cards()
	_presenter.pass_priority()
	assert_true(_presenter.is_villain_thinking())

	_screen.press_hand(_on(cards[1]), false)
	_screen.release_hand(FIELD)

	assert_eq(_row_cards(), cards, "A373: any card can be picked up at any time, but only played when it glows.")
	assert_eq(_screen.info_panel().error_text(), "")
	_settle_hand()
	_screen.press_hand(_on(cards[1]), false)
	_screen.release_hand(_on(cards[6]) + Vector2(400, 0))
	assert_eq(_screen.hand_order().cards()[6], cards[1], "And the hand can be rearranged meanwhile.")
	_presenter.wait_until_idle()


func test_held_where_letting_go_would_play_it_a_card_glows_brighter_and_the_info_panel_says_so() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	var green: Color = DecisionClicks.color_of(DecisionClicks.Kind.OTHER)
	var at: Vector2 = _on(forest)
	_screen.press_hand(at, false)

	_screen.drag_to(at + Vector2(0, -5))
	assert_eq(BorderEffects.glow_color(_screen.lifted_face()), green, "Over the strip it glows as it did.")
	assert_eq(_screen.info_panel().option_text(), "")

	_screen.drag_to(FIELD)
	assert_eq(BorderEffects.glow_color(_screen.lifted_face()), DecisionClicks.bright_color_of(DecisionClicks.Kind.OTHER))
	assert_eq(_screen.info_panel().option_text(), "Release to play Forest")

	_screen.drag_to(at)
	assert_eq(BorderEffects.glow_color(_screen.lifted_face()), green)
	assert_eq(_screen.info_panel().option_text(), "")

	_screen.drag_to(FIELD)
	_screen.cancel_drag()
	assert_eq(BorderEffects.glow_color(_face(forest)), green, "Back in the hand it glows as before.")
	assert_eq(_screen.info_panel().option_text(), "")
	_settle_hand()

	_screen.press_hand(_on(_card("Bear")), false)
	_screen.drag_to(FIELD)
	assert_eq(_screen.info_panel().option_text(), "Release to cast Bear")
	_screen.cancel_drag()


func test_moving_over_the_left_panels_lets_go_of_the_card() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var forest: int = _card("Forest")
	var before: EncounterSnapshot = _presenter.snapshot()
	_screen.press_hand(_on(forest), false)
	_screen.drag_to(FIELD)

	_screen.drag_to(_regions["hero_panel"].get_center())

	assert_null(_screen.lifted_face(), "A371: before any release.")
	assert_false(_screen.drag_card().is_holding())
	assert_eq(_row_cards(), cards)
	_screen.release_hand(_regions["hero_panel"].get_center())
	assert_eq(_presenter.snapshot(), before)
	_screen.drag_to(FIELD)
	assert_null(_screen.lifted_face(), "The drag is over: moving on picks nothing up.")


func test_canceling_puts_a_held_card_back_and_escape_also_opens_the_pause_menu() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	_screen.press_hand(_on(cards[2]), false)
	_screen.drag_to(FIELD)

	_screen.cancel_drag()
	assert_null(_screen.lifted_face())
	assert_eq(_row_cards(), cards)
	assert_false(_screen.is_paused())

	_settle_hand()
	assert_true(_screen.press_hand(_on(cards[2]), false))
	_screen.drag_to(FIELD)
	assert_not_null(_screen.lifted_face())
	_screen.press_key(KEY_ESCAPE)
	assert_null(_screen.lifted_face(), "A381.")
	assert_eq(_row_cards(), cards)
	assert_true(_screen.is_paused())
	assert_false(_screen.press_hand(_on(cards[2]), false), "Nothing is picked up while paused.")
	assert_false(_screen.press_hand(_on(_card("Forest")), true))
	_screen.press_key(KEY_ESCAPE)

	_settle_hand()
	assert_true(_screen.press_hand(_on(cards[2]), false))
	assert_true(_screen.drag_card().is_pressed())
	_screen.cancel_drag()
	assert_false(_screen.drag_card().is_pressed(), "A press that never became a drag is let go of too.")


func test_a_right_click_puts_a_held_card_back() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	_screen.press_hand(_on(cards[2]), false)
	_screen.drag_to(FIELD)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true

	get_viewport().push_input(click)

	assert_null(_screen.lifted_face())
	assert_eq(_row_cards(), cards)


func test_a_card_whose_play_is_refused_does_not_stay_held() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var forest: int = _card("Forest")
	_screen.press_hand(_on(forest), false)
	_screen.drag_to(FIELD)
	_presenter.set_paused(true)

	_screen.release_hand(FIELD)

	assert_eq(_screen.info_panel().error_text(), EncounterPresenter.PAUSED, "The presenter refused it.")
	assert_false(_screen.drag_card().is_lifted())
	assert_null(_screen.lifted_face())
	assert_eq(_row_cards(), cards)
	_presenter.set_paused(false)


func test_the_mouse_presses_drags_and_lets_go_where_its_events_say() -> void:
	_open(_forests_and_bears())
	_screen.position = Vector2(40, 0)
	var forest: int = _card("Forest")
	var at: Vector2 = _on(forest)
	var grabbed: Vector2 = at - _face(forest).position

	_screen._input(_button(MOUSE_BUTTON_LEFT, true, at + Vector2(40, 0)))
	assert_true(_screen.drag_card().is_pressed(), "Events come in the window's coordinates, and the screen is 40 px in.")
	assert_eq(_screen.drag_card().card_id(), forest)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = FIELD + Vector2(40, 0)
	_screen._input(motion)
	assert_eq(_screen.lifted_face().position, FIELD - grabbed, "What follows comes in the window's coordinates, and the screen is 40 px in.")

	_screen._input(_button(MOUSE_BUTTON_RIGHT, false, FIELD))
	_screen._input(_button(MOUSE_BUTTON_LEFT, true, FIELD))
	assert_true(_screen.drag_card().is_holding(), "Only the left button coming up lets go, and only the right going down cancels.")
	_screen._input(_button(MOUSE_BUTTON_LEFT, false, FIELD + Vector2(40, 0)))
	_presenter.wait_until_idle()

	assert_eq(_permanents("Forest").size(), 1)
	assert_false(_screen.drag_card().is_holding())


func test_mouse_events_are_left_alone_while_no_card_is_pressed_or_held() -> void:
	_open(_forests_and_bears())
	var before: EncounterSnapshot = _presenter.snapshot()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = FIELD

	_screen._input(motion)
	_screen._input(_button(MOUSE_BUTTON_LEFT, false, FIELD))
	_screen._input(_button(MOUSE_BUTTON_RIGHT, true, FIELD))
	_screen._input(InputEventKey.new())

	assert_null(_screen.lifted_face())
	assert_eq(_presenter.snapshot(), before)


func test_a_double_click_from_the_mouse_plays_the_card_and_a_press_off_the_hand_is_a_click_on_the_board() -> void:
	_open(_forests_and_bears())
	var click: InputEventMouseButton = _button(MOUSE_BUTTON_LEFT, true, _on(_card("Forest")))
	click.double_click = true

	_screen._input(click)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1)

	_screen._input(_button(MOUSE_BUTTON_RIGHT, true, _on(_card("Bear"))))
	_screen._input(_button(MOUSE_BUTTON_LEFT, false, _on(_card("Bear"))))
	_screen._input(InputEventKey.new())
	_screen._gui_input(InputEventKey.new())
	assert_false(_screen.drag_card().is_pressed(), "Only the left button going down presses a card.")
	_screen._input(_button(MOUSE_BUTTON_LEFT, true, FIELD))
	_screen._gui_input(_button(MOUSE_BUTTON_LEFT, true, FIELD))
	assert_false(_screen.drag_card().is_pressed())


func test_the_hand_eases_as_far_in_one_slow_frame_as_in_the_frames_it_replaced() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	_screen.press_hand(_on(cards[5]), false)
	_screen.release_hand(_on(cards[0]))
	var from: Vector2 = _face(cards[5]).position
	var to: Vector2 = _screen.hand_places(Vector2.ZERO)[0]

	_screen._process(3.0 / 60.0)

	assert_almost_eq(_face(cards[5]).position, from.lerp(to, 0.657), Vector2(0.5, 0.5))
	assert_eq(EncounterScreen.HAND_EASE, 0.3)


func test_a_card_under_a_window_or_the_option_menu_is_not_pressed_through_it() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var at: Vector2 = _on(cards[3])
	var covers: Array[Control] = [_screen.stack_window(), _screen.choice_window(),
			_screen.emblems_window(HERO), _screen.emblems_window(MmEncounterSetup.VILLAIN_PLAYER_ID)]

	for cover: Control in covers:
		cover.position = at - Vector2(40, 40)
		cover.size = Vector2(300, 200)
		cover.show()
		_screen._input(_button(MOUSE_BUTTON_LEFT, true, at))
		assert_false(_screen.drag_card().is_pressed(), "Under the %s." % cover.name)
		_screen._input(_button(MOUSE_BUTTON_LEFT, true, at - Vector2(41, 0)))
		assert_true(_screen.drag_card().is_pressed(), "Just beside it, a card is pressed as usual.")
		_screen.cancel_drag()
		cover.hide()
		_screen._input(_button(MOUSE_BUTTON_LEFT, true, at))
		assert_true(_screen.drag_card().is_pressed(), "A hidden window covers nothing.")
		_screen.cancel_drag()
	_screen.option_menu().open([ClickOption.new(0, "One"), ClickOption.new(1, "Two")] as Array[ClickOption], FIELD, _regions["battlefield"])
	_screen._input(_button(MOUSE_BUTTON_LEFT, true, at))
	assert_false(_screen.drag_card().is_pressed(), "While the Option Menu is open, a click anywhere is the menu's.")
	_screen.option_menu().close()


func test_a_real_press_drag_and_release_reach_the_hand_through_the_input_pipeline() -> void:
	# Fed into a viewport as a window would feed them, not handed to the screen's own
	# methods: the first build passed every test and did nothing under a real mouse, because
	# the screen stops the mouse and a press never reached the handler the tests called.
	var window: SubViewport = _open_in_a_viewport()
	var cards: Array[int] = _screen.hand_order().cards()
	var at: Vector2 = _on(cards[3])
	var down: Vector2 = _regions["hero_hand"].position + Vector2(20, 100)

	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))
	assert_true(_screen.drag_card().is_pressed(), "The press reached the hand.")
	window.push_input(_motion(FIELD))
	assert_true(_screen.drag_card().is_holding())
	assert_not_null(_screen.lifted_face())
	window.push_input(_motion(down))
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, down))

	assert_false(_screen.drag_card().is_holding())
	assert_eq(_screen.hand_order().cards()[0], cards[3], "It was put down at the left end.")


func test_a_real_double_click_plays_a_card_and_a_real_right_click_cancels_a_drag() -> void:
	var window: SubViewport = _open_in_a_viewport()
	var click: InputEventMouseButton = _button(MOUSE_BUTTON_LEFT, true, _on(_card("Forest")))
	click.double_click = true

	window.push_input(click)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1)

	var cards: Array[int] = _screen.hand_order().cards()
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, FIELD))
	# The hand parted around the double-click; with the mouse away it closes up again.
	window.push_input(_motion(FIELD))
	_settle_hand()
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, _on(cards[2])))
	window.push_input(_motion(FIELD))
	assert_true(_screen.drag_card().is_holding())
	window.push_input(_button(MOUSE_BUTTON_RIGHT, true, FIELD))
	assert_false(_screen.drag_card().is_holding())
	assert_eq(_row_cards(), cards)


func test_a_real_press_on_a_card_that_has_risen_over_a_land_picks_up_the_card() -> void:
	# A card under the cursor rises a little way over the Hero's lands. A land that can be
	# tapped takes clicks, and the card's top edge, where it is natural to grab it, lies
	# over that land: the card must win, as whatever is drawn on top should.
	var window: SubViewport = _open_in_a_viewport()
	_screen.press_hand(_on(_card("Forest")), true)
	_presenter.wait_until_idle()
	var forest: Control = _screen.face_of(_permanents("Forest")[0])
	assert_not_null(_screen.click_catcher(_permanents("Forest")[0]), "The Forest can be tapped for mana.")
	var land: Rect2 = Rect2(forest.get_global_rect().position - _screen.global_position, forest.size)
	var over: Vector2 = Vector2(land.get_center().x, 950)
	window.push_input(_motion(over))
	_settle_hand()
	var card_id: int = _screen.hand_card_at(over)
	var card: Rect2 = Rect2(_face(card_id).position, _face(card_id).size)
	var both: Rect2 = card.intersection(land)
	assert_gt(both.size.y, 8.0, "The risen card overlaps the land.")
	var at: Vector2 = Vector2(over.x, both.get_center().y)
	assert_eq(_screen.hand_card_at(at), card_id)
	var before: EncounterSnapshot = _presenter.snapshot()

	window.push_input(_motion(at))
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))

	assert_true(_screen.drag_card().is_pressed())
	assert_eq(_screen.drag_card().card_id(), card_id)
	assert_eq(_presenter.snapshot(), before, "The land under it was not tapped.")
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, at))


func test_a_real_press_made_before_the_hand_has_caught_up_with_the_cursor_still_picks_up_the_card() -> void:
	# The hand eases toward the cursor over several frames, and fewer when a frame is slow.
	# A press made on arriving, on the strip a card is about to rise into, used to miss: it
	# was tested against where the card was still drawn, not where the cursor was sending it.
	var window: SubViewport = _open_in_a_viewport()
	window.push_input(_motion(FIELD))
	_settle_hand()
	var cards: Array[int] = _screen.hand_order().cards()
	var rest: Vector2 = _face(cards[3]).position
	var at: Vector2 = rest + Vector2(30, -20)
	assert_false(Rect2(rest, _face(cards[3]).size).grow(8.0).has_point(at), "Above where the card is drawn at rest,")
	assert_true(Rect2(_screen.hand_places(at)[3], _face(cards[3]).size).has_point(at), "and where it rises to under the cursor.")

	window.push_input(_motion(at))
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))
	window.push_input(_motion(FIELD))

	assert_true(_screen.drag_card().is_holding(), "All three arrived in one slow frame, and the card is held.")
	assert_eq(_screen.drag_card().card_id(), cards[3])
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, FIELD))


func test_a_real_second_try_right_after_a_first_is_still_a_drag() -> void:
	# Two presses close together arrive marked as a double-click. On a card that cannot be
	# played that must not swallow the drag.
	var window: SubViewport = _open_in_a_viewport()
	_screen.press_hand(_on(_card("Forest")), true)
	_presenter.wait_until_idle()
	window.push_input(_motion(FIELD))
	_settle_hand()
	var cards: Array[int] = _screen.hand_order().cards()
	var second: int = _card("Forest")
	var at: Vector2 = _on(second)
	var again: InputEventMouseButton = _button(MOUSE_BUTTON_LEFT, true, at)
	again.double_click = true
	var before: EncounterSnapshot = _presenter.snapshot()

	window.push_input(again)
	window.push_input(_motion(_regions["hero_hand"].position + Vector2(20, 100)))
	assert_true(_screen.drag_card().is_holding())
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, _regions["hero_hand"].position + Vector2(20, 100)))

	assert_eq(_screen.hand_order().cards()[0], second)
	assert_ne(_screen.hand_order().cards(), cards)
	assert_eq(_presenter.snapshot(), before, "Nothing was played.")


func test_a_real_press_on_a_window_over_the_hand_is_the_windows() -> void:
	var window: SubViewport = _open_in_a_viewport()
	var cards: Array[int] = _screen.hand_order().cards()
	var at: Vector2 = _on(cards[3])
	var emblems: ZoneWindow = _screen.emblems_window(HERO)
	emblems.show()
	emblems.position = at - Vector2(100, 100)
	emblems.size = Vector2(300, 220)

	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))

	assert_false(_screen.drag_card().is_pressed(), "A card under a window is not picked up through it.")
	emblems.hide()
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))
	assert_true(_screen.drag_card().is_pressed(), "With the window gone, it is.")


func test_a_held_card_stays_held_while_the_board_is_rebuilt_under_it() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	var at: Vector2 = _on(forest)
	_screen.press_hand(at, false)
	_screen.drag_to(FIELD)
	var before: Control = _screen.lifted_face()
	var place: Vector2 = before.position

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	var after: CardFace = _screen.lifted_face()
	assert_ne(after, before, "It was drawn again")
	assert_true(before.is_queued_for_deletion())
	assert_eq(after.position, place, "where it is held")
	assert_eq(after.rotation, 0.0)
	assert_gt(after.get_parent().get_index(), _screen.stack_window().get_index())
	assert_eq(after.get_parent().get_child_count(), 1)
	assert_eq(BorderEffects.glow_color(after), DecisionClicks.bright_color_of(DecisionClicks.Kind.OTHER))
	assert_eq(_screen.info_panel().option_text(), "Release to play Forest")
	assert_eq(_screen.face_of(_seen(forest).id), after)
	assert_eq(_row_cards().size(), 6, "and the row is drawn without it.")
	_screen.release_hand(FIELD)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1, "It can still be played.")


func test_a_redraw_keeps_the_gap_the_hand_made() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var size: Vector2 = _face(cards[0]).size
	var hand: Rect2 = _regions["hero_hand"]
	_screen.press_hand(_on(cards[3]), false)
	_screen.drag_to(EncounterLayout.hand_rest(7, hand, size)[1] + Vector2(size.x / 2.0, 60))

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	assert_eq(_face(cards[1]).position, EncounterLayout.hand_row(6, 1, hand, size)[1])
	assert_almost_eq(_face(cards[1]).rotation, EncounterLayout.fan_angle(2, 7), 0.0001)
	assert_null(BorderEffects.glow_color(_screen.lifted_face()) if _screen._hand_options(cards[3]).is_empty() else null)
	_screen.cancel_drag()


func test_a_held_card_that_leaves_the_hand_is_no_longer_held() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	_screen.press_hand(_on(forest), false)
	_screen.drag_to(FIELD)

	_presenter.answer(_screen._hand_options(forest)[0].answer)
	_presenter.wait_until_idle()

	assert_false(_screen.drag_card().is_lifted(), "A380.")
	assert_null(_screen.lifted_face())
	assert_eq(_row_cards().size(), 6)
	_screen.release_hand(FIELD)
	assert_eq(_permanents("Forest").size(), 1, "Letting go afterwards plays nothing more.")


func test_a_card_with_several_ways_to_be_played_waits_where_it_was_let_go_for_the_option_menu() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var forest: int = _card("Forest")
	_two_ways(forest)
	_screen.press_hand(_on(forest), false)
	_screen.drag_to(FIELD)
	var place: Vector2 = _screen.lifted_face().position

	_screen.release_hand(FIELD)

	assert_true(_screen.option_menu().is_open(), "A372.")
	assert_eq(_screen.option_menu().rows().size(), 2)
	assert_eq(_screen.option_menu().rows()[0].text, "Play Forest")
	assert_true(_screen.option_menu().box_rect().has_point(FIELD + Vector2(4, 4)), "It opens where the card was let go.")
	assert_true(_screen.drag_card().is_waiting())
	assert_eq(_screen.lifted_face().position, place, "The card stays where it was released.")
	assert_eq(BorderEffects.glow_color(_screen.lifted_face()), DecisionClicks.bright_color_of(DecisionClicks.Kind.OTHER))
	assert_eq(_screen.info_panel().option_text(), "", "Nothing is being held any more.")
	assert_eq(_row_cards().size(), 6)
	assert_eq(_permanents("Forest").size(), 0, "Nothing is played yet.")
	_screen.drag_to(Vector2(600, 300))
	assert_eq(_screen.lifted_face().position, place, "It no longer follows the cursor.")

	_screen.option_menu().close()

	assert_null(_screen.lifted_face(), "Closing the menu sends the card back to the hand.")
	assert_eq(_row_cards(), cards)
	assert_eq(_permanents("Forest").size(), 0)


func test_choosing_from_the_option_menu_plays_the_waiting_card() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	_two_ways(forest)
	_screen.press_hand(_on(forest), false)
	_screen.release_hand(FIELD)

	_screen.option_menu().rows()[1].pressed.emit()
	_presenter.wait_until_idle()

	assert_eq(_permanents("Forest").size(), 1)
	assert_null(_screen.lifted_face())
	assert_false(_screen.drag_card().is_lifted())
	assert_false(_screen.option_menu().is_open())


func test_a_redraw_while_a_card_waits_sends_it_back_to_the_hand() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_order().cards()
	var forest: int = _card("Forest")
	_two_ways(forest)
	_screen.press_hand(_on(forest), false)
	_screen.release_hand(FIELD)

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	assert_false(_screen.option_menu().is_open(), "Anything open over the board closes on a redraw.")
	assert_null(_screen.lifted_face())
	assert_eq(_row_cards(), cards)


func test_a_double_click_on_a_card_with_several_ways_opens_the_option_menu_at_the_card() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	_two_ways(forest)

	_screen.press_hand(_on(forest), true)

	assert_true(_screen.option_menu().is_open())
	assert_eq(_screen.option_menu().rows().size(), 2)
	assert_null(_screen.lifted_face(), "The card stays in the hand (A377).")
	assert_eq(_row_cards().size(), 7)
	_screen.option_menu().rows()[0].pressed.emit()
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1)


func test_a_canceled_cast_and_an_undo_put_the_card_back_where_it_was() -> void:
	_open(_setup_of([Scenario.basic_land("Forest"), Scenario.free_shock("Zap", 2)]))
	var cards: Array[int] = _screen.hand_order().cards()
	var zap: int = _card("Zap")
	var place: int = cards.find(zap)

	_screen.press_hand(_on(zap), true)
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision)
	assert_false(_screen.hand_order().cards().has(zap))
	_screen.info_panel().cancel_button().pressed.emit()
	assert_eq(_screen.hand_order().cards(), cards, "A379: by Card Identity, though it is a new Game Object.")
	assert_eq(_row_cards(), cards)
	assert_eq(place, _screen.hand_order().place_of(zap))

	_screen.hand_order().place(zap, 0)
	var moved: Array[int] = _screen.hand_order().cards()
	var forest: int = _card("Forest")
	_screen.press_hand(_on(forest), true)
	_presenter.wait_until_idle()
	assert_false(_screen.hand_order().cards().has(forest))
	_screen.undo()
	assert_eq(_screen.hand_order().cards(), moved, "The undo brings the card back, and does not undo the rearranging (A374).")


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


## Opens the screen in a viewport of its own, so that events pushed into it go through
## Godot's own picking of what is under the mouse, clear of the test runner's windows.
func _open_in_a_viewport() -> SubViewport:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_open(_forests_and_bears(), DefaultAnswerAgent.new(), window)
	return window


func _button(button: MouseButton, is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = button
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click


func _open(setup: MmEncounterSetup, agent: MmAgent = DefaultAnswerAgent.new(), parent: Node = null) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	if parent == null:
		add_child_autofree(_screen)
	else:
		parent.add_child(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(setup, agent)
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_pass_until(func() -> bool:
		return _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN and _presenter.snapshot().view.active_player_id == HERO)


## The Hero's deck alternates Forests and free 2/2 Bears.
func _forests_and_bears() -> MmEncounterSetup:
	return _setup_of([Scenario.basic_land("Forest"), _bear()])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))


func _setup_of(cards: Array[MmCardDefinition]) -> MmEncounterSetup:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	return Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40))


## The Hero's view of the card in hand with Card Identity [param card_id].
func _seen(card_id: int) -> MmObjectView:
	for card: MmObjectView in _presenter.snapshot().view.hand:
		if card.card_id == card_id:
			return card
	return null


## The Card Identity of the leftmost card in hand named [param card_name].
func _card(card_name: String) -> int:
	for card_id: int in _screen.hand_order().cards():
		if _seen(card_id).name == card_name:
			return card_id
	return DragCard.NONE


func _face(card_id: int) -> Control:
	return _screen.face_of(_seen(card_id).id)


## A place on the part of the card with Card Identity [param card_id] that no other covers.
func _on(card_id: int) -> Vector2:
	return _face(card_id).position + Vector2(30, 60)


## The Card Identities of the hand's row as it is drawn, from the left.
func _row_cards() -> Array[int]:
	var cards: Array[int] = []
	var at: Dictionary[int, float] = {}
	for card: MmObjectView in _presenter.snapshot().view.hand:
		var face: Control = _screen.face_of(card.id)
		if face != null and face != _screen.lifted_face():
			at[card.card_id] = face.get_index()
			cards.append(card.card_id)
	cards.sort_custom(func(a: int, b: int) -> bool: return at[a] < at[b])
	return cards


func _is_left_to_right(cards: Array[int]) -> bool:
	for index: int in cards.size() - 1:
		if _face(cards[index]).position.x >= _face(cards[index + 1]).position.x:
			return false
	return true


## Lets the hand's cards ease to where they belong.
func _settle_hand() -> void:
	for frame: int in 60:
		_screen._spread_hand(0.3)


## Gives the card in hand with Card Identity [param card_id] a second way to be played, as
## the first card with two will have: the same answer again under another name.
func _two_ways(card_id: int) -> void:
	var clicks: DecisionClicks = _screen._clicks
	var options: Array[ClickOption] = clicks.hand_options_of(_seen(card_id).id)
	clicks._hand_options[_seen(card_id).id] = [options[0], ClickOption.new(options[0].answer, options[0].text + " another way")]


func _permanents(card_name: String) -> Array[int]:
	var found: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			found.append(permanent.id)
	return found


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
