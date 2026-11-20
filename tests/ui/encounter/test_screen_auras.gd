extends GutTest
## An Aura on the Encounter Screen (game ADR 0042, engine ADR 0064): a land glows as a target
## while an Aura is cast, and an Aura on a land lies sideways behind it in that land's row,
## whoever controls the land, with the land that much wider to its neighbors.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_land_glows_as_the_target_of_an_aura_and_a_click_on_it_answers() -> void:
	_open_with_forests(1)
	_begin_casting("Aura")
	var forest: int = _hero_permanents("Forest")[0]

	var catcher: ClickCatcher = _screen.click_catcher(forest)

	assert_not_null(catcher, "The Forest can be clicked as the Aura's target.")
	catcher.clicked.emit()
	_presenter.wait_until_idle()
	_resolve()
	assert_eq(_view_of(_hero_permanents("Aura")[0]).attached_to_object_id, forest)


func test_an_aura_on_a_land_lies_sideways_behind_it_in_the_lands_row() -> void:
	_open_with_forests(1)
	var forest: int = _hero_permanents("Forest")[0]

	_cast_at("Aura", forest)

	var aura: BattlefieldFace = _screen.face_of(_hero_permanents("Aura")[0]) as BattlefieldFace
	var land: BattlefieldFace = _screen.face_of(forest) as BattlefieldFace
	var strip: float = BattlefieldFace.attached_strip(aura.card().size.y)
	assert_true(aura.is_attached())
	assert_not_null(aura.attached_mark())
	assert_null(_screen.line("hero_others"), "It has left the other permanents.")
	assert_eq(aura.get_parent(), land.get_parent())
	assert_lt(aura.get_index(), land.get_index(), "The land is drawn over it.")
	assert_almost_eq(aura.get_global_rect().end.x, land.get_global_rect().end.x + strip, 0.01)
	assert_almost_eq(aura.get_global_rect().get_center().y, land.get_global_rect().get_center().y, 0.51)
	assert_almost_eq(aura.card().size.y, land.card().size.y, 0.01, "As tall as the land.")


func test_the_next_land_stands_the_usual_gap_past_an_enchanted_lands_name_strip() -> void:
	_open_with_forests(2)
	var forests: Array[int] = _hero_permanents("Forest")

	_cast_at("Aura", forests[0])

	var strip: float = BattlefieldFace.attached_strip((_screen.face_of(forests[0]) as BattlefieldFace).card().size.y)
	var first: Rect2 = _screen.face_of(forests[0]).get_global_rect()
	var second: Rect2 = _screen.face_of(forests[1]).get_global_rect()
	assert_almost_eq(second.position.x - first.end.x, strip + EncounterLayout.ROW_GAP, 0.01)


func test_an_aura_on_the_villains_land_lies_behind_it_in_the_villains_row() -> void:
	_open_with_forests(1)
	_play_to_the_heros_next_main_phase()
	var theirs: int = _permanents_of(1 - HERO, "Forest")[0]

	_cast_at("Aura", theirs)

	var aura: BattlefieldFace = _screen.face_of(_hero_permanents("Aura")[0]) as BattlefieldFace
	var land: Rect2 = _screen.face_of(theirs).get_global_rect()
	assert_true(aura.is_attached())
	assert_almost_eq(aura.get_global_rect().end.x, land.end.x + BattlefieldFace.attached_strip(aura.card().size.y), 0.01)
	assert_almost_eq(aura.get_global_rect().get_center().y, land.get_center().y, 0.51)


func test_layout_rows_give_a_land_the_room_of_its_attachments() -> void:
	var row_rect: Rect2 = Rect2(0, 0, 1000, 100)
	var plain: Array[Rect2] = EncounterLayout.row([false, false] as Array[bool], row_rect)
	var height: float = EncounterLayout.row_face_height([false, false] as Array[bool], row_rect, [2, 0] as Array[int])

	var spaced: Array[Rect2] = EncounterLayout.row([false, false] as Array[bool], row_rect, [2, 0] as Array[int])

	assert_almost_eq(plain[1].position.x - plain[0].end.x, EncounterLayout.ROW_GAP, 0.01)
	assert_almost_eq(spaced[1].position.x - spaced[0].end.x,
		EncounterLayout.attached_room(height, 2) + EncounterLayout.ROW_GAP, 0.01)
	assert_almost_eq((spaced[0].position.x - row_rect.position.x) + spaced[1].end.x, row_rect.size.x, 1.0,
		"Still centered, strips and all.")


## Opens the screen at the Hero's first main phase with [param count] Forests played and an
## Aura costing {0} in hand. Each player's deck is Forests and Auras.
func _open_with_forests(count: int) -> void:
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(Scenario.basic_land("Forest") if index % 2 == 0 else Scenario.aura())
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(Scenario.setup_with(deck, deck.duplicate()), DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_pass_to_heros_main()
	for land: int in count:
		if land > 0:
			_play_to_the_heros_next_main_phase()
		_play_a_land()


func _pass_to_heros_main() -> void:
	for attempt: int in 40:
		var view: MmPlayerView = _presenter.snapshot().view
		if view.step == MmTurn.Step.PRECOMBAT_MAIN and view.active_player_id == HERO \
				and _presenter.snapshot().decision is PriorityDecision:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


func _play_to_the_heros_next_main_phase() -> void:
	for attempt: int in 10:
		if _presenter.snapshot().view.step != MmTurn.Step.PRECOMBAT_MAIN:
			break
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	_pass_to_heros_main()


func _play_a_land() -> void:
	var priority: PriorityDecision = _presenter.snapshot().decision as PriorityDecision
	for index: int in priority.actions.size():
		if priority.actions[index] is PlayLandAction:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("No land to play.")


func _begin_casting(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var action: MmAction = priority.actions[index]
		if action is CastSpellAction and EncounterSnapshot.name_in(snapshot.view, DecisionClicks.object_of(action)) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			return
	fail_test("No %s to cast." % card_name)


## Casts [param card_name] at the permanent [param target_id] and lets it resolve.
func _cast_at(card_name: String, target_id: int) -> void:
	_begin_casting(card_name)
	var target: ChooseTargetDecision = _presenter.snapshot().decision as ChooseTargetDecision
	assert_not_null(target, "An Aura asks for its target.")
	for index: int in target.candidates.size():
		if target.candidates[index].is_object() and target.candidates[index].id == target_id:
			assert_eq(_presenter.answer(index), "")
	_presenter.wait_until_idle()
	_resolve()


func _resolve() -> void:
	for attempt: int in 10:
		if _presenter.snapshot().view.stack.is_empty():
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


func _view_of(object_id: int) -> MmObjectView:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.id == object_id:
			return permanent
	return null


func _hero_permanents(card_name: String) -> Array[int]:
	return _permanents_of(HERO, card_name)


func _permanents_of(player_id: int, card_name: String) -> Array[int]:
	var found: Array[int] = []
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name and permanent.controller_id == player_id:
			found.append(permanent.id)
	return found
