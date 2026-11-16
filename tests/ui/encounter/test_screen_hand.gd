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


func test_a_double_click_plays_a_land_and_casts_a_spell() -> void:
	_open(_forests_and_bears())

	_screen.press_hand(_on(_card("Forest")), true)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1)
	assert_false(_screen.hand_strip().is_pressing(), "A double-click starts no drag.")

	_screen.press_hand(_on(_card("Bear")), true)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Bear").size(), 1, "The Bear was cast, and the Hero's own spell is passed for them.")


func test_a_playable_card_let_go_above_the_strip_is_played() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")

	_screen.press_hand(_on(forest), false)
	_screen.release_hand(FIELD)
	_presenter.wait_until_idle()

	assert_eq(_permanents("Forest").size(), 1)
	assert_false(_screen.hand_strip().order().has(forest))
	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()), "Nothing is left under the cursor (A378).")
	assert_false((_screen.hand_strip().held() != DragCard.NONE))
	assert_eq(_row_cards().size(), 6)

	var bear: int = _card("Bear")
	_screen.press_hand(_on(bear), false)
	_screen.release_hand(_regions["hero_graveyard"].get_center())
	_presenter.wait_until_idle()
	assert_eq(_permanents("Bear").size(), 1, "Anywhere above the strip counts, the piles too (A372).")


func test_a_card_let_go_while_the_villain_thinks_goes_back_to_its_place() -> void:
	var agent: SlowAgent = SlowAgent.new()
	agent.delay_msec = 150
	_open(_forests_and_bears(), agent)
	var cards: Array[int] = _screen.hand_strip().order()
	_presenter.pass_priority()
	assert_true(_presenter.is_villain_thinking())

	_screen.press_hand(_on(cards[1]), false)
	_screen.release_hand(FIELD)

	assert_eq(_row_cards(), cards, "A373: any card can be picked up at any time, but only played when it glows.")
	assert_eq(_screen.info_panel().error_text(), "")
	_settle_hand()
	_screen.press_hand(_on(cards[1]), false)
	_screen.release_hand(_on(cards[6]) + Vector2(400, 0))
	assert_eq(_screen.hand_strip().order()[6], cards[1], "And the hand can be rearranged meanwhile.")
	_presenter.wait_until_idle()


func test_held_where_letting_go_would_play_it_a_card_glows_brighter_and_the_info_panel_says_so() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	var green: Color = DecisionClicks.color_of(DecisionClicks.Kind.PLAY)
	var at: Vector2 = _on(forest)
	_screen.press_hand(at, false)

	_screen.drag_to(at + Vector2(0, -5))
	assert_eq(BorderEffects.glow_color(_screen.hand_strip().face_of(_screen.hand_strip().held())), green, "Over the strip it glows as it did.")
	assert_eq(_screen.info_panel().option_text(), "")

	_screen.drag_to(FIELD)
	assert_eq(BorderEffects.glow_color(_screen.hand_strip().face_of(_screen.hand_strip().held())), DecisionClicks.bright_color_of(DecisionClicks.Kind.PLAY))
	assert_eq(_screen.info_panel().option_text(), "Release to play Forest")

	_screen.drag_to(at)
	assert_eq(BorderEffects.glow_color(_screen.hand_strip().face_of(_screen.hand_strip().held())), green)
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


func test_canceling_puts_a_held_card_back_and_escape_also_opens_the_pause_menu() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_strip().order()
	_screen.press_hand(_on(cards[2]), false)
	_screen.drag_to(FIELD)

	_screen.cancel_drag()
	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
	assert_eq(_row_cards(), cards)
	assert_false(_screen.is_paused())

	_settle_hand()
	assert_true(_screen.press_hand(_on(cards[2]), false))
	_screen.drag_to(FIELD)
	assert_not_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
	_screen.press_key(KEY_ESCAPE)
	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()), "A381.")
	assert_eq(_row_cards(), cards)
	assert_true(_screen.is_paused())
	assert_false(_screen.press_hand(_on(cards[2]), false), "Nothing is picked up while paused.")
	assert_false(_screen.press_hand(_on(_card("Forest")), true))
	_screen.press_key(KEY_ESCAPE)

	_settle_hand()
	assert_true(_screen.press_hand(_on(cards[2]), false))
	assert_true(_screen.hand_strip().is_pressing())
	_screen.cancel_drag()
	assert_false(_screen.hand_strip().is_pressing(), "A press that never became a drag is let go of too.")


func test_a_right_click_puts_a_held_card_back() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_strip().order()
	_screen.press_hand(_on(cards[2]), false)
	_screen.drag_to(FIELD)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true

	get_viewport().push_input(click)

	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
	assert_eq(_row_cards(), cards)


func test_a_card_whose_play_is_refused_does_not_stay_held() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_strip().order()
	var forest: int = _card("Forest")
	_screen.press_hand(_on(forest), false)
	_screen.drag_to(FIELD)
	_presenter.set_paused(true)

	_screen.release_hand(FIELD)

	assert_eq(_screen.info_panel().error_text(), EncounterPresenter.PAUSED, "The presenter refused it.")
	assert_false((_screen.hand_strip().held() != DragCard.NONE))
	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
	assert_eq(_row_cards(), cards)
	_presenter.set_paused(false)


func test_the_mouse_presses_drags_and_lets_go_where_its_events_say() -> void:
	_open(_forests_and_bears())
	_screen.position = Vector2(40, 0)
	var forest: int = _card("Forest")
	var at: Vector2 = _on(forest)
	var grabbed: Vector2 = at - _face(forest).position

	_screen._input(_button(MOUSE_BUTTON_LEFT, true, at + Vector2(40, 0)))
	assert_true(_screen.hand_strip().is_pressing(), "Events come in the window's coordinates, and the screen is 40 px in.")
	assert_eq(_screen.hand_strip().pressed(), forest)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = FIELD + Vector2(40, 0)
	_screen._input(motion)
	assert_eq(_screen.hand_strip().face_of(_screen.hand_strip().held()).position, FIELD - grabbed, "What follows comes in the window's coordinates, and the screen is 40 px in.")

	_screen._input(_button(MOUSE_BUTTON_RIGHT, false, FIELD))
	_screen._input(_button(MOUSE_BUTTON_LEFT, true, FIELD))
	assert_true(_screen.hand_strip().is_holding(), "Only the left button coming up lets go, and only the right going down cancels.")
	_screen._input(_button(MOUSE_BUTTON_LEFT, false, FIELD + Vector2(40, 0)))
	_presenter.wait_until_idle()

	assert_eq(_permanents("Forest").size(), 1)
	assert_false(_screen.hand_strip().is_holding())


func test_mouse_events_are_left_alone_while_no_card_is_pressed_or_held() -> void:
	_open(_forests_and_bears())
	var before: EncounterSnapshot = _presenter.snapshot()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = FIELD

	_screen._input(motion)
	_screen._input(_button(MOUSE_BUTTON_LEFT, false, FIELD))
	_screen._input(_button(MOUSE_BUTTON_RIGHT, true, FIELD))
	_screen._input(InputEventKey.new())

	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
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
	assert_false(_screen.hand_strip().is_pressing(), "Only the left button going down presses a card.")
	_screen._input(_button(MOUSE_BUTTON_LEFT, true, FIELD))
	_screen._gui_input(_button(MOUSE_BUTTON_LEFT, true, FIELD))
	assert_false(_screen.hand_strip().is_pressing())


func test_a_card_under_a_window_or_the_option_menu_is_not_pressed_through_it() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_strip().order()
	var at: Vector2 = _on(cards[3])
	var covers: Array[Control] = [_screen.stack_window(), _screen.choice_window(),
			_screen.emblems_window(HERO), _screen.emblems_window(MmEncounterSetup.VILLAIN_PLAYER_ID)]

	for cover: Control in covers:
		cover.position = at - Vector2(40, 40)
		cover.size = Vector2(300, 200)
		cover.show()
		_screen._input(_button(MOUSE_BUTTON_LEFT, true, at))
		assert_false(_screen.hand_strip().is_pressing(), "Under the %s." % cover.name)
		_screen._input(_button(MOUSE_BUTTON_LEFT, true, at - Vector2(41, 0)))
		assert_true(_screen.hand_strip().is_pressing(), "Just beside it, a card is pressed as usual.")
		_screen.cancel_drag()
		cover.hide()
		_screen._input(_button(MOUSE_BUTTON_LEFT, true, at))
		assert_true(_screen.hand_strip().is_pressing(), "A hidden window covers nothing.")
		_screen.cancel_drag()
	_screen.option_menu().open([ClickOption.new(0, "One"), ClickOption.new(1, "Two")] as Array[ClickOption], FIELD, _regions["battlefield"])
	_screen._input(_button(MOUSE_BUTTON_LEFT, true, at))
	assert_false(_screen.hand_strip().is_pressing(), "While the Option Menu is open, a click anywhere is the menu's.")
	_screen.option_menu().close()


func test_a_real_press_drag_and_release_reach_the_hand_through_the_input_pipeline() -> void:
	# Fed into a viewport as a window would feed them, not handed to the screen's own
	# methods: the first build passed every test and did nothing under a real mouse, because
	# the screen stops the mouse and a press never reached the handler the tests called.
	var window: SubViewport = _open_in_a_viewport()
	var cards: Array[int] = _screen.hand_strip().order()
	var at: Vector2 = _on(cards[3])
	var down: Vector2 = _regions["hero_hand"].position + Vector2(20, 100)

	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))
	assert_true(_screen.hand_strip().is_pressing(), "The press reached the hand.")
	window.push_input(_motion(FIELD))
	assert_true(_screen.hand_strip().is_holding())
	assert_not_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
	window.push_input(_motion(down))
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, down))

	assert_false(_screen.hand_strip().is_holding())
	assert_eq(_screen.hand_strip().order()[0], cards[3], "It was put down at the left end.")


func test_a_real_double_click_plays_a_card_and_a_real_right_click_cancels_a_drag() -> void:
	var window: SubViewport = _open_in_a_viewport()
	var click: InputEventMouseButton = _button(MOUSE_BUTTON_LEFT, true, _on(_card("Forest")))
	click.double_click = true

	window.push_input(click)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1)

	var cards: Array[int] = _screen.hand_strip().order()
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, FIELD))
	# The hand parted around the double-click; with the mouse away it closes up again.
	window.push_input(_motion(FIELD))
	_settle_hand()
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, _on(cards[2])))
	window.push_input(_motion(FIELD))
	assert_true(_screen.hand_strip().is_holding())
	window.push_input(_button(MOUSE_BUTTON_RIGHT, true, FIELD))
	assert_false(_screen.hand_strip().is_holding())
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
	var card_id: int = _screen.hand_strip().card_under(over)
	var card: Rect2 = Rect2(_face(card_id).position, _face(card_id).size)
	var both: Rect2 = card.intersection(land)
	assert_gt(both.size.y, 8.0, "The risen card overlaps the land.")
	var at: Vector2 = Vector2(over.x, both.get_center().y)
	assert_eq(_screen.hand_strip().card_under(at), card_id)
	var before: EncounterSnapshot = _presenter.snapshot()

	window.push_input(_motion(at))
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))

	assert_true(_screen.hand_strip().is_pressing())
	assert_eq(_screen.hand_strip().pressed(), card_id)
	assert_eq(_presenter.snapshot(), before, "The land under it was not tapped.")
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, at))


func test_a_real_press_made_before_the_hand_has_caught_up_with_the_cursor_still_picks_up_the_card() -> void:
	# The hand eases toward the cursor over several frames, and fewer when a frame is slow.
	# A press made on arriving, on the strip a card is about to rise into, used to miss: it
	# was tested against where the card was still drawn, not where the cursor was sending it.
	var window: SubViewport = _open_in_a_viewport()
	window.push_input(_motion(FIELD))
	_settle_hand()
	var cards: Array[int] = _screen.hand_strip().order()
	var rest: Vector2 = _face(cards[3]).position
	var at: Vector2 = rest + Vector2(30, -20)
	assert_false(Rect2(rest, _face(cards[3]).size).grow(8.0).has_point(at), "Above where the card is drawn at rest,")

	window.push_input(_motion(at))
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))
	window.push_input(_motion(FIELD))

	assert_true(_screen.hand_strip().is_holding(), "All three arrived in one slow frame, and the card is held.")
	assert_eq(_screen.hand_strip().held(), cards[3])
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, FIELD))


func test_a_real_second_try_right_after_a_first_is_still_a_drag() -> void:
	# Two presses close together arrive marked as a double-click. On a card that cannot be
	# played that must not swallow the drag.
	var window: SubViewport = _open_in_a_viewport()
	_screen.press_hand(_on(_card("Forest")), true)
	_presenter.wait_until_idle()
	window.push_input(_motion(FIELD))
	_settle_hand()
	var cards: Array[int] = _screen.hand_strip().order()
	var second: int = _card("Forest")
	var at: Vector2 = _on(second)
	var again: InputEventMouseButton = _button(MOUSE_BUTTON_LEFT, true, at)
	again.double_click = true
	var before: EncounterSnapshot = _presenter.snapshot()

	window.push_input(again)
	window.push_input(_motion(_regions["hero_hand"].position + Vector2(20, 100)))
	assert_true(_screen.hand_strip().is_holding())
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, _regions["hero_hand"].position + Vector2(20, 100)))

	assert_eq(_screen.hand_strip().order()[0], second)
	assert_ne(_screen.hand_strip().order(), cards)
	assert_eq(_presenter.snapshot(), before, "Nothing was played.")


func test_a_real_press_on_a_window_over_the_hand_is_the_windows() -> void:
	var window: SubViewport = _open_in_a_viewport()
	var cards: Array[int] = _screen.hand_strip().order()
	var at: Vector2 = _on(cards[3])
	var emblems: ZoneWindow = _screen.emblems_window(HERO)
	emblems.show()
	emblems.position = at - Vector2(100, 100)
	emblems.size = Vector2(300, 220)

	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))

	assert_false(_screen.hand_strip().is_pressing(), "A card under a window is not picked up through it.")
	emblems.hide()
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))
	assert_true(_screen.hand_strip().is_pressing(), "With the window gone, it is.")


func test_a_held_card_stays_held_while_the_board_is_rebuilt_under_it() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	var at: Vector2 = _on(forest)
	_screen.press_hand(at, false)
	_screen.drag_to(FIELD)
	var before: Control = _screen.hand_strip().face_of(_screen.hand_strip().held())
	var place: Vector2 = before.position

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	var after: CardFace = _screen.hand_strip().face_of(_screen.hand_strip().held())
	assert_eq(after, before, "The Hand Strip keeps its faces through a redraw (13j)")
	assert_false(before.is_queued_for_deletion())
	assert_eq(after.position, place, "and it stays where it is held")
	assert_eq(after.rotation, 0.0)
	assert_gt(after.get_parent().get_index(), _screen.stack_window().get_index())
	assert_eq(after.get_parent().get_child_count(), 1)
	assert_eq(BorderEffects.glow_color(after), DecisionClicks.bright_color_of(DecisionClicks.Kind.PLAY))
	assert_eq(_screen.info_panel().option_text(), "Release to play Forest")
	assert_eq(_screen.face_of(_seen(forest).id), after)
	assert_eq(_row_cards().size(), 6, "and the row is drawn without it.")
	_screen.release_hand(FIELD)
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1, "It can still be played.")


func test_a_held_card_that_leaves_the_hand_is_no_longer_held() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	_screen.press_hand(_on(forest), false)
	_screen.drag_to(FIELD)

	_presenter.answer(_screen._hand_options(forest)[0].answer)
	_presenter.wait_until_idle()

	assert_false((_screen.hand_strip().held() != DragCard.NONE), "A380.")
	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
	assert_eq(_row_cards().size(), 6)
	_screen.release_hand(FIELD)
	assert_eq(_permanents("Forest").size(), 1, "Letting go afterwards plays nothing more.")


func test_choosing_from_the_option_menu_plays_the_waiting_card() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	_two_ways(forest)
	_screen.press_hand(_on(forest), false)
	_screen.release_hand(FIELD)

	_screen.option_menu().rows()[1].pressed.emit()
	_presenter.wait_until_idle()

	assert_eq(_permanents("Forest").size(), 1)
	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
	assert_false((_screen.hand_strip().held() != DragCard.NONE))
	assert_false(_screen.option_menu().is_open())


func test_a_redraw_while_a_card_waits_sends_it_back_to_the_hand() -> void:
	_open(_forests_and_bears())
	var cards: Array[int] = _screen.hand_strip().order()
	var forest: int = _card("Forest")
	_two_ways(forest)
	_screen.press_hand(_on(forest), false)
	_screen.release_hand(FIELD)

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	assert_false(_screen.option_menu().is_open(), "Anything open over the board closes on a redraw.")
	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()))
	assert_eq(_row_cards(), cards)


func test_a_double_click_on_a_card_with_several_ways_opens_the_option_menu_at_the_card() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	_two_ways(forest)

	_screen.press_hand(_on(forest), true)

	assert_true(_screen.option_menu().is_open())
	assert_eq(_screen.option_menu().rows().size(), 2)
	assert_null(_screen.hand_strip().face_of(_screen.hand_strip().held()), "The card stays in the hand (A377).")
	assert_eq(_row_cards().size(), 7)
	_screen.option_menu().rows()[0].pressed.emit()
	_presenter.wait_until_idle()
	assert_eq(_permanents("Forest").size(), 1)


func test_a_canceled_cast_and_an_undo_put_the_card_back_where_it_was() -> void:
	_open(_setup_of([Scenario.basic_land("Forest"), Scenario.free_shock("Zap", 2)]))
	var cards: Array[int] = _screen.hand_strip().order()
	var zap: int = _card("Zap")
	var place: int = cards.find(zap)

	_screen.press_hand(_on(zap), true)
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision)
	assert_false(_screen.hand_strip().order().has(zap))
	_screen.info_panel().cancel_button().pressed.emit()
	assert_eq(_screen.hand_strip().order(), cards, "A379: by Card Identity, though it is a new Game Object.")
	assert_eq(_row_cards(), cards)
	assert_eq(place, _screen.hand_strip().order().find(zap))

	_screen.press_hand(_on(zap), false)
	_screen.release_hand(_regions["info"].get_center())
	assert_eq(_screen.hand_strip().order()[0], zap, "Put at the left end.")
	var moved: Array[int] = _screen.hand_strip().order()
	var forest: int = _card("Forest")
	_screen.press_hand(_on(forest), true)
	_presenter.wait_until_idle()
	assert_false(_screen.hand_strip().order().has(forest))
	_screen.undo()
	assert_eq(_screen.hand_strip().order(), moved, "The undo brings the card back, and does not undo the rearranging (A374).")


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
	for card_id: int in _screen.hand_strip().order():
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
		if face != null and face != _screen.hand_strip().face_of(_screen.hand_strip().held()):
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
		_screen.hand_strip().frame(1.0 / 60.0, _screen.get_local_mouse_position())


## Gives the card in hand with Card Identity [param card_id] a second way to be played, as
## the first card with two will have: the same answer again under another name.
func _two_ways(card_id: int) -> void:
	var clicks: DecisionClicks = _screen._clicks
	var options: Array[ClickOption] = clicks.hand_options_of(_seen(card_id).id)
	clicks._hand_options[_seen(card_id).id] = [options[0], ClickOption.new(options[0].answer, options[0].text + " another way")]
	# The Hand Strip is shown what each card offers, so it is shown the hand again.
	_screen._show_hand()


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
