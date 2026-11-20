extends GutTest
## Searching a library on the Encounter Screen (game ADR 0058). As a search resolves, the
## Hero's Library window opens by itself as a grid of every card face up, the cards the
## search may find first and then the rest, each by name. A click selects a card the search
## may find and a second click lets it go; once as many are selected as may be found, the
## rest stop glowing. Only the pass button or the space bar finds them: it reads "Find
## nothing", "Find Forest" or "Find 2 cards". Seek is "Search your library for a basic land
## card, reveal it, put it into your hand, then shuffle." costing {0}; Grove is a nonbasic
## land.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const MINE: String = "hero_library"
const GREEN: Color = Color("#7be36a")

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_search_opens_the_library_window_by_itself_as_a_grid_with_what_it_may_find_first() -> void:
	_open_searching()

	var window: PileWindow = _screen.pile_window(MINE)
	assert_true(window.is_open(), "Opened by the search itself.")
	var search: ChooseCardsInLibraryDecision = _search()
	var entries: Array[int] = window.entries()
	assert_eq(entries.size(), _presenter.snapshot().view.libraries[HERO].size(), "Every card of the library.")
	assert_false(entries.has(PileWindow.UNKNOWN), "Every card face up.")
	var first: Array[int] = entries.slice(0, search.candidate_ids.size())
	first.sort()
	var candidates: Array[int] = search.candidate_ids.duplicate()
	candidates.sort()
	assert_eq(first, candidates, "What may be found comes first.")
	assert_eq(BorderEffects.glow_colors(window.face_of(search.candidate_ids[0])), [GREEN] as Array[Color])
	assert_eq(BorderEffects.glow_colors(window.face_of(entries.back())), [] as Array[Color], "A Grove may not be found.")
	assert_eq(_screen.info_panel().prompt_text(), "Seek: search your library for a basic land card")
	assert_eq(_screen.pass_button().shown_text(), "Find nothing")


func test_a_click_selects_a_card_and_a_second_click_lets_it_go() -> void:
	_open_searching()
	var search: ChooseCardsInLibraryDecision = _search()
	var forest: int = search.candidate_ids[0]
	var other: int = search.candidate_ids[1]

	_screen.pile_window(MINE).catcher_of(forest).clicked.emit()

	var window: PileWindow = _screen.pile_window(MINE)
	assert_eq(BorderEffects.glow_colors(window.face_of(forest)), [Color.WHITE] as Array[Color], "Selected glows white.")
	assert_eq(BorderEffects.glow_colors(window.face_of(other)), [] as Array[Color], "One may be found, so no more.")
	assert_null(window.catcher_of(other), "Nor does another take a click.")
	assert_eq(_screen.pass_button().shown_text(), "Find Forest")
	assert_true(_presenter.snapshot().decision is ChooseCardsInLibraryDecision, "A click alone finds nothing.")

	window.catcher_of(forest).clicked.emit()

	window = _screen.pile_window(MINE)
	assert_eq(BorderEffects.glow_colors(window.face_of(forest)), [GREEN] as Array[Color])
	assert_eq(BorderEffects.glow_colors(window.face_of(other)), [GREEN] as Array[Color])
	assert_eq(_screen.pass_button().shown_text(), "Find nothing")


func test_the_pass_button_finds_the_selected_card_and_the_window_closes() -> void:
	_open_searching()
	var forest: int = _search().candidate_ids[0]
	var hand_before: int = _presenter.snapshot().view.hand.size()
	_screen.pile_window(MINE).catcher_of(forest).clicked.emit()

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_eq(_presenter.snapshot().view.hand.size(), hand_before + 1, "The Forest is found.")
	assert_false(_screen.pile_window(MINE).is_open())


func test_find_nothing_finds_nothing() -> void:
	_open_searching()
	var hand_before: int = _presenter.snapshot().view.hand.size()

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ChooseCardsInLibraryDecision)
	assert_eq(_presenter.snapshot().view.hand.size(), hand_before)


func test_the_cursor_on_a_card_says_select_or_unselect() -> void:
	_open_searching()
	var forest: int = _search().candidate_ids[0]

	_screen.pile_window(MINE).card_hovered.emit(forest, true)
	assert_eq(_screen.info_panel().option_text(), "Select Forest")
	_screen.pile_window(MINE).card_hovered.emit(forest, false)
	_screen.pile_window(MINE).catcher_of(forest).clicked.emit()
	_screen.pile_window(MINE).card_hovered.emit(forest, true)

	assert_eq(_screen.info_panel().option_text(), "Unselect Forest")


func _search() -> ChooseCardsInLibraryDecision:
	return _presenter.snapshot().decision as ChooseCardsInLibraryDecision


## Opens the screen in the Hero's first main phase holding Seek, casts it, and lets it
## resolve to its search.
func _open_searching() -> void:
	var deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.free_seek(), Scenario.basic_land("Forest"),
		Scenario.mana_land("Grove", MmMana.Type.GREEN, 1), Scenario.basic_land("Forest")])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		if Scenario.names(engine, engine.hero().hand).has("Seek"):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
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
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == "Seek":
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			break
	for attempt: int in 10:
		if _presenter.snapshot().decision is ChooseCardsInLibraryDecision:
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("Seek's search was never asked.")
