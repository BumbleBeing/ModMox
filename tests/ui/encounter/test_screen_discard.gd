extends GutTest
## Discarding at cleanup on the Encounter Screen (13e-2): cards are chosen in the hand's
## strip with single clicks, the pass button confirms them and undo takes back a click.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const GREEN: Color = Color("#7be36a")

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	await wait_process_frames(2)


func test_at_cleanup_the_hand_glows_and_the_pass_button_waits_to_confirm_the_discard() -> void:
	_open_at_discard(2)

	assert_eq(_screen.info_panel().prompt_text(), "Discard 2 cards (0 chosen)")
	assert_eq(_screen.pass_button().text, "Confirm discard [SPACE]")
	assert_true(_screen.pass_button().disabled)
	assert_false(_screen.opening_overlay().visible, "The board stays in sight.")
	for card_id: int in _screen.hand_order().cards():
		assert_eq(BorderEffects.glow_color(_face(card_id)), GREEN)
		assert_null(ClickCatcher.of(_face(card_id)), "The hand takes its presses in _input().")
	assert_eq(_screen.hand_order().cards().size(), 9)


func test_a_click_raises_a_card_with_a_white_glow_and_a_second_click_lowers_it() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	var rest: float = _face(cards[3]).position.y

	_click(cards[3])

	assert_eq(_screen.card_picks().picked(), [_seen(cards[3]).id] as Array[int])
	assert_eq(BorderEffects.glow_color(_face(cards[3])), Color.WHITE, "A401.")
	assert_eq(BorderEffects.glow_color(_face(cards[2])), GREEN)
	assert_eq(_screen.info_panel().prompt_text(), "Discard 2 cards (1 chosen)")
	assert_true(_screen.pass_button().disabled, "One more to go.")
	assert_false(_screen.undo_button().disabled)
	_settle_hand()
	var raised: float = rest - _face(cards[3]).size.y * EncounterLayout.PICKED_RISE
	assert_almost_eq(_screen.hand_places(Vector2(900, 300))[3].y, raised, 0.01, "A quarter of its height above the rest.")
	assert_almost_eq(_face(cards[3]).position.y, raised, 1.0)
	assert_true(_presenter.snapshot().decision is ChooseCardsToDiscardDecision, "Nothing is answered yet.")

	_click(cards[3])

	assert_eq(_screen.card_picks().picked(), [] as Array[int])
	assert_eq(BorderEffects.glow_color(_face(cards[3])), GREEN)
	assert_eq(_screen.info_panel().prompt_text(), "Discard 2 cards (0 chosen)")
	_settle_hand()
	assert_almost_eq(_face(cards[3]).position.y, rest, 1.0)


func test_nothing_is_rebuilt_for_a_click_so_the_card_eases_up() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	var face: Control = _face(cards[1])
	var before: float = face.position.y

	_click(cards[1])

	assert_eq(_face(cards[1]), face, "The same face.")
	assert_eq(face.position.y, before, "It has not jumped.")
	_screen._spread_hand(0.3)
	assert_lt(face.position.y, before)
	assert_gt(face.position.y, before - face.size.y * EncounterLayout.PICKED_RISE)


func test_with_enough_chosen_another_click_does_nothing_and_the_rest_stop_glowing() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	_click(cards[0])
	_click(cards[5])

	_click(cards[7])

	assert_eq(_screen.card_picks().picked(), [_seen(cards[0]).id, _seen(cards[5]).id] as Array[int])
	assert_null(BorderEffects.glow_color(_face(cards[7])), "It cannot be chosen while two are.")
	assert_eq(BorderEffects.glow_color(_face(cards[0])), Color.WHITE)
	assert_false(_screen.pass_button().disabled)
	assert_eq(_screen.info_panel().prompt_text(), "Discard 2 cards (2 chosen)")
	_click(cards[0])
	assert_eq(BorderEffects.glow_color(_face(cards[7])), GREEN, "Letting one go opens the rest again.")
	assert_true(_screen.pass_button().disabled)


func test_undo_takes_back_the_last_click_and_then_has_nothing_to_take_back() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	assert_true(_screen.undo_button().disabled)
	_click(cards[2])
	_click(cards[4])

	_screen.undo_button().pressed.emit()

	assert_eq(_screen.card_picks().picked(), [_seen(cards[2]).id] as Array[int])
	assert_eq(BorderEffects.glow_color(_face(cards[4])), GREEN)
	assert_eq(_screen.info_panel().prompt_text(), "Discard 2 cards (1 chosen)")
	_screen.press_key(KEY_Z)
	assert_eq(_screen.card_picks().picked(), [] as Array[int])
	assert_true(_screen.undo_button().disabled)
	assert_true(_presenter.snapshot().decision is ChooseCardsToDiscardDecision)


func test_confirming_discards_the_chosen_cards_and_no_others() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	var kept: Array[int] = cards.duplicate()
	kept.erase(cards[1])
	kept.erase(cards[6])
	_click(cards[6])
	_click(cards[1])

	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseCardsToDiscardDecision)
	assert_eq(_presenter.snapshot().view.graveyards[HERO].size(), 2)
	var discarded: Array[int] = []
	for card: MmObjectView in _presenter.snapshot().view.graveyards[HERO]:
		discarded.append(card.card_id)
	assert_true(discarded.has(cards[1]) and discarded.has(cards[6]))
	assert_false(_screen.card_picks().is_active())
	assert_eq(_screen.pass_button().text, "Pass Priority [SPACE]")


func test_space_confirms_only_once_enough_are_chosen() -> void:
	_open_at_discard(1)
	var cards: Array[int] = _screen.hand_order().cards()

	var asked: EncounterSnapshot = _presenter.snapshot()
	_screen.press_key(KEY_SPACE)
	_screen.pass_priority()
	assert_eq(_presenter.snapshot(), asked, "No answer was sent, so none was refused.")
	assert_eq(_screen.info_panel().error_text(), "")
	_click(cards[0])
	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseCardsToDiscardDecision)


func test_a_press_that_moves_is_a_drag_that_rearranges_the_hand_and_chooses_nothing() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	var at: Vector2 = _on(cards[0])
	var strip: Rect2 = EncounterLayout.regions(SCREEN)["hero_hand"]

	_screen.press_hand(at, false)
	_screen.drag_to(at + Vector2(4, 0))
	_screen.drag_to(Vector2(strip.end.x - 20.0, at.y))
	_screen.release_hand(Vector2(strip.end.x - 20.0, at.y))

	assert_eq(_screen.card_picks().picked(), [] as Array[int])
	assert_eq(_screen.hand_order().cards().back(), cards[0], "It went to the right end.")
	assert_eq(BorderEffects.glow_color(_face(cards[0])), GREEN, "And still can be chosen.")


func test_a_chosen_card_stays_chosen_and_raised_when_the_hand_is_rearranged() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	_click(cards[8])
	_settle_hand()
	var at: Vector2 = _on(cards[0])
	var strip: Rect2 = EncounterLayout.regions(SCREEN)["hero_hand"]

	_screen.press_hand(at, false)
	_screen.drag_to(at + Vector2(4, 0))
	_screen.drag_to(Vector2(strip.end.x - 20.0, at.y))
	_screen.release_hand(Vector2(strip.end.x - 20.0, at.y))
	_settle_hand()

	assert_eq(_screen.card_picks().picked(), [_seen(cards[8]).id] as Array[int])
	assert_eq(BorderEffects.glow_color(_face(cards[8])), Color.WHITE)
	assert_lt(_face(cards[8]).position.y, _face(cards[7]).position.y - 30.0, "Still standing above its neighbor.")


func test_a_double_click_is_two_clicks() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	var at: Vector2 = _on(cards[2])

	_screen.press_hand(at, false)
	_screen.release_hand(at)
	_screen.press_hand(at, true)
	_screen.release_hand(at)

	assert_eq(_screen.card_picks().picked(), [] as Array[int], "Chosen, then let go: neither press was swallowed.")
	assert_false(_screen.option_menu().is_open())


func test_a_click_chooses_nothing_while_paused_or_at_priority() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()

	_screen.press_key(KEY_ESCAPE)
	_screen._click_hand(cards[0])
	assert_eq(_screen.card_picks().picked(), [] as Array[int])
	_screen.press_key(KEY_ESCAPE)
	_click(cards[0])
	_click(cards[1])
	_screen.pass_button().pressed.emit()
	_presenter.wait_until_idle()
	_pass_until(func() -> bool: return _presenter.snapshot().decision is PriorityDecision)

	var first: int = _screen.hand_order().cards()[0]
	_click(first)

	assert_false(_screen.card_picks().is_active())
	assert_ne(BorderEffects.glow_color(_face(first)), Color.WHITE, "One click at priority does nothing (A371).")
	assert_eq(_face(first).position.y, _screen.hand_places(Vector2(900, 300))[0].y, "And raises nothing.")


func test_a_redraw_draws_the_chosen_cards_raised_and_white_again() -> void:
	_open_at_discard(2)
	var cards: Array[int] = _screen.hand_order().cards()
	_click(cards[4])
	_settle_hand()
	var raised: float = _face(cards[4]).position.y

	_screen._redraw()

	assert_eq(BorderEffects.glow_color(_face(cards[4])), Color.WHITE)
	assert_almost_eq(_face(cards[4]).position.y, raised, 1.0, "A redraw puts it straight at its place.")
	assert_eq(_screen.pass_button().text, "Confirm discard [SPACE]")
	assert_eq(_screen.info_panel().prompt_text(), "Discard 2 cards (1 chosen)")
	assert_false(_screen.undo_button().disabled)


func test_a_real_press_and_release_in_place_chooses_a_card_and_a_real_drag_does_not() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_open_at_discard(2, window)
	var cards: Array[int] = _screen.hand_order().cards()
	var at: Vector2 = _on(cards[3])
	var strip: Rect2 = EncounterLayout.regions(SCREEN)["hero_hand"]

	window.push_input(_motion(at))
	window.push_input(_button(true, at))
	window.push_input(_button(false, at))

	assert_eq(_screen.card_picks().picked(), [_seen(cards[3]).id] as Array[int])
	assert_eq(BorderEffects.glow_color(_face(cards[3])), Color.WHITE)

	# The cursor leaves the hand, so the cards close up and each is where it rests.
	window.push_input(_motion(Vector2(1000, 400)))
	_settle_hand()
	var other: Vector2 = _on(cards[6])
	window.push_input(_motion(other))
	window.push_input(_button(true, other))
	window.push_input(_motion(other + Vector2(5, 0)))
	window.push_input(_motion(Vector2(strip.position.x + 10.0, other.y)))
	window.push_input(_button(false, Vector2(strip.position.x + 10.0, other.y)))

	assert_eq(_screen.card_picks().picked(), [_seen(cards[3]).id] as Array[int], "A drag chooses nothing.")
	assert_eq(_screen.hand_order().cards()[0], cards[6], "It rearranged the hand.")


func test_a_real_click_on_the_raised_part_of_a_chosen_card_lets_it_go() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_open_at_discard(2, window)
	var cards: Array[int] = _screen.hand_order().cards()
	_click(cards[4])
	_settle_hand()
	var top_edge: Vector2 = _face(cards[4]).position + Vector2(30, 12)
	assert_lt(top_edge.y, EncounterLayout.regions(SCREEN)["hero_hand"].position.y + 5.0, "Above where an unchosen card reaches at rest.")

	window.push_input(_motion(top_edge))
	window.push_input(_button(true, top_edge))
	window.push_input(_button(false, top_edge))

	assert_eq(_screen.card_picks().picked(), [] as Array[int], "It is hit where it is drawn.")


## Opens an encounter and passes to the Hero's first cleanup with [param count] cards too
## many: the Hero is on the draw, plays nothing, and the setup deals what is needed.
func _open_at_discard(count: int, parent: Node = null) -> void:
	var setup: MmEncounterSetup = Scenario.setup(MmEncounterSetup.StartingPlayerRule.VILLAIN_STARTS)
	setup.hero.opening_hand_size = 6 + count
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	if parent == null:
		add_child_autofree(_screen)
	else:
		parent.add_child(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(setup, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_pass_until(func() -> bool: return _presenter.snapshot().decision is ChooseCardsToDiscardDecision)
	assert_eq((_presenter.snapshot().decision as ChooseCardsToDiscardDecision).count, count)


func _pass_until(is_there: Callable) -> void:
	for attempt: int in 200:
		if is_there.call():
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


func _seen(card_id: int) -> MmObjectView:
	for card: MmObjectView in _presenter.snapshot().view.hand:
		if card.card_id == card_id:
			return card
	return null


func _face(card_id: int) -> Control:
	return _screen.face_of(_seen(card_id).id)


## A place on the part of the card with Card Identity [param card_id] that no other covers.
func _on(card_id: int) -> Vector2:
	return _face(card_id).position + Vector2(30, 60)


## Presses the card and lets go in place, as one click does.
func _click(card_id: int) -> void:
	_screen.press_hand(_on(card_id), false)
	_screen.release_hand(_on(card_id))


func _settle_hand() -> void:
	for frame: int in 60:
		_screen._spread_hand(0.3)


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


func _button(is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click
