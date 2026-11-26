extends GutTest
## An ability that works from the graveyard on the Encounter Screen (engine ADR 0094), clicked
## as flashback is (game ADR 0049): the Hero's graveyard pile glows purple while a card in it
## has an ability to activate, and a click on the card in the Graveyard window activates it.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const SCREEN: Vector2 = Vector2(1920, 1080)
const MINE: String = "hero_graveyard"

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_the_pile_glows_purple_and_its_window_activates_the_ability() -> void:
	_open_with_skeleton_in_graveyard()
	var skeleton: int = _in_graveyard("Skeleton")

	assert_eq(_screen.pile_glow(MINE), [DecisionClicks.color_of(DecisionClicks.Kind.ABILITY)] as Array[Color],
		"Purple: an ability to activate.")
	assert_false(_screen.pile_window(MINE).is_open(), "Passing answers too, so it waits for a click.")
	_screen.pile_catcher(MINE).clicked.emit()
	var window: PileWindow = _screen.pile_window(MINE)
	assert_true(window.is_open())
	assert_not_null(window.catcher_of(skeleton), "The card takes the click.")
	_presenter.is_hold_key_down = true  # So the ability stays on the stack to be seen.
	window.catcher_of(skeleton).clicked.emit()
	_presenter.wait_until_idle()

	var stack: Array[MmObjectView] = _presenter.snapshot().view.stack
	assert_eq(stack.size(), 1, "Its ability is on the stack.")


## The Hero's deck cycles Skeleton, a 0/0 costing {0} with "{0}: Return this card from your
## graveyard to your hand", which dies as it enters; the Hero casts one in their main phase
## and has priority with it in their graveyard.
func _open_with_skeleton_in_graveyard() -> void:
	var skeleton: MmCardDefinition = Scenario.creature("Skeleton", 0, 0, [Scenario.back_from_the_graveyard(Scenario.mana_cost(0))])
	var chosen: MmEncounterSetup = Scenario.setup_with(Scenario.cycled([skeleton]), Scenario.cycled([]),
		MmEncounterSetup.StartingPlayerRule.HERO_STARTS, 1)
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
	_cast("Skeleton")
	assert_ne(_in_graveyard("Skeleton"), -1, "Skeleton died as it entered.")


## Casts the card named [param card_name] from the hand and lets it resolve.
func _cast(card_name: String) -> void:
	var snapshot: EncounterSnapshot = _presenter.snapshot()
	var priority: PriorityDecision = snapshot.decision as PriorityDecision
	for index: int in priority.actions.size():
		var cast: CastSpellAction = priority.actions[index] as CastSpellAction
		if cast != null and EncounterSnapshot.name_in(snapshot.view, cast.object_id) == card_name:
			assert_eq(_presenter.answer(index), "")
			_presenter.wait_until_idle()
			while not _presenter.snapshot().view.stack.is_empty():
				_presenter.pass_priority()
				_presenter.wait_until_idle()
			return
	fail_test("No cast of %s." % card_name)


func _in_graveyard(card_name: String) -> int:
	for seen: MmObjectView in _presenter.snapshot().view.graveyards[HERO]:
		if seen.name == card_name:
			return seen.id
	return -1
