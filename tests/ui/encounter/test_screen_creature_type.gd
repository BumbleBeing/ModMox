extends GutTest
## Choosing a creature type on the Encounter Screen (game ADR 0053): the Creature Type
## Window opens with the keyboard in its search box as the Hero's Rally resolves, a redraw
## keeps what is typed, pointing marks the Hero's creatures of the type, Enter and a click
## answer, Escape is still the screen's, and the chosen type shows on the face and in the
## State Information.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SCREEN: Vector2 = Vector2(1920, 1080)
const TARGET: Color = Color("#ff5a2a")

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	await wait_process_frames(2)


func test_the_window_opens_as_the_heros_rally_resolves_with_the_heros_types_first() -> void:
	_reach_choice()
	await wait_process_frames(2)

	var window: CreatureTypeWindow = _screen.creature_type_window()
	assert_true(window.is_open())
	assert_eq(window.title_text(), "Rally the Ranks: choose a creature type")
	assert_true(window.filter_box().has_focus(), "The keyboard is in the search box as it opens.")
	assert_eq(window.shown_types().slice(0, 2), ["Cat", "Elf"])
	assert_eq(_screen.info_panel().prompt_text(), "Choose a creature type for Rally the Ranks")
	assert_true(window.bounds.encloses(Rect2(window.position, window.size)))


func test_typing_then_enter_chooses_the_top_match_and_the_face_shows_it() -> void:
	_reach_choice()
	var window: CreatureTypeWindow = _screen.creature_type_window()

	window.type_text("ca")
	window.filter_box().text_submitted.emit(window.query())
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseCreatureTypeDecision)
	assert_false(window.is_open())
	assert_false(window.filter_box().has_focus(), "The keyboard is the screen's again.")
	var rally: int = _permanent("Rally the Ranks")
	assert_eq(_view_of(rally).chosen_creature_type, "Cat")
	var face: BattlefieldFace = _screen.face_of(rally) as BattlefieldFace
	assert_eq(face.chosen_type_chip().shown_text, "Cat")
	var state: Array = _presenter.snapshot().state_information.get(rally, [])
	assert_eq((state[0] as StateEntry).title, "Chosen type: Cat")
	assert_eq(_view_of(_permanent("Lion")).power, 3, "The Lion is a Cat.")


func test_a_click_on_a_row_chooses_its_type() -> void:
	_reach_choice()

	_screen.creature_type_window().catcher_of("Elf").clicked.emit()
	_presenter.wait_until_idle()

	assert_eq(_view_of(_permanent("Rally the Ranks")).chosen_creature_type, "Elf")


func test_a_redraw_keeps_what_is_typed_and_rebuilds_no_row() -> void:
	_reach_choice()
	var window: CreatureTypeWindow = _screen.creature_type_window()
	window.type_text("wa")
	var row: PanelContainer = window.row_of("Warrior")

	_presenter.changed.emit(_presenter.snapshot())

	assert_eq(window.query(), "wa")
	assert_same(window.row_of("Warrior"), row)
	assert_true(window.is_open())


func test_pointing_at_a_type_marks_the_heros_creatures_of_it_and_the_info_panel_only_asks() -> void:
	_reach_choice()
	var window: CreatureTypeWindow = _screen.creature_type_window()
	var lion: Control = _screen.face_of(_permanent("Lion"))
	var elf: Control = _screen.face_of(_permanent("Elf"))

	window.catcher_of("Cat").mouse_entered.emit()

	assert_not_null(BorderEffects.mark_color(lion), "Marked in the target color.")
	assert_null(BorderEffects.mark_color(elf))
	assert_eq(_screen.info_panel().option_text(), "", "It never says what the type would do.")
	window.catcher_of("Cat").mouse_exited.emit()
	await wait_process_frames(2)
	assert_null(BorderEffects.mark_color(lion))


func test_up_and_down_light_the_next_type_and_the_board_follows() -> void:
	_reach_choice()
	var window: CreatureTypeWindow = _screen.creature_type_window()
	window.type_text("e")

	window.step_light(1)

	assert_eq(window.lit(), window.shown_types()[1])
	window.step_light(-1)
	assert_eq(window.lit(), "Elf")
	assert_not_null(BorderEffects.mark_color(_screen.face_of(_permanent("Elf"))))
	assert_eq(_screen.info_panel().option_text(), "")


func test_the_window_is_closed_while_the_hero_is_not_asked_for_a_type() -> void:
	_open()

	assert_false(_screen.creature_type_window().is_open())


func test_a_real_click_on_a_row_answers() -> void:
	var viewport: SubViewport = _viewport()
	_reach_choice(viewport)
	await wait_process_frames(3)
	var at: Vector2 = _screen.creature_type_window().row_of("Elf").get_global_rect().get_center()

	viewport.push_input(_motion(at))
	viewport.push_input(_button(true, at))
	viewport.push_input(_button(false, at))
	_presenter.wait_until_idle()

	assert_eq(_view_of(_permanent("Rally the Ranks")).chosen_creature_type, "Elf")
	viewport.push_input(_motion(Vector2(10, 10)))
	await wait_process_frames(3)


func test_real_keys_type_into_the_box_move_the_light_and_enter_answers() -> void:
	var viewport: SubViewport = _viewport()
	_reach_choice(viewport)
	await wait_process_frames(3)
	var window: CreatureTypeWindow = _screen.creature_type_window()

	for letter: Key in [KEY_C, KEY_A]:
		viewport.push_input(_key(letter, char(letter).to_lower()))
	assert_eq(window.query(), "ca", "Letters go to the box, not to the Key Bindings.")
	viewport.push_input(_key(KEY_DOWN))
	assert_eq(window.lit(), "Caitian")
	viewport.push_input(_key(KEY_ENTER))
	_presenter.wait_until_idle()

	assert_eq(_view_of(_permanent("Rally the Ranks")).chosen_creature_type, "Caitian")


func test_space_in_the_box_types_a_space_and_passes_nothing() -> void:
	var viewport: SubViewport = _viewport()
	_reach_choice(viewport)
	await wait_process_frames(3)

	viewport.push_input(_key(KEY_SPACE, " "))

	assert_eq(_screen.creature_type_window().query(), " ")
	assert_true(_presenter.snapshot().decision is ChooseCreatureTypeDecision)


func test_a_real_escape_in_the_box_still_opens_the_pause_menu() -> void:
	var viewport: SubViewport = _viewport()
	_reach_choice(viewport)
	await wait_process_frames(3)
	assert_true(_screen.creature_type_window().filter_box().has_focus())

	viewport.push_input(_key(KEY_ESCAPE))

	assert_true(_screen.is_paused(), "Escape opens the Pause Menu as everywhere else.")


# --- Helpers ----------------------------------------------------------------------------


## The Hero controls a Lion (a Cat) and an Elf, and has just cast Rally the Ranks, whose
## type is asked.
func _reach_choice(parent: Node = null) -> void:
	_open(parent)
	_cast("Lion")
	_cast("Elf")
	_cast("Rally the Ranks")
	_presenter.wait_until_idle()
	assert_true(_presenter.snapshot().decision is ChooseCreatureTypeDecision, "The type is asked.")


## A screen where the Hero's deck cycles through a Lion, an Elf and Rally the Ranks, the
## Villain does nothing, and the Hero has kept and reached their first main phase.
func _open(parent: Node = null) -> void:
	var cards: Array[MmCardDefinition] = [Scenario.typed_creature("Lion", 2, 2, ["Cat"]),
		Scenario.typed_creature("Elf", 1, 1, ["Elf"]), Scenario.rally("Rally the Ranks")]
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	if parent == null:
		add_child_autofree(_screen)
	else:
		parent.add_child(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40)), DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	for attempt: int in 200:
		if _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN and _presenter.snapshot().decision is PriorityDecision:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


func _viewport() -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	add_child_autofree(viewport)
	return viewport


func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	assert_not_null(priority, "The Hero does not have priority.")
	if priority == null:
		return
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if action is CastSpellAction and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("Cannot cast %s." % card_name)


func _permanent(card_name: String) -> int:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			return permanent.id
	return -1


func _view_of(object_id: int) -> MmObjectView:
	for seen: MmObjectView in _presenter.snapshot().visible_objects():
		if seen.id == object_id:
			return seen
	return null


func _key(keycode: Key, text: String = "") -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	if text != "":
		key.unicode = text.unicode_at(0)
	return key


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
