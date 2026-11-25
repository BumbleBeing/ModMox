extends GutTest
## Looking at the top cards of the library on the Encounter Screen (game ADR 0085), as
## Militia Bugler does. As the look resolves, the Look window opens by itself, titled "Look
## at N", with the cards face up in a row, top first, and "Hand" baked into its bottom edge.
## The cards that may be taken glow green; a click selects one, which glows white, and a
## second lets it go; "Hand" flies the selected card into the hand, and then no other may be
## taken. Only the pass button, "Done", answers: the cards taken. The rest fly face down
## onto the Library pile. Undo takes back the card taken. Bugler is a 2/3 costing {0} with
## Militia Bugler's ability (Scenario.bugler()).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const GREEN: Color = Color("#7be36a")
const FLIGHT: float = 0.4

var _presenter: EncounterPresenter
var _screen: EncounterScreen
## The Card Identity of each card in the Hero's library as the look was asked, by object ID.
var _known_card_ids: Dictionary[int, int] = {}


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_look_opens_the_look_window_by_itself_with_the_cards_in_library_order() -> void:
	_open_looking()

	var window: LookWindow = _screen.look_window()
	var asked: ChooseLookedAtCardsDecision = _look()
	assert_true(window.is_open(), "Opened by the look itself.")
	assert_eq(window.title_text(), "Look at 4")
	assert_null(window.close_button(), "It has no close button.")
	assert_eq(window.entries(), asked.card_ids, "Top first.")
	for object_id: int in asked.card_ids:
		var glow: Array[Color] = []
		if asked.candidate_ids.has(object_id):
			glow.append(GREEN)
		assert_eq(BorderEffects.glow_colors(window.face_of(object_id)), glow, "Only a card that may be taken glows.")
	assert_true(window.hand_button().disabled, "Nothing is selected.")
	assert_eq(window.hand_button().text, "Hand")
	assert_eq(_screen.info_panel().prompt_text(),
		"Bugler: you may put a creature card with power 2 or less into your hand. The rest go to the bottom.")
	assert_eq(_screen.pass_button().shown_text(), "Done")
	assert_false(_screen.pass_button().disabled, "Done can always be pressed.")


func test_it_is_placed_left_of_the_piles_over_the_heros_side_four_cards_wide() -> void:
	_open_looking()

	var window: LookWindow = _screen.look_window()
	var regions: Dictionary = EncounterLayout.regions(SCREEN)
	assert_lt(window.position.x + window.size.x, (regions["piles"] as Rect2).position.x, "Left of the piles.")
	assert_gt(window.position.y, (regions["battlefield"] as Rect2).get_center().y, "Over the Hero's side.")
	assert_almost_eq(window.size, LookWindow.opening_size(), Vector2(0.01, 0.01))


func test_hand_is_baked_into_the_bottom_edge_and_stays_centered_however_the_window_is_resized() -> void:
	_open_looking()
	var window: LookWindow = _screen.look_window()

	assert_eq(window.hand_button().get_parent(), window.edge_strip(), "In the strip along the bottom edge.")
	assert_eq(window.edge_strip().size.y, LookWindow.HAND_BUTTON.y, "As tall as the button.")
	window.resize_by(Vector2(80, 40))
	var button: Rect2 = window.hand_button().get_global_rect()
	assert_almost_eq(button.get_center().x, window.get_global_rect().get_center().x, 0.5, "Centered.")
	assert_almost_eq(button.end.y, window.get_global_rect().end.y - 2.0, 0.5, "On the bottom edge.")


func test_a_click_selects_a_card_that_may_be_taken_and_a_second_lets_it_go() -> void:
	_open_looking()
	var asked: ChooseLookedAtCardsDecision = _look()
	var taken: int = asked.candidate_ids[0]
	var other: int = _not_a_candidate()
	var window: LookWindow = _screen.look_window()

	window.card_clicked.emit(other)
	assert_eq(BorderEffects.glow_colors(window.face_of(other)), [] as Array[Color], "It may not be taken.")
	assert_true(window.hand_button().disabled)
	window.card_clicked.emit(taken)

	assert_eq(BorderEffects.glow_colors(window.face_of(taken)), [Color.WHITE] as Array[Color], "Selected glows white.")
	assert_false(window.hand_button().disabled)
	assert_true(_presenter.snapshot().decision is ChooseLookedAtCardsDecision, "A click answers nothing.")
	window.card_clicked.emit(taken)
	assert_eq(BorderEffects.glow_colors(window.face_of(taken)), [GREEN] as Array[Color])
	assert_true(window.hand_button().disabled)


func test_hand_puts_the_selected_card_into_the_hand_and_answers_nothing() -> void:
	_open_looking()
	var asked: ChooseLookedAtCardsDecision = _look()
	var taken: int = asked.candidate_ids[0]
	var card_id: int = _card_id_of(taken)
	var library: int = _presenter.snapshot().view.library_sizes[HERO]
	var window: LookWindow = _screen.look_window()
	window.card_clicked.emit(taken)

	window.hand_button().pressed.emit()

	assert_false(window.entries().has(taken))
	assert_eq(window.entries().size(), 3)
	assert_true(window.hand_button().disabled, "Nothing is selected now.")
	for object_id: int in window.entries():
		assert_eq(BorderEffects.glow_colors(window.face_of(object_id)), [] as Array[Color], "No other may be taken.")
	assert_true(_presenter.snapshot().decision is ChooseLookedAtCardsDecision, "Nothing answered until Done.")
	assert_eq(_screen.pile_text("hero_library"), "Library (%d)" % (library - 1))
	assert_not_null(_screen.hand_strip().face_of(card_id), "The hand shows it.")


func test_done_gives_the_card_taken_and_the_rest_go_to_the_bottom() -> void:
	_open_looking()
	var asked: ChooseLookedAtCardsDecision = _look()
	var taken: int = asked.candidate_ids[0]
	var card_id: int = _card_id_of(taken)
	var library: int = _presenter.snapshot().view.library_sizes[HERO]
	_screen.look_window().card_clicked.emit(taken)
	_screen.look_window().hand_button().pressed.emit()

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseLookedAtCardsDecision)
	var in_hand: Array[int] = []
	for seen: MmObjectView in _presenter.snapshot().view.hand:
		in_hand.append(seen.card_id)
	assert_true(in_hand.has(card_id))
	assert_not_null(_screen.hand_strip().face_of(card_id))
	assert_eq(_presenter.snapshot().view.library_sizes[HERO], library - 1, "The rest are back in the library.")
	assert_eq(_screen.pile_text("hero_library"), "Library (%d)" % (library - 1))
	assert_false(_screen.look_window().is_open(), "Closed once answered.")


func test_done_at_once_takes_nothing() -> void:
	_open_looking()
	var library: int = _presenter.snapshot().view.library_sizes[HERO]
	var hand: int = _presenter.snapshot().view.hand.size()

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseLookedAtCardsDecision)
	assert_eq(_presenter.snapshot().view.library_sizes[HERO], library, "All four are back in the library.")
	assert_eq(_presenter.snapshot().view.hand.size(), hand)


func test_undo_takes_back_the_card_taken() -> void:
	_open_looking()
	var asked: ChooseLookedAtCardsDecision = _look()
	var taken: int = asked.candidate_ids[0]
	var library: int = _presenter.snapshot().view.library_sizes[HERO]
	var window: LookWindow = _screen.look_window()
	window.card_clicked.emit(taken)
	window.hand_button().pressed.emit()
	assert_false(_screen.undo_button().disabled)

	_screen.undo()

	assert_eq(window.entries(), asked.card_ids, "Back in its place.")
	assert_eq(_screen.pile_text("hero_library"), "Library (%d)" % library)
	assert_null(_screen.hand_strip().face_of(_card_id_of(taken)), "Out of the hand.")
	assert_eq(BorderEffects.glow_colors(window.face_of(taken)), [GREEN] as Array[Color], "It may be taken again.")
	assert_true(_presenter.snapshot().decision is ChooseLookedAtCardsDecision)


func test_a_card_taken_flies_from_the_window_into_the_hand_and_never_flies_a_second_time() -> void:
	_open_looking(FLIGHT)
	var taken: int = _look().candidate_ids[0]
	var window: LookWindow = _screen.look_window()
	window.card_clicked.emit(taken)
	var from: Vector2 = window.face_of(taken).get_global_rect().get_center() - _screen.global_position

	window.hand_button().pressed.emit()

	var card: FlightCard = _screen.flight_card_of(taken)
	assert_not_null(card, "It flies.")
	assert_almost_eq(card.position, from, Vector2(1, 1), "From where it was in the window.")
	_advance(FLIGHT * 1.5)
	assert_null(_screen.flight_card_of(taken))
	assert_not_null(_screen.hand_strip().face_of(_card_id_of(taken)), "In the hand once it lands.")

	_screen.pass_priority()
	_presenter.wait_until_idle()
	_screen.advance_motion(0.01)

	assert_false(_flying_to_hand(), "It does not fly a second time.")


func test_at_done_the_rest_fly_face_down_onto_the_library_pile() -> void:
	_open_looking(FLIGHT)
	var rest: Array[int] = _look().card_ids

	_screen.pass_priority()

	for object_id: int in rest:
		var card: FlightCard = _screen.flight_card_of(object_id)
		assert_not_null(card, "It flies.")
		if card != null:
			assert_eq(card.landing_kind, FlightCard.Kind.BACK, "Face down onto the pile.")
	_presenter.wait_until_idle()
	_advance(FLIGHT * 1.5)
	assert_eq(_screen.flight_layer().flying_ids(), [] as Array[int])


func test_a_card_in_the_window_can_be_pinned() -> void:
	_open_looking()
	var first: int = _look().card_ids[0]
	var face: Control = _screen.look_window().face_of(first)

	assert_eq(_screen.inspectable_at(face.get_global_rect().get_center() - _screen.global_position), first)


func test_a_real_click_selects() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	add_child_autofree(viewport)
	_open_looking(0.0, viewport)
	var taken: int = _look().candidate_ids[0]
	var window: LookWindow = _screen.look_window()
	var at: Vector2 = window.face_of(taken).get_global_rect().get_center()

	viewport.push_input(_button(true, at))
	viewport.push_input(_button(false, at))

	assert_eq(BorderEffects.glow_colors(window.face_of(taken)), [Color.WHITE] as Array[Color])


# --- Helpers ---------------------------------------------------------------------------


func _look() -> ChooseLookedAtCardsDecision:
	return _presenter.snapshot().decision as ChooseLookedAtCardsDecision


func _not_a_candidate() -> int:
	for object_id: int in _look().card_ids:
		if not _look().candidate_ids.has(object_id):
			return object_id
	return -1


func _card_id_of(object_id: int) -> int:
	for seen: Variant in _presenter.snapshot().view.libraries[HERO]:
		if seen != null and (seen as MmObjectView).id == object_id:
			return (seen as MmObjectView).card_id
	return _known_card_ids.get(object_id, -1)


func _flying_to_hand() -> bool:
	for object_id: int in _screen.flight_layer().flying_ids():
		var card: FlightCard = _screen.flight_card_of(object_id)
		if card != null and card.landing_kind == FlightCard.Kind.CARD:
			return true
	return false


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


## Opens the screen in the Hero's first main phase holding a Bugler, with at least one card
## that may be taken among the top four of their library once it is cast, casts it, and
## lets its trigger resolve to its look. Cards fly for [param flight_seconds].
func _open_looking(flight_seconds: float = 0.0, parent: Node = null) -> void:
	var deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.bugler(), Scenario.basic_land("Plains"),
		Scenario.creature("Pup", 1, 1), Scenario.creature("Ogre", 3, 3)])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		if not Scenario.names(engine, engine.hero().hand).has("Bugler"):
			continue
		var top: Array[String] = []
		for card: MmGameObject in engine.hero().library.objects().slice(0, 4):
			top.append(engine.game_state().characteristics_of(card).name)
		if top.has("Ogre") and (top.has("Pup") or top.has("Bugler")):
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
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == "Bugler":
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			break
	for attempt: int in 10:
		if _presenter.snapshot().decision is ChooseLookedAtCardsDecision:
			_advance(FLIGHT * 2.0)
			break
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	assert_true(_presenter.snapshot().decision is ChooseLookedAtCardsDecision, "The look is asked.")
	for seen: Variant in _presenter.snapshot().view.libraries[HERO]:
		if seen != null:
			_known_card_ids[(seen as MmObjectView).id] = (seen as MmObjectView).card_id
