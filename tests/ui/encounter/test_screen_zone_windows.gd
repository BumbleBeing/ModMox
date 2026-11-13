extends GutTest
## Every graveyard, exile and library opens a Zone Window from its pile (13f, ADR 0032),
## and a card in a graveyard that can be targeted is chosen in its window: the pile glows,
## and the window opens by itself when nothing on the board answers.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const MINE: String = "hero_graveyard"
const TARGET: Color = Color("#ff5a2a")

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_click_on_any_pile_opens_its_window_and_a_second_closes_it() -> void:
	_open()
	_keep_and_reach_main()

	for key: String in EncounterLayout.pile_keys():
		var window: PileWindow = _screen.pile_window(key)
		assert_false(window.is_open(), key + " starts closed.")
		_screen.pile_catcher(key).clicked.emit()
		assert_true(window.is_open(), key)
		_screen.pile_catcher(key).clicked.emit()
		assert_false(window.is_open(), key)


func test_an_empty_pile_opens_an_empty_window() -> void:
	_open()
	_keep_and_reach_main()

	_screen.pile_catcher("villain_exile").clicked.emit()

	assert_true(_screen.pile_window("villain_exile").is_open())
	assert_eq(_screen.pile_window("villain_exile").title_text(), "Villain's Exile (0)")
	assert_eq(_screen.pile_window("villain_exile").entries(), [] as Array[int])


func test_a_graveyard_window_names_its_player_and_follows_what_the_zone_holds() -> void:
	_open(PlayerNames.new("Jackson", "Mishra"))
	_keep_and_reach_main()
	_screen.pile_catcher(MINE).clicked.emit()
	assert_eq(_screen.pile_window(MINE).title_text(), "Jackson's Graveyard (0)")

	_kill_a_bear()

	var window: PileWindow = _screen.pile_window(MINE)
	assert_eq(window.title_text(), "Jackson's Graveyard (2)", "It was open, and followed.")
	assert_eq(window.entries(), [_in_graveyard("Doom"), _in_graveyard("Bear")] as Array[int], "The newest first.")
	_screen.pile_catcher("villain_graveyard").clicked.emit()
	assert_eq(_screen.pile_window("villain_graveyard").title_text(), "Mishra's Graveyard (0)")


func test_a_window_opened_later_shows_what_the_zone_holds_then() -> void:
	_open()
	_keep_and_reach_main()
	_kill_a_bear()
	assert_eq(_screen.pile_window(MINE).entries(), [] as Array[int], "A closed window is not filled.")

	_screen.pile_catcher(MINE).clicked.emit()

	assert_eq(_screen.pile_window(MINE).entries().size(), 2)


func test_a_library_window_has_a_card_back_for_each_card_nobody_has_seen() -> void:
	_open()
	_keep_and_reach_main()

	_screen.pile_catcher("hero_library").clicked.emit()
	_screen.pile_catcher("villain_library").clicked.emit()

	var mine: PileWindow = _screen.pile_window("hero_library")
	var size: int = _presenter.snapshot().view.library_sizes[HERO]
	assert_eq(mine.title_text(), "Hero's Library (%d)" % size)
	assert_eq(mine.entries().size(), size)
	assert_eq(mine.entries().count(PileWindow.UNKNOWN), size)
	assert_eq(_screen.pile_window("villain_library").entries().count(PileWindow.UNKNOWN), _presenter.snapshot().view.library_sizes[VILLAIN])


func test_a_card_the_hero_put_on_the_bottom_is_face_up_at_the_right_of_their_library() -> void:
	_open()
	_presenter.answer(KeepOrMulliganDecision.Choice.MULLIGAN)
	_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	var bottom: ChooseCardsToBottomDecision = _presenter.snapshot().decision as ChooseCardsToBottomDecision
	var card_name: String = EncounterSnapshot.name_in(_presenter.snapshot().view, bottom.candidate_ids[2])
	_presenter.answer([bottom.candidate_ids[2]])
	_presenter.wait_until_idle()
	_pass_to_main()

	_screen.pile_catcher("hero_library").clicked.emit()

	var window: PileWindow = _screen.pile_window("hero_library")
	var last: int = window.entries().back()
	assert_ne(last, PileWindow.UNKNOWN)
	assert_eq(window.entries().count(PileWindow.UNKNOWN), window.entries().size() - 1)
	assert_eq(window.face_of(last).title_text().shown_text(), card_name)


func test_several_windows_are_open_at_once_and_each_reopens_where_it_was_left() -> void:
	_open()
	_keep_and_reach_main()
	_screen.pile_catcher(MINE).clicked.emit()
	_screen.pile_catcher("hero_exile").clicked.emit()
	var first: PileWindow = _screen.pile_window(MINE)
	var second: PileWindow = _screen.pile_window("hero_exile")
	assert_true(first.is_open() and second.is_open())
	assert_ne(first.position, second.position, "Two never open exactly over each other.")
	assert_true(_screen.get_rect().encloses(Rect2(first.position, first.size)))

	first.drag_by(Vector2(-200, -150))
	var left_at: Vector2 = first.position
	_screen.pile_catcher(MINE).clicked.emit()
	_screen.pile_catcher(MINE).clicked.emit()

	assert_true(first.is_open())
	assert_eq(first.position, left_at)


func test_a_window_opens_to_the_left_of_its_pile() -> void:
	_open()
	_keep_and_reach_main()

	_screen.pile_catcher("villain_graveyard").clicked.emit()

	var window: PileWindow = _screen.pile_window("villain_graveyard")
	assert_lt(window.position.x + window.size.x, _screen.pile_catcher("villain_graveyard").global_position.x)


func test_casting_at_a_card_in_a_graveyard_opens_its_window_and_the_cards_that_answer_glow() -> void:
	_open()
	_keep_and_reach_main()
	_kill_a_bear()
	assert_eq(_screen.pile_glow(MINE), [] as Array[Color], "Nothing is asked yet.")

	_do(CastSpellAction, "Raise")

	var window: PileWindow = _screen.pile_window(MINE)
	assert_true(_presenter.snapshot().decision is ChooseTargetDecision)
	assert_true(window.is_open(), "Only cards in the graveyard answer, so it opens by itself (A443).")
	assert_eq(_screen.pile_glow(MINE), [TARGET] as Array[Color])
	assert_eq(_screen.pile_glow("villain_graveyard"), [] as Array[Color])
	assert_eq(BorderEffects.glow_colors(window.face_of(_in_graveyard("Bear"))), [TARGET] as Array[Color])
	assert_null(window.catcher_of(_in_graveyard("Doom")), "A card that cannot be chosen takes no click.")
	assert_false(_screen.pile_window("villain_graveyard").is_open())


func test_clicking_a_glowing_card_chooses_it_and_the_window_closes() -> void:
	_open()
	_keep_and_reach_main()
	_kill_a_bear()
	var bears_held: int = _held("Bear")
	_do(CastSpellAction, "Raise")
	var window: PileWindow = _screen.pile_window(MINE)

	window.catcher_of(_in_graveyard("Bear")).clicked.emit()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseTargetDecision)
	assert_false(window.is_open(), "The game opened it, so the game closes it (A450).")
	assert_eq(_held("Bear"), bears_held + 1, "The Raise resolved.")
	assert_eq(_in_graveyard("Bear"), -1)


func test_canceling_the_cast_closes_the_window_too() -> void:
	_open()
	_keep_and_reach_main()
	_kill_a_bear()
	_do(CastSpellAction, "Raise")
	assert_true(_screen.pile_window(MINE).is_open())

	_presenter.cancel_cast()
	_presenter.wait_until_idle()

	assert_false(_screen.pile_window(MINE).is_open())
	assert_eq(_screen.pile_glow(MINE), [] as Array[Color])


func test_a_window_the_hero_had_open_stays_open_afterward() -> void:
	_open()
	_keep_and_reach_main()
	_kill_a_bear()
	_screen.pile_catcher(MINE).clicked.emit()
	_do(CastSpellAction, "Raise")
	var window: PileWindow = _screen.pile_window(MINE)
	assert_not_null(window.catcher_of(_in_graveyard("Bear")), "Already open, it shows what answers.")

	window.catcher_of(_in_graveyard("Bear")).clicked.emit()
	_presenter.wait_until_idle()

	assert_true(window.is_open())


func test_a_window_closed_by_hand_while_asked_stays_closed() -> void:
	_open()
	_keep_and_reach_main()
	_kill_a_bear()
	_do(CastSpellAction, "Raise")

	_screen.pile_catcher(MINE).clicked.emit()
	_screen.size = SCREEN - Vector2(40, 0)

	assert_false(_screen.pile_window(MINE).is_open(), "A redraw does not open it again.")
	assert_eq(_screen.pile_glow(MINE), [TARGET] as Array[Color], "The pile still glows, and a click opens it.")


func test_with_a_choice_on_the_board_too_the_pile_glows_and_opens_only_when_clicked() -> void:
	_open()
	_keep_and_reach_main()
	_kill_a_bear()
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	var asked: EncounterSnapshot = _presenter.snapshot()
	var real: MmPendingDecision = asked.decision
	# No card in the game can target a permanent or a card in a graveyard, so the screen is
	# shown a decision that offers both.
	asked.decision = ChooseTargetDecision.new(HERO, 0, 0, [
		MmReference.to_object(asked.view.battlefield[0].id), MmReference.to_object(_in_graveyard("Bear")),
	] as Array[MmReference])

	_presenter.changed.emit(asked)

	var window: PileWindow = _screen.pile_window(MINE)
	assert_eq(_screen.pile_glow(MINE), [TARGET] as Array[Color])
	assert_false(window.is_open(), "The Hero may mean the permanent (A443).")
	_screen.pile_catcher(MINE).clicked.emit()
	assert_true(window.is_open())
	assert_not_null(window.catcher_of(_in_graveyard("Bear")))

	asked.decision = real
	_presenter.changed.emit(asked)
	assert_false(window.is_open(), "Opened to answer, it closes once the target is no longer asked for.")


func test_a_real_click_on_a_card_in_a_graveyard_window_answers() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	add_child_autofree(viewport)
	_open(null, viewport)
	_keep_and_reach_main()
	_kill_a_bear()
	_do(CastSpellAction, "Raise")
	await wait_process_frames(3)
	var face: CardFace = _screen.pile_window(MINE).face_of(_in_graveyard("Bear"))
	var at: Vector2 = face.get_global_rect().get_center()

	viewport.push_input(_button(true, at))
	viewport.push_input(_button(false, at))
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseTargetDecision, "The click chose the Bear.")
	assert_eq(_in_graveyard("Bear"), -1)


func test_a_real_click_on_a_pile_opens_its_window() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	add_child_autofree(viewport)
	_open(null, viewport)
	_keep_and_reach_main()
	await wait_process_frames(2)
	var at: Vector2 = _screen.pile_catcher("hero_library").get_global_rect().get_center()

	viewport.push_input(_button(true, at))
	viewport.push_input(_button(false, at))

	assert_true(_screen.pile_window("hero_library").is_open())


func test_an_emblem_shows_its_rules_text_on_one_line_cut_with_an_ellipsis() -> void:
	var request: EncounterRequest = EncounterRequest.new()
	request.has_sample_emblems = true
	_open(PlayerNames.new("Jackson", ""), null, request.setup())

	var window: ZoneWindow = _screen.emblems_window(HERO)
	var entry: ZoneEntry = window.body().get_child(0) as ZoneEntry
	assert_eq(window.title_text(), "Jackson's Emblems (3)")
	assert_eq(entry.name_text(), "Sample Boon: Howling Winds")
	assert_true(entry.detail_text().begins_with("At the beginning of each player's draw step"), entry.detail_text())
	assert_false(AbilityText.has_fallback(entry.detail_text()))
	assert_true(entry.is_detail_cut())


func _button(is_pressed: bool, at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = is_pressed
	click.position = at
	click.global_position = at
	return click


## The Hero's deck cycles free Bears, Dooms ("destroy target creature") and Raises ("return
## target creature card from your graveyard to your hand"); a seed is found that deals one
## of each.
func _open(names: PlayerNames = null, parent: Node = null, setup: MmEncounterSetup = null) -> void:
	var cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.creature("Bear", 2, 2), Scenario.free_destroy("Doom"), Scenario.free_raise("Raise")])
	var chosen: MmEncounterSetup = setup
	for encounter_seed: int in range(1, 40) if setup == null else 0:
		chosen = Scenario.setup_with(cards, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var held: Array[String] = Scenario.names(MmEngine.start(chosen), MmEngine.start(chosen).hero().hand)
		if held.has("Bear") and held.has("Doom") and held.has("Raise"):
			break
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	if parent == null:
		add_child_autofree(_screen)
	else:
		parent.add_child(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(chosen, DefaultAnswerAgent.new())
	if names != null:
		_presenter.names = names
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()


func _keep_and_reach_main() -> void:
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_pass_to_main()


func _pass_to_main() -> void:
	for attempt: int in 10:
		if _presenter.snapshot().view.step == MmTurn.Step.PRECOMBAT_MAIN:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


## Casts a Bear and a Doom at it, leaving both in the Hero's graveyard.
func _kill_a_bear() -> void:
	_do(CastSpellAction, "Bear")
	_presenter.wait_until_idle()
	_do(CastSpellAction, "Doom")
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	for index: int in target.candidates.size():
		if EncounterSnapshot.name_in(_presenter.snapshot().view, target.candidates[index].id) == "Bear":
			_presenter.answer(index)
	_presenter.wait_until_idle()
	assert_ne(_in_graveyard("Bear"), -1, "The Bear died.")


## Takes the priority action of [param kind] about the card named [param card_name].
func _do(kind: Script, card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if is_instance_of(action, kind) and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			return
	fail_test("No %s action for %s." % [kind.resource_path.get_file(), card_name])


## The object ID of the card named [param card_name] in the Hero's graveyard, or -1.
func _in_graveyard(card_name: String) -> int:
	for seen: MmObjectView in _presenter.snapshot().view.graveyards[HERO]:
		if seen.name == card_name:
			return seen.id
	return -1


func _held(card_name: String) -> int:
	var count: int = 0
	for seen: MmObjectView in _presenter.snapshot().view.hand:
		if seen.name == card_name:
			count += 1
	return count
