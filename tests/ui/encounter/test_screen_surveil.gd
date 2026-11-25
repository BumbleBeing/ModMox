extends GutTest
## Surveilling on the Encounter Screen (game ADR 0069). As a surveil resolves, the Surveil
## window opens by itself, titled "Surveil N", with the cards surveilled face up in a row,
## leftmost on top. A drag orders the row; a click selects a card, which glows white, and a
## second lets it go; "Graveyard" flies the selected card straight onto the Hero's Graveyard
## pile. Only the pass button, "Done", answers: the cards sent, in the order sent, then the
## row. Undo takes back the last sending or move. Thespian is a 3/1 costing {0}, "When this
## creature enters or dies, surveil N."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const GREEN: Color = Color("#7be36a")
const FLIGHT: float = 0.4

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_surveil_opens_the_surveil_window_by_itself_with_the_cards_in_library_order() -> void:
	_open_surveilling(2)

	var window: SurveilWindow = _screen.surveil_window()
	var asked: SurveilDecision = _surveil()
	assert_true(window.is_open(), "Opened by the surveil itself.")
	assert_eq(window.title_text(), "Surveil 2")
	assert_null(window.close_button(), "It has no close button.")
	assert_eq(window.entries(), asked.card_ids, "Leftmost on top.")
	for object_id: int in asked.card_ids:
		assert_eq(BorderEffects.glow_colors(window.face_of(object_id)), [GREEN] as Array[Color])
	assert_true(window.graveyard_button().disabled, "Nothing is selected.")
	assert_eq(window.graveyard_button().text, "Graveyard")
	assert_eq(_screen.info_panel().prompt_text(),
		"Surveil: graveyard any of these, and order the rest. The leftmost will be on top.")
	assert_eq(_screen.pass_button().shown_text(), "Done")
	assert_false(_screen.pass_button().disabled, "Done can always be pressed.")


func test_surveilling_one_card_says_so() -> void:
	_open_surveilling(1)

	assert_eq(_screen.surveil_window().title_text(), "Surveil 1")
	assert_eq(_screen.info_panel().prompt_text(), "Surveil: graveyard any of these.")


func test_it_is_placed_left_of_the_piles_over_the_heros_side_three_cards_wide() -> void:
	_open_surveilling(1)

	var window: SurveilWindow = _screen.surveil_window()
	var regions: Dictionary = EncounterLayout.regions(SCREEN)
	assert_lt(window.position.x + window.size.x, (regions["piles"] as Rect2).position.x, "Left of the piles.")
	assert_gt(window.position.y, (regions["battlefield"] as Rect2).get_center().y, "Over the Hero's side.")
	assert_almost_eq(window.size, SurveilWindow.opening_size(), Vector2(0.01, 0.01))
	var button: Rect2 = window.graveyard_button().get_global_rect()
	assert_gt(button.position.x, window.get_global_rect().position.x, "The button is not cut off on the left.")
	assert_lt(button.end.y, window.get_global_rect().end.y, "The window ends just under it.")


func test_graveyard_is_baked_into_the_bottom_edge_and_stays_centered_however_the_window_is_resized() -> void:
	# Game ADR 0085: the Surveil window takes the Look window's structure.
	_open_surveilling(2)
	var window: SurveilWindow = _screen.surveil_window()

	var strip: Control = window.edge_strip()
	assert_not_null(strip)
	assert_eq(window.graveyard_button().get_parent(), strip, "In the strip along the bottom edge.")
	assert_eq(strip.size.y, SurveilWindow.GRAVEYARD_BUTTON.y, "As tall as the button.")
	var button: Rect2 = window.graveyard_button().get_global_rect()
	assert_almost_eq(button.get_center().x, window.get_global_rect().get_center().x, 0.5)
	assert_almost_eq(button.end.y, window.get_global_rect().end.y - 2.0, 0.5)
	window.resize_by(Vector2(-60, 40))
	button = window.graveyard_button().get_global_rect()
	assert_almost_eq(button.get_center().x, window.get_global_rect().get_center().x, 0.5, "Still centered.")
	assert_almost_eq(button.end.y, window.get_global_rect().end.y - 2.0, 0.5, "Still on the bottom edge.")
	window.card_clicked.emit(_surveil().card_ids[0])
	window.graveyard_button().pressed.emit()
	button = window.graveyard_button().get_global_rect()
	assert_almost_eq(button.get_center().x, window.get_global_rect().get_center().x, 0.5, "However many cards are left.")


func test_a_click_selects_a_card_and_a_second_lets_it_go() -> void:
	_open_surveilling(2)
	var first: int = _surveil().card_ids[0]
	var second: int = _surveil().card_ids[1]

	_screen.surveil_window().card_clicked.emit(first)

	var window: SurveilWindow = _screen.surveil_window()
	assert_eq(BorderEffects.glow_colors(window.face_of(first)), [Color.WHITE] as Array[Color], "Selected glows white.")
	assert_eq(BorderEffects.glow_colors(window.face_of(second)), [GREEN] as Array[Color])
	assert_false(window.graveyard_button().disabled)
	assert_true(_presenter.snapshot().decision is SurveilDecision, "A click answers nothing.")

	window.card_clicked.emit(first)

	assert_eq(BorderEffects.glow_colors(window.face_of(first)), [GREEN] as Array[Color])
	assert_true(window.graveyard_button().disabled)


func test_graveyard_sends_the_selected_card_to_the_graveyard_pile_and_answers_nothing() -> void:
	_open_surveilling(2)
	var first: int = _surveil().card_ids[0]
	var second: int = _surveil().card_ids[1]
	var library: int = _presenter.snapshot().view.library_sizes[HERO]
	var graveyard: int = _presenter.snapshot().view.graveyards[HERO].size()
	_screen.surveil_window().card_clicked.emit(first)

	_screen.surveil_window().graveyard_button().pressed.emit()

	var window: SurveilWindow = _screen.surveil_window()
	assert_eq(window.entries(), [second] as Array[int])
	assert_true(window.graveyard_button().disabled, "Nothing is selected now.")
	assert_true(_presenter.snapshot().decision is SurveilDecision, "Nothing answered until Done.")
	assert_eq(_screen.pile_text("hero_graveyard"), "Graveyard (%d)" % (graveyard + 1))
	assert_eq(_screen.pile_text("hero_library"), "Library (%d)" % (library - 1))


func test_done_gives_the_cards_sent_then_the_row() -> void:
	_open_surveilling(3)
	var cards: Array[int] = _surveil().card_ids
	var card_ids: Array[int] = []
	for id: int in cards:
		card_ids.append(_card_id_of(id))
	var window: SurveilWindow = _screen.surveil_window()
	window.card_clicked.emit(cards[1])
	window.graveyard_button().pressed.emit()
	window.moved.emit(1, 0)

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is SurveilDecision)
	var library: Array = _presenter.snapshot().view.libraries[HERO]
	assert_eq((library[0] as MmObjectView).card_id, card_ids[2], "Moved to the top.")
	assert_eq((library[1] as MmObjectView).card_id, card_ids[0])
	assert_eq((_presenter.snapshot().view.graveyards[HERO].back() as MmObjectView).card_id, card_ids[1])
	assert_false(_screen.surveil_window().is_open(), "Closed once answered.")


func test_done_at_once_keeps_every_card_where_it_was() -> void:
	_open_surveilling(2)
	var cards: Array[int] = _surveil().card_ids

	_screen.pass_priority()
	_presenter.wait_until_idle()

	var library: Array = _presenter.snapshot().view.libraries[HERO]
	assert_eq((library[0] as MmObjectView).id, cards[0], "Kept, and still the same objects.")
	assert_eq((library[1] as MmObjectView).id, cards[1])


func test_undo_takes_back_the_last_sending_then_the_last_move() -> void:
	_open_surveilling(2)
	var cards: Array[int] = _surveil().card_ids
	var graveyard: int = _presenter.snapshot().view.graveyards[HERO].size()
	var window: SurveilWindow = _screen.surveil_window()
	assert_true(_screen.undo_button().disabled, "Nothing to take back yet.")
	window.moved.emit(0, 1)
	window.card_clicked.emit(cards[0])
	window.graveyard_button().pressed.emit()
	assert_false(_screen.undo_button().disabled)

	_screen.undo()

	assert_eq(window.entries(), [cards[1], cards[0]] as Array[int], "The card is back in its place.")
	assert_eq(_screen.pile_text("hero_graveyard"), "Graveyard (%d)" % graveyard)
	_screen.undo()
	assert_eq(window.entries(), cards)
	assert_true(_screen.undo_button().disabled)
	assert_true(_presenter.snapshot().decision is SurveilDecision)


func test_a_card_sent_flies_from_the_window_to_the_graveyard_pile_and_counts_once_it_lands() -> void:
	_open_surveilling(2, FLIGHT)
	var first: int = _surveil().card_ids[0]
	var graveyard: int = _presenter.snapshot().view.graveyards[HERO].size()
	var window: SurveilWindow = _screen.surveil_window()
	window.card_clicked.emit(first)
	var from: Vector2 = window.face_of(first).get_global_rect().get_center() - _screen.global_position

	window.graveyard_button().pressed.emit()

	var card: FlightCard = _screen.flight_card_of(first)
	assert_not_null(card, "It flies.")
	assert_almost_eq(card.position, from, Vector2(1, 1), "From where it was in the window.")
	assert_eq(_screen.pile_text("hero_graveyard"), "Graveyard (%d)" % graveyard, "Not yet landed.")
	_advance(FLIGHT * 1.5)
	assert_null(_screen.flight_card_of(first))
	assert_eq(_screen.pile_text("hero_graveyard"), "Graveyard (%d)" % (graveyard + 1))

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_eq(_screen.flight_layer().flying_ids(), [] as Array[int], "It does not fly a second time.")


func test_the_graveyard_window_shows_the_cards_sent() -> void:
	_open_surveilling(2)
	var first: int = _surveil().card_ids[0]
	_screen.surveil_window().card_clicked.emit(first)
	_screen.surveil_window().graveyard_button().pressed.emit()

	_screen.pile_catcher("hero_graveyard").clicked.emit()

	assert_true(_screen.pile_window("hero_graveyard").entries().has(first))


func test_a_card_in_the_window_can_be_pinned() -> void:
	_open_surveilling(1)
	var first: int = _surveil().card_ids[0]
	var face: Control = _screen.surveil_window().face_of(first)

	assert_eq(_screen.inspectable_at(face.get_global_rect().get_center() - _screen.global_position), first)


func test_the_window_keeps_its_place_and_size_through_a_click() -> void:
	_open_surveilling(2)
	var window: SurveilWindow = _screen.surveil_window()
	window.drag_by(Vector2(-40, -30))
	var rect: Rect2 = Rect2(window.position, window.size)

	window.card_clicked.emit(_surveil().card_ids[0])
	window.graveyard_button().pressed.emit()

	assert_eq(Rect2(window.position, window.size), rect)


func test_a_real_drag_reorders_the_row_and_a_real_click_selects() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	add_child_autofree(viewport)
	_open_surveilling(2, 0.0, viewport)
	var cards: Array[int] = _surveil().card_ids
	var window: SurveilWindow = _screen.surveil_window()
	var first: Vector2 = window.face_of(cards[0]).get_global_rect().get_center()
	var second: Vector2 = window.face_of(cards[1]).get_global_rect().get_center()

	viewport.push_input(_button(true, first))
	viewport.push_input(_motion(first + Vector2(20, 0)))
	viewport.push_input(_motion(second + Vector2(20, 0)))
	viewport.push_input(_button(false, second + Vector2(20, 0)))

	assert_eq(window.entries(), [cards[1], cards[0]] as Array[int], "Dragged past the second card.")
	assert_eq(_surveil().card_ids, cards, "A drag answers nothing.")
	await wait_process_frames(30)
	viewport.push_input(_button(true, window.slot_center(0)))
	viewport.push_input(_button(false, window.slot_center(0)))
	assert_eq(BorderEffects.glow_colors(window.face_of(cards[1])), [Color.WHITE] as Array[Color], "Clicked where it rests.")


func _surveil() -> SurveilDecision:
	return _presenter.snapshot().decision as SurveilDecision


func _card_id_of(object_id: int) -> int:
	for seen: Variant in _presenter.snapshot().view.libraries[HERO]:
		if seen != null and (seen as MmObjectView).id == object_id:
			return (seen as MmObjectView).card_id
	return -1


func _advance(seconds: float) -> void:
	var frames: int = ceili(seconds / 0.01)
	for frame: int in frames:
		_screen.advance_motion(seconds / frames)
	_screen.advance_motion(0.000001)


func _button(is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click


func _motion(at: Vector2) -> InputEventMouseMotion:
	var moved: InputEventMouseMotion = InputEventMouseMotion.new()
	moved.position = at
	moved.global_position = at
	moved.button_mask = MOUSE_BUTTON_MASK_LEFT
	return moved


## Opens the screen in the Hero's first main phase holding a Thespian that surveils
## [param amount], casts it, and lets its trigger resolve to its surveil. Cards fly for
## [param flight_seconds].
func _open_surveilling(amount: int, flight_seconds: float = 0.0, parent: Node = null) -> void:
	var deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.thespian("Thespian", amount), Scenario.basic_land("Forest"),
		Scenario.creature("Bear", 2, 2), Scenario.basic_land("Forest")])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		if Scenario.names(engine, engine.hero().hand).has("Thespian"):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	if parent == null:
		add_child_autofree(_screen)
	else:
		parent.add_child(_screen)
	_screen.set_process(false)
	_screen.size = SCREEN
	_screen.flight_layer().seconds = flight_seconds
	_presenter = EncounterPresenter.new(chosen, DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	for attempt: int in 10:
		if _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN:
			break
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == "Thespian":
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			break
	for attempt: int in 10:
		if _presenter.snapshot().decision is SurveilDecision:
			_advance(FLIGHT * 2.0)
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("Thespian's surveil was never asked.")
