extends GutTest
## The Encounter Screen draws its Backdrop once, behind everything, under a dim layer that
## keeps the board readable over any picture (ADR 0035).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_screen_shows_the_plain_backdrop_until_told_otherwise() -> void:
	_open()

	assert_eq(_screen.backdrop_name(), "plain")
	assert_null(_screen.backdrop())
	assert_null(_screen.backdrop_dimmer(), "Nothing dims the slate.")
	assert_eq((_screen.get_child(0) as ColorRect).color, Backdrops.SLATE)


func test_a_backdrop_fills_the_screen_behind_everything_else() -> void:
	_open()

	_screen.show_backdrop("red")

	var backdrop: Control = _screen.backdrop()
	assert_eq(_screen.backdrop_name(), "red")
	assert_eq(backdrop.get_global_rect(), Rect2(Vector2.ZERO, SCREEN))
	assert_eq(backdrop.get_index(), 1, "Only the slate is behind it.")
	for region: String in ["sidebar", "battlefield", "hero_hand", "piles"]:
		assert_true(backdrop.get_global_rect().encloses(EncounterLayout.regions(SCREEN)[region]), region)


func test_the_dim_layer_lies_just_over_the_backdrop_at_one_strength() -> void:
	_open()

	_screen.show_backdrop("white")

	var dimmer: ColorRect = _screen.backdrop_dimmer()
	assert_eq(dimmer.get_index(), _screen.backdrop().get_index() + 1)
	assert_eq(dimmer.get_global_rect(), Rect2(Vector2.ZERO, SCREEN))
	assert_eq(dimmer.color, Color(Backdrops.SLATE, Backdrops.DIM))
	assert_almost_eq(Backdrops.DIM, 0.55, 0.001)


func test_a_redraw_leaves_the_backdrop_and_its_dim_layer_alone() -> void:
	_open()
	_screen.show_backdrop("green")
	var backdrop: Control = _screen.backdrop()
	var dimmer: ColorRect = _screen.backdrop_dimmer()

	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	_presenter.pass_priority()
	_presenter.wait_until_idle()

	assert_same(_screen.backdrop(), backdrop)
	assert_same(_screen.backdrop_dimmer(), dimmer)
	assert_true(is_instance_valid(backdrop))
	assert_eq(backdrop.get_index(), 1)


func test_the_backdrop_and_its_dim_layer_take_no_clicks() -> void:
	_open()

	_screen.show_backdrop("blue")

	assert_eq(_screen.backdrop().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_screen.backdrop_dimmer().mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_showing_another_backdrop_replaces_the_first_and_plain_takes_it_away() -> void:
	_open()
	_screen.show_backdrop("blue")
	var first: Control = _screen.backdrop()

	_screen.show_backdrop("black")

	assert_ne(_screen.backdrop(), first)
	assert_true(first.is_queued_for_deletion())
	assert_eq(_screen.backdrop().get_index(), 1)

	_screen.show_backdrop("plain")

	assert_null(_screen.backdrop())
	assert_null(_screen.backdrop_dimmer())


func _open() -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	var cards: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	_presenter = EncounterPresenter.new(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)), DefaultAnswerAgent.new())
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
