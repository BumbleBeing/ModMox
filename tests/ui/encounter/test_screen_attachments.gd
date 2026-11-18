extends GutTest
## An attachment on the Encounter Screen (game ADR 0042): an Equipment attached to a
## creature lies sideways behind it with only its name strip out past the creature's right
## edge, the creature takes that much more room in its line, and the strip is what is
## clicked and pinned.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_an_equipment_attached_to_nothing_stands_among_the_other_permanents() -> void:
	_open_with_a_bear_and_a_sword()

	var sword: BattlefieldFace = _screen.face_of(_permanent("Sword")) as BattlefieldFace

	assert_false(sword.is_attached())
	assert_eq(sword.card().rotation_degrees, 0.0)
	assert_not_null(_screen.line("hero_others"))
	assert_eq(sword.get_parent(), _screen.line("hero_others").content())


func test_an_attached_equipment_lies_sideways_behind_its_creature_with_its_name_strip_past_the_right_edge() -> void:
	_open_with_a_bear_and_a_sword()

	_equip(_permanent("Sword"), _permanent("Bear"))

	var sword: BattlefieldFace = _screen.face_of(_permanent("Sword")) as BattlefieldFace
	var bear: BattlefieldFace = _screen.face_of(_permanent("Bear")) as BattlefieldFace
	var strip: float = BattlefieldFace.attached_strip(sword.card().size.y)
	assert_true(sword.is_attached())
	assert_not_null(sword.attached_mark())
	assert_eq(sword.get_parent(), bear.get_parent(), "It has left the other permanents for its creature's line.")
	assert_null(_screen.line("hero_others"), "Nothing is left there.")
	assert_lt(sword.get_index(), bear.get_index(), "It is drawn first, so the creature is drawn over it.")
	assert_almost_eq(sword.get_global_rect().end.x, bear.get_global_rect().end.x + strip, 0.01)
	assert_almost_eq(sword.get_global_rect().get_center().y, bear.get_global_rect().get_center().y, 0.51)
	assert_almost_eq(sword.card().size.y / bear.card().size.y, EncounterLayout.OTHERS_SCALE, 0.01, "As big as it was on its own.")


func test_the_next_creature_stands_the_usual_gap_past_an_equipped_creatures_name_strip() -> void:
	_open(_setup_of([_bear(), Scenario.sword("Sword")]))
	_cast("Bear")
	_cast("Bear")
	_cast("Sword")
	var bears: Array[int] = _permanents("Bear")
	var gap_before: float = _screen.face_of(bears[1]).get_global_rect().position.x - _screen.face_of(bears[0]).get_global_rect().end.x

	_equip(_permanent("Sword"), bears[0])

	var sword: BattlefieldFace = _screen.face_of(_permanent("Sword")) as BattlefieldFace
	var strip: float = BattlefieldFace.attached_strip(sword.card().size.y)
	var gap_after: float = _screen.face_of(bears[1]).get_global_rect().position.x - _screen.face_of(bears[0]).get_global_rect().end.x
	assert_almost_eq(gap_before, EncounterLayout.ROW_GAP, 0.01)
	assert_almost_eq(gap_after, strip + EncounterLayout.ROW_GAP, 0.01, "The creature is that much wider to its neighbors.")
	assert_almost_eq(_screen.line("hero_creatures").content_width(),
		EncounterLayout.LINE_PAD * 2.0 + _screen.face_of(bears[0]).size.x * 2.0 + strip + EncounterLayout.ROW_GAP, 0.01,
		"The line counts the strip, so it scrolls sooner and nothing shrinks.")


func test_a_second_equipment_shows_past_the_first() -> void:
	_open(_setup_of([_bear(), Scenario.sword("Sword"), Scenario.sword("Axe", 2)]))
	_cast("Bear")
	_cast("Sword")
	_cast("Axe")
	var first: int = mini(_permanent("Sword"), _permanent("Axe"))
	var second: int = maxi(_permanent("Sword"), _permanent("Axe"))

	_equip(_permanent("Axe"), _permanent("Bear"))
	_equip(_permanent("Sword"), _permanent("Bear"))

	var bear: Rect2 = _screen.face_of(_permanent("Bear")).get_global_rect()
	var strip: float = BattlefieldFace.attached_strip((_screen.face_of(first) as BattlefieldFace).card().size.y)
	assert_almost_eq(_screen.face_of(first).get_global_rect().end.x, bear.end.x + strip, 0.01, "The lower ID lies nearest.")
	assert_almost_eq(_screen.face_of(second).get_global_rect().end.x, bear.end.x + strip * 2.0, 0.01)
	assert_lt(_screen.face_of(second).get_index(), _screen.face_of(first).get_index(), "The outer one is drawn under the inner.")


func test_only_the_name_strip_of_an_attached_equipment_is_clicked() -> void:
	_open_with_a_bear_and_a_sword()
	_equip(_permanent("Sword"), _permanent("Bear"))
	var sword: BattlefieldFace = _screen.face_of(_permanent("Sword")) as BattlefieldFace
	var strip: float = BattlefieldFace.attached_strip(sword.card().size.y)

	var catcher: ClickCatcher = _screen.click_catcher(_permanent("Sword"))

	assert_not_null(catcher, "Equip can be activated again.")
	assert_almost_eq(catcher.get_global_rect().size.x, strip, 0.01)
	assert_almost_eq(catcher.get_global_rect().end.x, sword.get_global_rect().end.x, 0.01)
	catcher.clicked.emit()
	_presenter.wait_until_idle()
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision, "Clicking the strip activates equip.")


func test_a_real_click_on_the_creature_does_not_reach_the_equipment_behind_it_and_one_on_the_strip_does() -> void:
	var window: SubViewport = SubViewport.new()
	window.size = Vector2i(SCREEN)
	add_child_autofree(window)
	_open(_setup_of([_bear(), Scenario.sword("Sword")]), window)
	_cast("Bear")
	_cast("Sword")
	_equip(_permanent("Sword"), _permanent("Bear"))
	await wait_process_frames(2)
	var bear: Rect2 = _screen.face_of(_permanent("Bear")).get_global_rect()
	var sword: Rect2 = _screen.face_of(_permanent("Sword")).get_global_rect()
	assert_null(_screen.click_catcher(_permanent("Bear")), "The Bear offers nothing in the main phase.")

	window.push_input(_button(MOUSE_BUTTON_LEFT, true, bear.get_center()))
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, bear.get_center()))
	_presenter.wait_until_idle()
	assert_true(_presenter.snapshot().decision is PriorityDecision, "The Equipment under the creature took nothing.")

	var on_strip: Vector2 = Vector2((bear.end.x + sword.end.x) / 2.0, sword.get_center().y)
	window.push_input(_button(MOUSE_BUTTON_LEFT, true, on_strip))
	window.push_input(_button(MOUSE_BUTTON_LEFT, false, on_strip))
	_presenter.wait_until_idle()
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision)


func test_a_right_click_pins_the_equipment_on_its_strip_and_the_creature_everywhere_else() -> void:
	_open_with_a_bear_and_a_sword()
	_equip(_permanent("Sword"), _permanent("Bear"))
	var bear: Rect2 = _screen.face_of(_permanent("Bear")).get_global_rect()
	var sword: Rect2 = _screen.face_of(_permanent("Sword")).get_global_rect()
	var on_strip: Vector2 = Vector2((bear.end.x + sword.end.x) / 2.0, sword.get_center().y) - _screen.global_position
	var on_bear: Vector2 = Vector2(bear.end.x - 6.0, bear.get_center().y) - _screen.global_position

	assert_eq(_screen.inspectable_at(on_strip), _permanent("Sword"))
	assert_eq(_screen.inspectable_at(on_bear), _permanent("Bear"), "Where the Equipment lies under the creature, the creature is pinned.")

	_screen.right_click_at(on_strip)
	assert_eq(_screen.inspector().shown_key(), _permanent("Sword"))
	assert_true(_screen.inspector().state_texts().has(["Attached", "Attached to Bear."]))
	_screen.right_click_at(on_bear)
	assert_eq(_screen.inspector().shown_key(), _permanent("Bear"))
	assert_true(_screen.inspector().state_texts().has(["Attachment", "Sword."]))


func test_an_equipment_turns_smoothly_onto_its_side_as_it_moves_behind_its_creature_and_back_as_it_comes_off() -> void:
	_open(_setup_of([_bear(), Scenario.sword("Sword"), Scenario.free_destroy("Murder")]))
	_cast("Bear")
	_cast("Sword")
	_screen.set_process(false)
	_screen.face_motion().seconds = 0.25

	_equip(_permanent("Sword"), _permanent("Bear"))
	for frame: int in 12:
		_screen.advance_motion(0.01)

	var sword: BattlefieldFace = _screen.face_of(_permanent("Sword")) as BattlefieldFace
	assert_gt(sword.card().rotation_degrees, 5.0, "Part of the way over,")
	assert_lt(sword.card().rotation_degrees, 85.0, "not snapped onto its side.")
	assert_false(sword.is_darkened(), "And never darkened on the way: it is not tapped.")
	for frame: int in 30:
		_screen.advance_motion(0.01)
	assert_eq(sword.card().rotation_degrees, 90.0)

	var bear: int = _permanent("Bear")
	_cast_at("Murder", bear)
	for frame: int in 12:
		_screen.advance_motion(0.01)
	sword = _screen.face_of(_permanent("Sword")) as BattlefieldFace
	assert_false(sword.is_attached())
	assert_gt(sword.card().rotation_degrees, 5.0, "It stands up again as smoothly")
	assert_lt(sword.card().rotation_degrees, 85.0, "once its creature has died.")
	for frame: int in 30:
		_screen.advance_motion(0.01)
	assert_eq(sword.card().rotation_degrees, 0.0)


func test_the_equipped_creature_shows_its_raised_power_and_toughness() -> void:
	_open_with_a_bear_and_a_sword()

	_equip(_permanent("Sword"), _permanent("Bear"))

	var look: CardLook = _presenter.snapshot().look_of(_permanent("Bear"))
	assert_eq([look.power, look.toughness], [3, 3])


func _open_with_a_bear_and_a_sword() -> void:
	_open(_setup_of([_bear(), Scenario.sword("Sword")]))
	_cast("Bear")
	_cast("Sword")


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))


func _setup_of(cards: Array[MmCardDefinition]) -> MmEncounterSetup:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	return Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40))


## Opens the screen and plays to the Hero's first main phase.
func _open(setup: MmEncounterSetup, parent: Node = null) -> void:
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
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	for attempt: int in 10:
		if _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


## Casts the card named [param card_name] from the Hero's hand and lets it resolve.
func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if action is CastSpellAction and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("No %s to cast." % card_name)


## Casts the card named [param card_name] at the permanent [param target_id] and lets it
## resolve.
func _cast_at(card_name: String, target_id: int) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if action is CastSpellAction and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			break
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	for index: int in target.candidates.size():
		if target.candidates[index].is_object() and target.candidates[index].id == target_id:
			assert_eq(_presenter.answer(index), "")
	_presenter.wait_until_idle()


## Activates equip on [param equipment_id] for [param creature_id] and lets it resolve.
func _equip(equipment_id: int, creature_id: int) -> void:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: ActivateAbilityAction = priority.actions[index] as ActivateAbilityAction
		if action != null and action.object_id == equipment_id:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	assert_not_null(target, "Equip asks for its target.")
	for index: int in target.candidates.size():
		if target.candidates[index].is_object() and target.candidates[index].id == creature_id:
			assert_eq(_presenter.answer(index), "")
	_presenter.wait_until_idle()
	assert_eq(_view_of(equipment_id).attached_to_object_id, creature_id)


func _view_of(object_id: int) -> MmObjectView:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.id == object_id:
			return permanent
	return null


func _permanent(card_name: String) -> int:
	var found: Array[int] = _permanents(card_name)
	return found[0] if not found.is_empty() else -1


func _permanents(card_name: String) -> Array[int]:
	var found: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			found.append(permanent.id)
	return found


func _button(button: MouseButton, is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = button
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click
