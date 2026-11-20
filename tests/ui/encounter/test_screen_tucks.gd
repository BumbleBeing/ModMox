extends GutTest
## A Tucked Card on the Encounter Screen (game ADR 0043): a card in exile lies behind the
## permanent that exiled it as an attachment does, with no Attached Mark and past every
## attachment; its exile pile counts it and does not show it; and while that exile's Pile
## Window is open the card is in the window, a Tuck Outline keeping its place. The Prison
## is Oblivion Ring's two abilities on an enchantment costing {0}.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const MOVE: float = 0.25
const FLIGHT: float = 0.4
const NEAR: Vector2 = Vector2(1.0, 1.0)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_card_exiled_by_a_permanent_lies_sideways_behind_it_with_no_attached_mark() -> void:
	_open_with_a_bear_in_prison()

	var bear: BattlefieldFace = _screen.face_of(_exiled("Bear")) as BattlefieldFace
	var prison: BattlefieldFace = _screen.face_of(_permanent("Prison")) as BattlefieldFace
	assert_not_null(bear, "It is drawn as a Battlefield Face, though it is in exile.")
	var strip: float = BattlefieldFace.attached_strip(bear.card().size.y)
	assert_true(bear.is_attached())
	assert_eq(bear.card().rotation_degrees, 90.0)
	assert_null(bear.attached_mark(), "The plus is for what is attached.")
	assert_false(bear.is_darkened())
	assert_eq(bear.get_parent(), prison.get_parent())
	assert_lt(bear.get_index(), prison.get_index(), "It is drawn first, so the permanent is drawn over it.")
	assert_almost_eq(bear.get_global_rect().end.x, prison.get_global_rect().end.x + strip, 0.01)
	assert_almost_eq(bear.get_global_rect().get_center().y, prison.get_global_rect().get_center().y, 0.51)
	assert_almost_eq(_screen.line("hero_others").content_width(), EncounterLayout.LINE_PAD * 2.0 + prison.size.x + strip, 0.01,
		"The line counts the strip.")
	assert_gte(_screen.line("hero_others").size.x, _screen.line("hero_others").content_width(), "And its group has the room.")


func test_the_exile_pile_counts_a_tucked_card_and_does_not_show_it() -> void:
	_open_with_a_bear_in_prison()

	assert_eq(_screen.pile_text("hero_exile"), "Exile (1)")
	assert_false(_screen.face_of(_exiled("Bear")) is CardFace, "No card lies on the pile.")
	_screen.pile_catcher("hero_exile").clicked.emit()
	assert_eq(_screen.pile_window("hero_exile").title_text(), "Hero's Exile (1)")


func test_a_tucked_card_lies_behind_every_attachment() -> void:
	_open(_setup_of([_bear(), _jailer(), Scenario.sword("Sword")]))
	_cast("Bear")
	_cast("Sword")
	_cast("Jailer", [_permanent("Bear")])
	_equip(_permanent("Sword"), _permanent("Jailer"))

	var jailer: Rect2 = _screen.face_of(_permanent("Jailer")).get_global_rect()
	var sword: BattlefieldFace = _screen.face_of(_permanent("Sword")) as BattlefieldFace
	var bear: BattlefieldFace = _screen.face_of(_exiled("Bear")) as BattlefieldFace
	var strip: float = BattlefieldFace.attached_strip(sword.card().size.y)
	assert_gt(_permanent("Sword"), 0)
	assert_almost_eq(sword.get_global_rect().end.x, jailer.end.x + strip, 0.01, "The attachment is nearest,")
	assert_almost_eq(bear.get_global_rect().end.x, jailer.end.x + strip * 2.0, 0.01, "and the Tucked Card past it.")
	assert_lt(bear.get_index(), sword.get_index(), "The outer one is drawn under the inner.")
	assert_not_null(sword.attached_mark())
	assert_null(bear.attached_mark())


func test_two_cards_exiled_by_one_permanent_lie_in_id_order() -> void:
	_open(_setup_of([_bear(), _twin_jailer()]))
	_cast("Bear")
	_cast("Bear")
	var bears: Array[int] = _permanents("Bear")

	_cast("Twin Jailer", bears)

	var exiled: Array[int] = _all_exiled("Bear")
	assert_eq(exiled.size(), 2)
	var jailer: Rect2 = _screen.face_of(_permanent("Twin Jailer")).get_global_rect()
	var strip: float = BattlefieldFace.attached_strip((_screen.face_of(exiled[0]) as BattlefieldFace).card().size.y)
	assert_almost_eq(_screen.face_of(exiled[0]).get_global_rect().end.x, jailer.end.x + strip, 0.01, "The lower ID lies nearest.")
	assert_almost_eq(_screen.face_of(exiled[1]).get_global_rect().end.x, jailer.end.x + strip * 2.0, 0.01)


func test_only_the_strip_of_a_tucked_card_is_pinned_and_the_inspector_says_both_ends() -> void:
	_open_with_a_bear_in_prison()
	var prison: Rect2 = _screen.face_of(_permanent("Prison")).get_global_rect()
	var bear: Rect2 = _screen.face_of(_exiled("Bear")).get_global_rect()
	var on_strip: Vector2 = Vector2((prison.end.x + bear.end.x) / 2.0, bear.get_center().y) - _screen.global_position
	var on_prison: Vector2 = Vector2(prison.end.x - 6.0, prison.get_center().y) - _screen.global_position

	assert_eq(_screen.inspectable_at(on_strip), _exiled("Bear"))
	assert_eq(_screen.inspectable_at(on_prison), _permanent("Prison"), "Where the card lies under the permanent, the permanent is pinned.")

	_screen.right_click_at(on_strip)
	assert_eq(_screen.inspector().shown_key(), _exiled("Bear"))
	assert_true(_screen.inspector().state_texts().has(["Exiled", "Exiled by Prison."]))
	_screen.right_click_at(on_prison)
	assert_eq(_screen.inspector().shown_key(), _permanent("Prison"))
	assert_true(_screen.inspector().state_texts().has(["Exiled Card", "Bear."]))


func test_once_its_permanent_has_gone_the_card_flies_from_behind_it_to_the_pile_and_from_there_to_the_battlefield() -> void:
	_open_with_a_bear_in_prison(FLIGHT)
	_settle()
	var exiled: int = _exiled("Bear")
	var tucked: Vector2 = _middle(_screen.face_of(exiled))
	_screen.set_hold_key_down(true)
	_cast_only("Disenchant")
	_answer_targets([_permanent("Prison")])
	_settle()

	_presenter.pass_priority()
	_presenter.wait_until_idle()

	assert_eq(_permanent("Prison"), -1)
	assert_eq(_exiled("Bear"), exiled, "Its trigger is on the stack, and the card is still in exile.")
	var falling: FlightCard = _screen.flight_card_of(exiled)
	assert_not_null(falling, "Nothing holds it now, so it goes to the pile.")
	assert_almost_eq(falling.position, tucked, NEAR)
	assert_true(falling.leaving_face() is BattlefieldFace, "It leaves as it lay,")
	assert_true(falling.landing_face() is CardFace, "and lands as a card of the pile.")
	assert_null(_screen.ghost_of(exiled), "It leaves no ghost behind.")
	assert_true(_screen.face_of(exiled) is CardFace)
	assert_eq(_screen.face_of(exiled).modulate.a, 0.0, "The pile shows nothing of it until it lands.")
	_settle()
	assert_eq(_screen.face_of(exiled).modulate.a, 1.0)
	var on_pile: Vector2 = _middle(_screen.face_of(exiled))

	_screen.set_hold_key_down(false)
	_resolve()

	var bear: int = _permanent("Bear")
	assert_gt(bear, 0, "It is back on the battlefield.")
	assert_almost_eq(_screen.flight_card_of(bear).position, on_pile, NEAR)
	_settle()
	assert_eq(_screen.face_of(bear).modulate.a, 1.0)


func test_a_card_exiled_until_its_permanent_leaves_flies_from_behind_it_straight_to_the_battlefield() -> void:
	# Leyline Binding's exile (engine ADR 0065): the card returns in the same action as its
	# permanent leaves, so it never lands on the pile.
	_open(_setup_of([_bear(), Scenario.free_binding("Binding", Scenario.another_nonland_permanent()),
		Scenario.free_disenchant("Disenchant")]), FLIGHT)
	_cast("Bear")
	_cast("Binding", [_permanent("Bear")])
	_settle()
	var exiled: int = _exiled("Bear")
	assert_gt(exiled, 0, "The Binding exiled the Bear.")
	var tucked: Vector2 = _middle(_screen.face_of(exiled))

	_cast("Disenchant", [_permanent("Binding")])

	assert_eq(_permanent("Binding"), -1)
	var bear: int = _permanent("Bear")
	assert_gt(bear, 0, "It is back on the battlefield.")
	var flying: FlightCard = _screen.flight_card_of(bear)
	assert_not_null(flying)
	assert_almost_eq(flying.position, tucked, NEAR)
	assert_true(flying.leaving_face() is BattlefieldFace, "It leaves as it lay.")
	_settle()
	assert_eq(_screen.face_of(bear).modulate.a, 1.0)
	assert_eq(_screen.pile_text("hero_exile"), "Exile (0)", "It never landed on the pile.")


func test_a_card_whose_permanent_left_before_it_was_exiled_is_in_the_pile() -> void:
	_open(_setup_of([_bear(), Scenario.free_prison("Prison"), Scenario.free_disenchant("Disenchant")]))
	_cast("Bear")
	_cast_only("Prison")
	_resolve()
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision, "Its trigger asks for its target.")
	_screen.set_hold_key_down(true)
	_answer_targets([_permanent("Bear")])
	assert_true(_presenter.snapshot().decision is PriorityDecision, "The Hero keeps priority with the trigger on the stack.")
	assert_eq(_presenter.snapshot().view.stack.size(), 1)
	_cast_only("Disenchant")
	_answer_targets([_permanent("Prison")])
	_screen.set_hold_key_down(false)
	_resolve()

	assert_eq(_permanent("Prison"), -1)
	var bear: int = _exiled("Bear")
	assert_gt(bear, 0, "Exiled for good.")
	assert_true(_screen.face_of(bear) is CardFace, "It lies on the pile like any other card.")
	assert_eq(_screen.pile_text("hero_exile"), "Exile (1)")


func test_opening_the_exile_window_flies_the_card_there_and_leaves_a_tuck_outline() -> void:
	_open_with_a_bear_in_prison(FLIGHT)
	_settle()
	var bear: int = _exiled("Bear")
	var tucked: Vector2 = _middle(_screen.face_of(bear))
	var width: float = _screen.line("hero_others").content_width()

	_screen.pile_catcher("hero_exile").clicked.emit()

	var window: PileWindow = _screen.pile_window("hero_exile")
	assert_true(window.is_open())
	assert_null(_screen.face_of(bear), "Nothing of it lies behind the permanent now,")
	var outline: Control = _screen.tuck_outline_of(bear)
	assert_not_null(outline, "but its outline does.")
	assert_almost_eq(outline.get_global_rect().get_center() - _screen.global_position, tucked, NEAR)
	assert_eq(_screen.line("hero_others").content_width(), width, "The line keeps the strip's room.")
	assert_null(_screen.ghost_of(bear))
	var flying: FlightCard = _screen.flight_card_of(bear)
	assert_not_null(flying)
	assert_almost_eq(flying.position, tucked, NEAR, "It takes off from behind the permanent.")
	assert_true(flying.leaving_face() is BattlefieldFace)
	assert_true(flying.landing_face() is CardFace)
	assert_eq(window.face_of(bear).modulate.a, 0.0, "The window shows nothing of it until it lands.")

	await wait_process_frames(2)
	_settle()
	assert_null(_screen.flight_card_of(bear))
	assert_eq(window.face_of(bear).modulate.a, 1.0)


func test_a_card_on_its_way_to_the_window_is_aimed_at_its_place_there() -> void:
	_open_with_a_bear_in_prison(FLIGHT)
	_settle()
	var bear: int = _exiled("Bear")
	_screen.pile_catcher("hero_exile").clicked.emit()
	await wait_process_frames(2)

	_advance(FLIGHT * 0.99)

	var window: PileWindow = _screen.pile_window("hero_exile")
	assert_almost_eq(_screen.flight_card_of(bear).position, _middle(window.face_of(bear)), Vector2(6.0, 6.0))


func test_closing_the_exile_window_flies_the_card_back_behind_its_permanent() -> void:
	_open_with_a_bear_in_prison(FLIGHT)
	_settle()
	var bear: int = _exiled("Bear")
	var tucked: Vector2 = _middle(_screen.face_of(bear))
	_screen.pile_catcher("hero_exile").clicked.emit()
	await wait_process_frames(2)
	_settle()
	var in_window: Vector2 = _middle(_screen.pile_window("hero_exile").face_of(bear))

	_screen.pile_catcher("hero_exile").clicked.emit()

	assert_false(_screen.pile_window("hero_exile").is_open())
	assert_null(_screen.tuck_outline_of(bear))
	var face: BattlefieldFace = _screen.face_of(bear) as BattlefieldFace
	assert_not_null(face)
	assert_eq(face.modulate.a, 0.0, "What it lands on shows nothing of it until it arrives.")
	var flying: FlightCard = _screen.flight_card_of(bear)
	assert_not_null(flying)
	assert_almost_eq(flying.position, in_window, NEAR)
	_settle()
	assert_null(_screen.flight_card_of(bear))
	assert_eq(face.modulate.a, 1.0)
	assert_almost_eq(_middle(face), tucked, NEAR)
	assert_eq(face.card().rotation_degrees, 90.0)


func test_the_windows_own_close_button_sends_the_card_back_too() -> void:
	_open_with_a_bear_in_prison()
	var bear: int = _exiled("Bear")
	_screen.pile_catcher("hero_exile").clicked.emit()
	assert_null(_screen.face_of(bear))

	_screen.pile_window("hero_exile").close_button().pressed.emit()

	assert_not_null(_screen.face_of(bear))
	assert_null(_screen.tuck_outline_of(bear))


func test_nothing_flies_with_no_flight_speed_and_the_card_is_simply_in_the_window() -> void:
	_open_with_a_bear_in_prison()
	var bear: int = _exiled("Bear")

	_screen.pile_catcher("hero_exile").clicked.emit()

	assert_null(_screen.flight_card_of(bear))
	assert_null(_screen.ghost_of(bear))
	assert_not_null(_screen.tuck_outline_of(bear))
	assert_eq(_screen.pile_window("hero_exile").face_of(bear).modulate.a, 1.0)


func test_the_permanent_leaving_while_the_window_is_open_flies_the_card_from_the_window() -> void:
	_open_with_a_bear_in_prison(FLIGHT)
	_settle()
	_screen.pile_catcher("hero_exile").clicked.emit()
	await wait_process_frames(2)
	_settle()
	var in_window: Vector2 = _middle(_screen.pile_window("hero_exile").face_of(_exiled("Bear")))

	_cast("Disenchant", [_permanent("Prison")])

	var flying: FlightCard = _screen.flight_card_of(_permanent("Bear"))
	assert_not_null(flying)
	assert_almost_eq(flying.position, in_window, NEAR, "Not from the pile: the window had it.")
	assert_true(flying.leaving_face() is CardFace)
	assert_null(_screen.tuck_outline_of(_exiled_before))


func test_the_card_under_the_cursor_in_the_window_gives_its_tuck_outline_a_white_dashed_border() -> void:
	_open_with_a_bear_in_prison()
	var bear: int = _exiled("Bear")
	_screen.pile_catcher("hero_exile").clicked.emit()
	await wait_process_frames(2)
	var outline: Control = _screen.tuck_outline_of(bear)
	var on_card: Vector2 = _middle(_screen.pile_window("hero_exile").face_of(bear))
	assert_null(BorderEffects.mark_color(outline))

	_screen.follow_tuck_marks(on_card, 0.0)
	assert_eq(BorderEffects.mark_color(outline), Color.WHITE)
	assert_true(BorderEffects.is_mark_dashed(outline))

	_screen.follow_tuck_marks(Vector2(5.0, 5.0), 0.0)
	assert_null(BorderEffects.mark_color(outline), "It goes when the cursor does.")


func test_a_pinned_card_keeps_its_tuck_outlines_border_and_the_outline_pins_nothing() -> void:
	_open_with_a_bear_in_prison()
	var bear: int = _exiled("Bear")
	_screen.pile_catcher("hero_exile").clicked.emit()
	await wait_process_frames(2)
	var on_card: Vector2 = _middle(_screen.pile_window("hero_exile").face_of(bear))
	var prison: Rect2 = _screen.face_of(_permanent("Prison")).get_global_rect()
	var outline_rect: Rect2 = _screen.tuck_outline_of(bear).get_global_rect()
	var on_outline: Vector2 = Vector2((prison.end.x + outline_rect.end.x) / 2.0, outline_rect.get_center().y) - _screen.global_position

	assert_eq(_screen.inspectable_at(on_outline), Inspection.NOTHING)

	_screen.right_click_at(on_card)
	_screen.follow_tuck_marks(Vector2(5.0, 5.0), 0.0)
	assert_eq(_screen.inspector().shown_key(), bear)
	assert_eq(BorderEffects.mark_color(_screen.tuck_outline_of(bear)), Color.WHITE)


func _open_with_a_bear_in_prison(flight_seconds: float = 0.0) -> void:
	_open(_setup_of([_bear(), Scenario.free_prison("Prison"), Scenario.free_disenchant("Disenchant")]), flight_seconds)
	_cast("Bear")
	_cast("Prison", [_permanent("Bear")])
	_exiled_before = _exiled("Bear")
	assert_gt(_exiled_before, 0, "The Prison exiled the Bear.")


var _exiled_before: int = -1


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))


## A free 2/2 with the Prison's two abilities.
func _jailer() -> MmCardDefinition:
	return Scenario.creature("Jailer", 2, 2, Scenario.free_prison("Prison").abilities, Scenario.mana_cost(0))


## A free 2/2 that exiles twice as it enters: no card in Content does.
func _twin_jailer() -> MmCardDefinition:
	var abilities: Array[MmAbility] = Scenario.free_prison("Prison").abilities
	abilities.insert(0, Scenario.free_prison("Prison").abilities[0])
	return Scenario.creature("Twin Jailer", 2, 2, abilities, Scenario.mana_cost(0))


func _setup_of(cards: Array[MmCardDefinition]) -> MmEncounterSetup:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	return Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40))


## Opens the screen and plays to the Hero's first main phase. Its faces take MOVE seconds
## to move and its cards [param flight_seconds] to fly; frames go by only as a test says.
func _open(setup: MmEncounterSetup, flight_seconds: float = 0.0) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.set_process(false)
	_screen.size = SCREEN
	_screen.position = Vector2(30, 20)
	_screen.face_motion().seconds = MOVE if flight_seconds > 0.0 else 0.0
	_screen.flight_layer().seconds = flight_seconds
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


## Casts the card named [param card_name] from the Hero's hand, answers each target it or
## its triggers ask for from [param target_ids] in turn, and lets everything resolve.
func _cast(card_name: String, target_ids: Array[int] = []) -> void:
	_cast_only(card_name)
	_answer_targets(target_ids)
	_resolve()
	_answer_targets(target_ids)
	_resolve()


func _cast_only(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if action is CastSpellAction and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("No %s to cast." % card_name)


## Answers each target asked for now with the first of [param target_ids] it offers, and
## puts triggers on the stack in the order offered.
func _answer_targets(target_ids: Array[int]) -> void:
	var used: Array[int] = []
	for attempt: int in 6:
		var decision: MmPendingDecision = _presenter.snapshot().decision
		if decision is OrderTriggersDecision:
			_presenter.answer(range((decision as OrderTriggersDecision).source_object_ids.size()))
			_presenter.wait_until_idle()
			continue
		var target: ChooseTargetDecision = decision as ChooseTargetDecision
		if target == null:
			return
		for index: int in target.candidates.size():
			var candidate: MmReference = target.candidates[index]
			if candidate.is_object() and target_ids.has(candidate.id) and not used.has(candidate.id):
				used.append(candidate.id)
				assert_eq(_presenter.answer(index), "")
				break
		_presenter.wait_until_idle()


## Passes priority until the stack is empty.
func _resolve() -> void:
	for attempt: int in 10:
		var snapshot: EncounterSnapshot = _presenter.snapshot()
		if snapshot.view.stack.is_empty() or not (snapshot.decision is PriorityDecision):
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


## Activates equip on [param equipment_id] for [param creature_id] and lets it resolve.
func _equip(equipment_id: int, creature_id: int) -> void:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: ActivateAbilityAction = priority.actions[index] as ActivateAbilityAction
		if action != null and action.object_id == equipment_id:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			break
	_answer_targets([creature_id])
	_resolve()


func _permanent(card_name: String) -> int:
	var found: Array[int] = _permanents(card_name)
	return found[0] if not found.is_empty() else -1


func _permanents(card_name: String) -> Array[int]:
	var found: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			found.append(permanent.id)
	return found


## The first card named [param card_name] in the Hero's exile, or -1.
func _exiled(card_name: String) -> int:
	var found: Array[int] = _all_exiled(card_name)
	return found[0] if not found.is_empty() else -1


func _all_exiled(card_name: String) -> Array[int]:
	var found: Array[int] = []
	for card: MmObjectView in _presenter.snapshot().view.exiles.get(HERO, []):
		if card.name == card_name:
			found.append(card.id)
	found.sort()
	return found


## Lets [param seconds] go by in short frames, and a hair more.
func _advance(seconds: float) -> void:
	var frames: int = ceili(seconds / 0.01)
	for frame: int in frames:
		_screen.advance_motion(seconds / frames)
	_screen.advance_motion(0.000001)


## Lets every move and flight finish.
func _settle() -> void:
	_advance(FLIGHT * 1.5)


## Where the middle of [param face] is drawn, in the screen's coordinates.
func _middle(face: Control) -> Vector2:
	return face.get_global_transform() * (face.size / 2.0) - _screen.global_position
