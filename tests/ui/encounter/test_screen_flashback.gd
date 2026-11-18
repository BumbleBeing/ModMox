extends GutTest
## Casting with flashback on the Encounter Screen (game ADR 0049): the Hero's graveyard
## pile glows green while a card in it can be cast, the card glows in the Graveyard window
## and a click there casts it; creatures to tap for its cost glow green, a click picks one
## (white, and drawn turned in its place) or lets it go, and the click that makes the last
## pick answers it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const MINE: String = "hero_graveyard"
const PLAY: Color = Color("#7be36a")

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_the_pile_glows_green_and_its_window_casts_the_card() -> void:
	_open_with_echo_in_graveyard()
	var echo: int = _in_graveyard("Echo")

	assert_eq(_screen.pile_glow(MINE), [PLAY] as Array[Color], "Green: a card to cast.")
	assert_false(_screen.pile_window(MINE).is_open(), "Passing answers too, so it waits for a click.")
	_screen.pile_catcher(MINE).clicked.emit()
	var window: PileWindow = _screen.pile_window(MINE)
	assert_true(window.is_open())
	assert_not_null(window.catcher_of(echo), "The card takes the click.")
	window.catcher_of(echo).clicked.emit()
	_presenter.wait_until_idle()

	assert_true(_presenter.snapshot().decision is ChoosePermanentsDecision, "Its flashback cost asks which creatures.")
	assert_false(window.is_open(), "Closed with the click that began the cast.")


func test_a_picked_creature_is_drawn_turned_and_white_and_stays_in_its_row() -> void:
	_open_with_echo_in_graveyard()
	_screen.pile_catcher(MINE).clicked.emit()
	_screen.pile_window(MINE).catcher_of(_in_graveyard("Echo")).clicked.emit()
	_presenter.wait_until_idle()
	var bears: Array[int] = _bears()
	assert_eq(BorderEffects.glow_colors(_screen.face_of(bears[0])), [PLAY] as Array[Color])
	assert_true(_screen.info_panel().prompt_text().begins_with("Tap two untapped creatures you control for Echo"))
	var row_center: float = _center_y(bears[1])

	_screen.click_catcher(bears[0]).clicked.emit()

	var picked: Control = _screen.face_of(bears[0])
	assert_eq(BorderEffects.glow_colors(picked), [Color.WHITE] as Array[Color])
	assert_true(_screen.is_drawn_tapped(bears[0]), "Drawn as it will be once tapped.")
	var upright: Vector2 = _screen.face_of(bears[1]).size
	assert_eq(picked.size, Vector2(upright.y, upright.x), "The face itself is turned, so its Glow is round it.")
	assert_almost_eq(_center_y(bears[0]), row_center, 1.0, "It stays in its row, not lifted out of it.")
	assert_true(_screen.info_panel().prompt_text().ends_with("(1 of 2)"))
	assert_true(_presenter.snapshot().decision is ChoosePermanentsDecision, "One of two: nothing answered yet.")


func test_the_click_that_makes_the_last_pick_casts_the_spell() -> void:
	_open_with_echo_in_graveyard()
	_screen.pile_catcher(MINE).clicked.emit()
	_screen.pile_window(MINE).catcher_of(_in_graveyard("Echo")).clicked.emit()
	_presenter.wait_until_idle()
	var bears: Array[int] = _bears()
	_presenter.is_hold_key_down = true  # So it stays on the stack to be seen.

	_screen.click_catcher(bears[0]).clicked.emit()
	_screen.click_catcher(bears[1]).clicked.emit()
	_presenter.wait_until_idle()

	var stack: Array[MmObjectView] = _presenter.snapshot().view.stack
	assert_eq(stack.size(), 1, "Cast with no confirm.")
	assert_true(stack[0].cast_with_flashback)
	for id: int in bears.slice(0, 2):
		assert_true(_permanent(id).is_tapped)


func test_a_picked_creature_clicked_again_is_let_go_and_undo_takes_back_a_click() -> void:
	_open_with_echo_in_graveyard()
	_screen.pile_catcher(MINE).clicked.emit()
	_screen.pile_window(MINE).catcher_of(_in_graveyard("Echo")).clicked.emit()
	_presenter.wait_until_idle()
	var bears: Array[int] = _bears()

	_screen.click_catcher(bears[0]).clicked.emit()
	_screen.click_catcher(bears[0]).clicked.emit()
	assert_false(_screen.is_drawn_tapped(bears[0]))
	_screen.click_catcher(bears[1]).clicked.emit()
	_screen.undo()

	assert_false(_screen.is_drawn_tapped(bears[1]))
	assert_true(_presenter.snapshot().decision is ChoosePermanentsDecision, "Nothing was answered.")


## The Hero's deck cycles free Bears and Echo, "You gain 1 life. Flashback—Tap two untapped
## creatures you control"; a seed deals two Bears and an Echo. The Hero casts them all and
## Echo is in their graveyard, with priority in their main phase.
func _open_with_echo_in_graveyard() -> void:
	var costs: Array[MmCost] = [Scenario.tap_creatures(2)]
	var echo: MmCardDefinition = Scenario.flashback_sorcery("Echo", [], [Scenario.gain_life(1, Scenario.you())],
		Scenario.flashback(null, costs))
	var cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.creature("Bear", 2, 2), Scenario.creature("Bear", 2, 2), echo])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 40):
		chosen = Scenario.setup_with(cards, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var held: Array[String] = Scenario.names(MmEngine.start(chosen), MmEngine.start(chosen).hero().hand)
		if held.count("Bear") >= 2 and held.has("Echo"):
			break
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
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
	for card_name: String in ["Bear", "Bear", "Echo"]:
		_cast(card_name)
	assert_ne(_in_graveyard("Echo"), -1, "Echo resolved into the graveyard.")


## Casts the card named [param card_name] from the hand and lets it resolve.
func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and _in_hand(cast.object_id) and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			while not _presenter.snapshot().view.stack.is_empty():
				_presenter.pass_priority()
				_presenter.wait_until_idle()
			return
	fail_test("No cast of %s." % card_name)


func _in_hand(object_id: int) -> bool:
	for seen: MmObjectView in _presenter.snapshot().view.hand:
		if seen.id == object_id:
			return true
	return false


func _in_graveyard(card_name: String) -> int:
	for seen: MmObjectView in _presenter.snapshot().view.graveyards[HERO]:
		if seen.name == card_name:
			return seen.id
	return -1


## The middle of Game Object [param object_id]'s face, up and down, on the screen.
func _center_y(object_id: int) -> float:
	var face: Control = _screen.face_of(object_id)
	return face.get_global_rect().get_center().y


func _bears() -> Array[int]:
	var ids: Array[int] = []
	for seen: MmObjectView in _presenter.snapshot().view.battlefield:
		if seen.name == "Bear":
			ids.append(seen.id)
	ids.sort()
	return ids


func _permanent(object_id: int) -> MmObjectView:
	for seen: MmObjectView in _presenter.snapshot().view.battlefield:
		if seen.id == object_id:
			return seen
	return null
