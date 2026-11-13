extends GutTest
## The Inspector on the Encounter Screen (13h, ADR 0033): a right-click pins a card, and
## the Inspector takes the sidebar's place until the card is let go. Hovering shows
## nothing (A472).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const FIELD: Vector2 = Vector2(1000, 500)

var _presenter: EncounterPresenter
var _screen: EncounterScreen
var _regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)


func after_each() -> void:
	await wait_process_frames(2)


func test_the_inspector_is_hidden_until_a_card_is_right_clicked() -> void:
	_open(_forests_and_bears())
	assert_false(_screen.inspector().visible)

	_screen.right_click_at(_on(_card("Bear")))

	var inspector: Inspector = _screen.inspector()
	assert_true(inspector.visible)
	assert_eq(inspector.shown_key(), _seen(_card("Bear")).id)
	assert_eq(inspector.shown_look().name, "Bear")
	assert_eq(inspector.position, _regions["sidebar"].position, "It takes the sidebar's place.")
	assert_eq(inspector.size, _regions["sidebar"].size)


func test_it_lies_over_the_player_panels_and_under_every_window() -> void:
	_open(_forests_and_bears())
	var index: int = _screen.inspector().get_index()

	assert_gt(index, _screen.player_panel(HERO).get_index())
	assert_gt(index, _screen.player_panel(VILLAIN).get_index())
	assert_lt(index, _screen.stack_window().get_index())
	assert_lt(index, _screen.emblems_window(HERO).get_index())
	assert_lt(index, _screen.opening_overlay().get_index())


func test_empty_space_pins_nothing() -> void:
	_open(_forests_and_bears())

	_screen.right_click_at(FIELD)

	assert_eq(_screen.inspectable_at(FIELD), Inspection.NOTHING)
	assert_false(_screen.inspector().visible)


func test_a_card_in_hand_glows_in_its_rarity_and_has_its_original() -> void:
	var dragon: MmCardDefinition = load("res://content/cards/alpha/shivan_dragon.tres") as MmCardDefinition
	_open(_setup_of([Scenario.basic_land("Forest"), dragon]))

	_screen.right_click_at(_on(_card("Shivan Dragon")))

	var inspector: Inspector = _screen.inspector()
	assert_eq(BorderEffects.glow_color(inspector.face()), Inspector.glow_of(MmCardDefinition.Rarity.RARE))
	assert_false(inspector.original_button().disabled)
	assert_eq(inspector.reminder_keywords(), ["Flying"])


func test_a_permanent_is_inspected_with_its_state_list() -> void:
	_open(_forests_and_bears())
	_play("Bear")
	var bear: int = _permanents("Bear")[0]

	_screen.right_click_at(_on_permanent(bear))

	assert_eq(_screen.inspector().shown_key(), bear)
	assert_eq(_screen.inspector().state_texts()[0][0], "Summoning sick")
	assert_true(_screen.inspector().state_scroll().visible)


func test_a_new_snapshot_redraws_the_card_being_shown() -> void:
	_open(_forests_and_bears())
	_play("Bear")
	var bear: int = _permanents("Bear")[0]
	_screen.right_click_at(_on_permanent(bear))
	var turn: int = _presenter.snapshot().view.game_turn

	_pass_until(func() -> bool:
		return _presenter.snapshot().view.game_turn > turn + 1 and _presenter.snapshot().view.active_player_id == HERO)

	assert_eq(_screen.inspector().shown_key(), bear)
	assert_eq(_screen.inspector().state_texts().size(), 0, "It is no longer summoning sick.")


func test_the_villains_hand_and_a_library_are_never_inspected() -> void:
	_open(_forests_and_bears())

	assert_eq(_screen.inspectable_at(_regions["villain_hand"].get_center()), Inspection.NOTHING)
	assert_eq(_screen.inspectable_at(_regions["hero_library"].get_center()), Inspection.NOTHING)
	assert_eq(_screen.inspectable_at(_regions["villain_library"].get_center()), Inspection.NOTHING)


func test_a_right_click_pins_the_card_and_rings_it() -> void:
	_open(_forests_and_bears())
	var bear: int = _card("Bear")

	_screen.right_click_at(_on(bear))

	assert_eq(_screen.inspection().pinned(), _seen(bear).id)
	assert_true(_screen.inspector().visible)
	assert_true(BorderEffects.has_pin(_face(bear)), "The ring is part of the card, so a card over it covers the ring too.")


func test_the_ring_follows_the_pinned_card_through_a_redraw() -> void:
	_open(_forests_and_bears())
	var bear: int = _card("Bear")
	_screen.right_click_at(_on(bear))

	_presenter.toggle_stop(HERO, MmTurn.Step.UPKEEP)

	assert_true(BorderEffects.has_pin(_face(bear)), "The face is a new node.")
	assert_true(_screen.inspector().visible)


func test_a_right_click_on_another_card_pins_that_one_instead() -> void:
	_open(_forests_and_bears())
	var bear: int = _card("Bear")
	var forest: int = _card("Forest")
	_screen.right_click_at(_on(bear))

	_screen.right_click_at(_on(forest))

	assert_eq(_screen.inspector().shown_look().name, "Forest")
	assert_true(BorderEffects.has_pin(_face(forest)))
	assert_false(BorderEffects.has_pin(_face(bear)))


func test_a_second_right_click_or_one_on_empty_space_lets_the_card_go() -> void:
	_open(_forests_and_bears())
	var bear: int = _card("Bear")
	_screen.right_click_at(_on(bear))
	_screen.right_click_at(_on(bear))
	assert_eq(_screen.inspection().pinned(), Inspection.NOTHING)
	assert_false(BorderEffects.has_pin(_face(bear)))

	_screen.right_click_at(_on(bear))
	_screen.right_click_at(FIELD)

	assert_eq(_screen.inspection().pinned(), Inspection.NOTHING)
	assert_false(_screen.inspector().visible)


func test_a_right_click_on_the_inspector_itself_changes_nothing() -> void:
	_open(_forests_and_bears())
	var bear: int = _card("Bear")
	_screen.right_click_at(_on(bear))

	_screen.right_click_at(_regions["sidebar"].get_center())

	assert_eq(_screen.inspection().pinned(), _seen(bear).id)


func test_escape_lets_the_pinned_card_go_before_it_pauses() -> void:
	_open(_forests_and_bears())
	_screen.right_click_at(_on(_card("Bear")))

	_screen.press_key(KEY_ESCAPE)
	assert_eq(_screen.inspection().pinned(), Inspection.NOTHING)
	assert_false(_screen.is_paused())

	_screen.press_key(KEY_ESCAPE)
	assert_true(_screen.is_paused())
	_screen.press_key(KEY_ESCAPE)


func test_space_and_z_still_work_while_a_card_is_pinned() -> void:
	_open(_forests_and_bears())
	_play("Forest")
	_screen.right_click_at(_on(_card("Bear")))
	var step: MmTurn.Step = _presenter.snapshot().view.step

	_screen.press_key(KEY_SPACE)
	_presenter.wait_until_idle()

	assert_ne(_presenter.snapshot().view.step, step, "Space passed priority.")


func test_nothing_is_pinned_while_the_game_is_paused() -> void:
	_open(_forests_and_bears())
	_screen.set_paused(true)

	_screen.right_click_at(_on(_card("Bear")))

	assert_false(_screen.inspector().visible)
	_screen.set_paused(false)


func test_nothing_is_pinned_while_a_card_is_dragged() -> void:
	_open(_forests_and_bears())
	var bear: int = _card("Bear")
	_screen.press_hand(_on(bear), false)
	_screen.drag_to(FIELD)
	assert_true(_screen.drag_card().is_holding())

	_screen.right_click_at(_on(_card("Forest")))

	assert_eq(_screen.inspection().pinned(), Inspection.NOTHING)
	assert_false(_screen.inspector().visible, "A460: the player panels stay for the whole drag.")
	_screen.cancel_drag()


func test_a_pinned_card_that_leaves_its_zone_is_let_go() -> void:
	_open(_forests_and_bears())
	var forest: int = _card("Forest")
	_screen.right_click_at(_on(forest))
	assert_ne(_screen.inspection().pinned(), Inspection.NOTHING)

	_screen.press_hand(_on(forest), true)
	_presenter.wait_until_idle()

	assert_eq(_screen.inspection().pinned(), Inspection.NOTHING, "It is a new object on the battlefield.")


func test_a_card_of_the_opening_hand_is_inspected_and_pinned() -> void:
	_open_pregame(_forests_and_bears())
	var overlay: OpeningHandOverlay = _screen.opening_overlay()
	assert_true(overlay.is_open())
	var first: int = overlay.shown_ids()[0]
	var at: Vector2 = overlay.position + overlay.center_of(first)

	_screen.right_click_at(at)
	assert_eq(_screen.inspector().shown_key(), first)
	assert_eq(_screen.inspection().pinned(), first)
	assert_true(BorderEffects.has_pin(overlay.face_of(first)))
	_screen.let_pinned_go()


func test_an_emblem_is_inspected_from_its_window_with_no_original() -> void:
	var setup: MmEncounterSetup = _forests_and_bears()
	setup.hero.emblems = [Scenario.emblem("Boon", [FlyingAbility.new()] as Array[MmAbility])] as Array[MmCardDefinition]
	_open(setup)
	_screen.player_panel(HERO).emblems_button().pressed.emit()
	await wait_process_frames(2)
	var row: Control = _screen.emblems_window(HERO).body().get_child(0) as Control

	_screen.right_click_at(row.get_global_rect().get_center() - _screen.global_position)

	var inspector: Inspector = _screen.inspector()
	assert_eq(inspector.shown_look().name, "Boon")
	assert_true(inspector.original_button().disabled)
	assert_false(inspector.original_button().visible, "An Emblem has no Original to see (ADR 0033).")
	assert_null(inspector.face(), "It is drawn on an Emblem Face, not a Card Face.")
	assert_eq(inspector.emblem_face().name_text(), "Boon")
	assert_eq(inspector.emblem_face().type_line_text(), "Emblem")


func test_an_ability_on_the_stack_is_read_as_the_card_it_came_from() -> void:
	_open(_setup_of([Scenario.life_land()]))
	_screen.press_hand(_on(_card("Life Land")), true)
	_presenter.wait_until_idle()
	var decision: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	for index: int in decision.actions.size():
		if decision.actions[index] is ActivateAbilityAction:
			_presenter.answer(index)
			break
	_presenter.wait_until_idle()
	await wait_process_frames(2)
	assert_eq(_presenter.snapshot().view.stack.size(), 1, "It is on the stack while its target is chosen.")
	var ability: int = _presenter.snapshot().view.stack[0].id
	var land: int = _permanents("Life Land")[0]
	var entry: StackEntry = _screen.stack_entry_of(ability)

	_screen.right_click_at(entry.get_global_rect().get_center() - _screen.global_position)

	assert_eq(_screen.inspector().shown_key(), ability)
	assert_eq(_screen.inspector().shown_look(), _presenter.snapshot().look_of(land), "The land as it is now.")
	assert_false(_screen.inspector().original_button().disabled)


func test_a_real_right_click_pins_and_a_real_left_click_lets_go_and_still_plays() -> void:
	var window: SubViewport = _open_in_a_viewport()
	var bear: int = _card("Bear")
	var forest: int = _card("Forest")

	window.push_input(_button(MOUSE_BUTTON_RIGHT, true, _on(bear)))
	assert_eq(_screen.inspection().pinned(), _seen(bear).id)
	assert_true(_screen.inspector().visible)

	var click: InputEventMouseButton = _button(MOUSE_BUTTON_LEFT, true, _on(forest))
	click.double_click = true
	window.push_input(click)
	_presenter.wait_until_idle()

	assert_eq(_screen.inspection().pinned(), Inspection.NOTHING, "A459: a left-click anywhere else lets go.")
	assert_eq(_permanents("Forest").size(), 1, "A461: and the click still did what it does.")
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, FIELD))


func test_a_real_left_click_on_the_inspector_keeps_the_card_pinned() -> void:
	var window: SubViewport = _open_in_a_viewport()
	var bear: int = _card("Bear")
	window.push_input(_button(MOUSE_BUTTON_RIGHT, true, _on(bear)))
	var at: Vector2 = _regions["sidebar"].get_center()

	window.push_input(_button(MOUSE_BUTTON_LEFT, true, at))
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, at))

	assert_eq(_screen.inspection().pinned(), _seen(bear).id)


func test_a_real_right_click_while_a_card_is_held_puts_it_down_and_pins_nothing() -> void:
	var window: SubViewport = _open_in_a_viewport()
	var bear: int = _card("Bear")
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, _on(bear)))
	window.push_input(_motion(FIELD))
	assert_true(_screen.drag_card().is_holding())

	window.push_input(_button(MOUSE_BUTTON_RIGHT, true, _on(_card("Forest"))))

	assert_false(_screen.drag_card().is_holding())
	assert_eq(_screen.inspection().pinned(), Inspection.NOTHING)


func test_a_real_cursor_over_a_card_shows_nothing() -> void:
	var window: SubViewport = _open_in_a_viewport()

	window.push_input(_motion(_on(_card("Bear"))))
	await wait_process_frames(3)

	assert_false(_screen.inspector().visible, "A472: only a right-click shows the Inspector.")
	window.push_input(_motion(FIELD))
	await wait_process_frames(3)


func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	return motion


func _button(button: MouseButton, is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = button
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click


func _open_in_a_viewport() -> SubViewport:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_open(_forests_and_bears(), window)
	return window


## Opens the screen and stops at the opening hand, before it is kept.
func _open_pregame(setup: MmEncounterSetup, parent: Node = null) -> void:
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
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()


func _open(setup: MmEncounterSetup, parent: Node = null) -> void:
	_open_pregame(setup, parent)
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_pass_until(func() -> bool:
		return _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN and _presenter.snapshot().view.active_player_id == HERO)


func _forests_and_bears() -> MmEncounterSetup:
	return _setup_of([Scenario.basic_land("Forest"), Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))])


func _setup_of(cards: Array[MmCardDefinition]) -> MmEncounterSetup:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	return Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40))


## Plays or casts the card of the hand named [param card_name] and lets it resolve.
func _play(card_name: String) -> void:
	var count: int = _presenter.snapshot().view.battlefield.size()
	_screen.press_hand(_on(_card(card_name)), true)
	_presenter.wait_until_idle()
	_pass_until(func() -> bool: return _presenter.snapshot().view.battlefield.size() > count)


func _seen(card_id: int) -> MmObjectView:
	for card: MmObjectView in _presenter.snapshot().view.hand:
		if card.card_id == card_id:
			return card
	return null


func _card(card_name: String) -> int:
	for card_id: int in _screen.hand_order().cards():
		if _seen(card_id).name == card_name:
			return card_id
	return DragCard.NONE


func _face(card_id: int) -> Control:
	return _screen.face_of(_seen(card_id).id)


func _on(card_id: int) -> Vector2:
	return _face(card_id).position + Vector2(30, 60)


func _on_permanent(object_id: int) -> Vector2:
	var face: Control = _screen.face_of(object_id)
	return face.get_global_rect().get_center() - _screen.global_position


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
