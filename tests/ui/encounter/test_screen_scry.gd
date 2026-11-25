extends GutTest
## Scrying on the Encounter Screen (game ADR 0069's addendum). A scry opens the Surveil window
## as a surveil does, titled "Scry N", with the cards scried face up in a row, leftmost on top.
## A drag orders the row and a click selects a card, as for a surveil; "Bottom" flies the
## selected card out of the window onto the Hero's Library pile, whose count stays as it
## was, since the card never leaves the library. Only "Done" answers: the cards sent, in the
## order sent, each under everything, then the row. Seer is a 1/1 costing {0}, "When this
## creature enters, scry N."

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


func test_a_scry_opens_the_window_titled_scry_with_bottom_in_its_edge() -> void:
	_open_scrying(2)

	var window: SurveilWindow = _screen.surveil_window()
	assert_true(window.is_open(), "Opened by the scry itself.")
	assert_eq(window.title_text(), "Scry 2")
	assert_eq(window.entries(), _scry().card_ids, "Leftmost on top.")
	for object_id: int in _scry().card_ids:
		assert_eq(BorderEffects.glow_colors(window.face_of(object_id)), [GREEN] as Array[Color])
	assert_eq(window.graveyard_button().text, "Bottom")
	assert_true(window.graveyard_button().disabled, "Nothing is selected.")
	assert_eq(_screen.info_panel().prompt_text(),
		"Scry: put any of these on the bottom, and order the rest. The leftmost will be on top.")
	assert_eq(_screen.pass_button().shown_text(), "Done")


func test_scrying_one_card_says_so() -> void:
	_open_scrying(1)

	assert_eq(_screen.surveil_window().title_text(), "Scry 1")
	assert_eq(_screen.info_panel().prompt_text(), "Scry: put any of these on the bottom.")


func test_bottom_takes_the_selected_card_out_of_the_row_and_answers_nothing() -> void:
	_open_scrying(2)
	var first: int = _scry().card_ids[0]
	var second: int = _scry().card_ids[1]
	var library: int = _presenter.snapshot().view.library_sizes[HERO]
	var graveyard: int = _presenter.snapshot().view.graveyards[HERO].size()
	var window: SurveilWindow = _screen.surveil_window()
	window.card_clicked.emit(first)

	window.graveyard_button().pressed.emit()

	assert_eq(window.entries(), [second] as Array[int])
	assert_true(window.graveyard_button().disabled, "Nothing is selected now.")
	assert_true(_presenter.snapshot().decision is ScryDecision, "Nothing answered until Done.")
	assert_eq(_screen.pile_text("hero_library"), "Library (%d)" % library, "It is still in the library.")
	assert_eq(_screen.pile_text("hero_graveyard"), "Graveyard (%d)" % graveyard)


func test_a_card_sent_flies_from_the_window_to_the_library_pile_once() -> void:
	_open_scrying(2, FLIGHT)
	var first: int = _scry().card_ids[0]
	var window: SurveilWindow = _screen.surveil_window()
	window.card_clicked.emit(first)
	var from: Vector2 = window.face_of(first).get_global_rect().get_center() - _screen.global_position

	window.graveyard_button().pressed.emit()

	var card: FlightCard = _screen.flight_card_of(first)
	assert_not_null(card, "It flies.")
	assert_almost_eq(card.position, from, Vector2(1, 1), "From where it was in the window.")
	_advance(FLIGHT * 1.5)
	assert_null(_screen.flight_card_of(first), "Landed on the Library pile.")

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_eq(_screen.flight_layer().flying_ids(), [] as Array[int], "It does not fly a second time.")


func test_done_puts_the_cards_sent_on_the_bottom_the_last_deepest_and_the_row_on_top() -> void:
	_open_scrying(3)
	var cards: Array[int] = _scry().card_ids
	var window: SurveilWindow = _screen.surveil_window()
	window.card_clicked.emit(cards[0])
	window.graveyard_button().pressed.emit()
	window.card_clicked.emit(cards[2])
	window.graveyard_button().pressed.emit()

	_screen.pass_priority()
	_presenter.wait_until_idle()

	assert_false(_presenter.snapshot().decision is ScryDecision)
	var library: Array = _presenter.snapshot().view.libraries[HERO]
	assert_eq((library[0] as MmObjectView).id, cards[1], "The row, on top.")
	assert_eq((library[library.size() - 2] as MmObjectView).id, cards[0], "Known to the Hero, at the bottom.")
	assert_eq((library.back() as MmObjectView).id, cards[2], "The last sent is the deepest.")
	assert_false(_screen.surveil_window().is_open(), "Closed once answered.")


func test_undo_takes_back_the_last_card_sent() -> void:
	_open_scrying(2)
	var cards: Array[int] = _scry().card_ids
	var window: SurveilWindow = _screen.surveil_window()
	window.card_clicked.emit(cards[0])
	window.graveyard_button().pressed.emit()

	_screen.undo()

	assert_eq(window.entries(), cards, "The card is back in its place.")
	assert_true(_presenter.snapshot().decision is ScryDecision)


func _scry() -> ScryDecision:
	return _presenter.snapshot().decision as ScryDecision


func _advance(seconds: float) -> void:
	var frames: int = ceili(seconds / 0.01)
	for frame: int in frames:
		_screen.advance_motion(seconds / frames)
	_screen.advance_motion(0.000001)


## Opens the screen in the Hero's first main phase holding a Seer that scries
## [param amount], casts it, and lets its trigger resolve to its scry. Cards fly for
## [param flight_seconds].
func _open_scrying(amount: int, flight_seconds: float = 0.0) -> void:
	var deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.seer("Seer", amount), Scenario.basic_land("Forest"),
		Scenario.creature("Bear", 2, 2), Scenario.basic_land("Forest")])
	var chosen: MmEncounterSetup = null
	for encounter_seed: int in range(1, 400):
		var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([]), MmEncounterSetup.StartingPlayerRule.HERO_STARTS, encounter_seed)
		var engine: MmEngine = MmEngine.start(setup)
		Scenario.keep_all(engine)
		if Scenario.names(engine, engine.hero().hand).has("Seer"):
			chosen = setup
			break
	assert_not_null(chosen, "No seed gave the needed cards.")
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
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
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == "Seer":
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			break
	for attempt: int in 10:
		if _presenter.snapshot().decision is ScryDecision:
			_advance(FLIGHT * 2.0)
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()
	fail_test("Seer's scry was never asked.")
