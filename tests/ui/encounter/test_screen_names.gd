extends GutTest
## The Encounter Screen calls each player what the presenter's snapshots do: on their
## panel and wherever the end of the encounter names them.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_every_snapshot_carries_the_presenters_names() -> void:
	_open(PlayerNames.new("Jackson", "Mishra"))

	assert_eq(_presenter.snapshot().names.of(HERO), "Jackson")
	_presenter.answer(KeepOrMulliganDecision.Choice.KEEP)
	_presenter.wait_until_idle()
	assert_eq(_presenter.snapshot().names.of(VILLAIN), "Mishra", "The next one too.")


func test_the_panels_are_headed_with_the_players_names() -> void:
	_open(PlayerNames.new("Jackson", "Mishra"))

	assert_eq(_screen.player_panel(HERO).name_text(), "JACKSON")
	assert_eq(_screen.player_panel(VILLAIN).name_text(), "MISHRA")


func test_players_with_no_names_go_by_their_parts() -> void:
	_open(null)

	assert_eq(_screen.player_panel(HERO).name_text(), "HERO")
	assert_eq(_screen.player_panel(VILLAIN).name_text(), "VILLAIN")


func test_the_end_of_the_encounter_names_the_loser() -> void:
	_open(PlayerNames.new("Jackson", "Mishra"))

	_screen.press_key(KEY_ESCAPE)
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()
	_screen.pause_menu().button(PauseMenu.CONCEDE).pressed.emit()

	assert_eq(_screen.banner_text(), "Defeat\nJackson conceded.")


func _open(names: PlayerNames) -> void:
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = SCREEN
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	_presenter = EncounterPresenter.new(Scenario.setup_with(forests, forests), DefaultAnswerAgent.new())
	if names != null:
		_presenter.names = names
	_presenter.set_auto_passing(false)
	_screen.begin(_presenter)
	_presenter.wait_until_idle()
	if _presenter.snapshot().decision is ChoosePlayOrDrawDecision:
		_presenter.answer(ChoosePlayOrDrawDecision.Choice.PLAY)
		_presenter.wait_until_idle()
