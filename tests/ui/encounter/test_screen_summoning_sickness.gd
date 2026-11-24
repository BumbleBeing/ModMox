extends GutTest
## Summoning sickness on the Encounter Screen: a creature that cannot attack or pay {T} yet
## is darkened a little on the board, with the Sickness Spiral turning over its art. One
## with haste is drawn as any other creature is.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SCREEN: Vector2 = Vector2(1920, 1080)

var _presenter: EncounterPresenter
var _screen: EncounterScreen


func after_each() -> void:
	# What a redraw replaced is freed at the end of the frame.
	await wait_process_frames(2)


func test_a_creature_cast_this_turn_is_darkened_a_little_under_its_sickness_spiral() -> void:
	_open()
	_cast("Bear")

	var bear: BattlefieldFace = _face("Bear")
	assert_not_null(bear.sickness_spiral())
	assert_almost_eq(bear.darkness(), BattlefieldFace.SICK_SHADE, 0.0001)
	assert_false(bear.is_darkened(), "It is not tapped.")
	assert_eq(bear.sickness_spiral().size.x, SicknessSpiral.side_in(BattlefieldFace.art_box(bear.card().size.y).size))


func test_a_creature_with_haste_cast_this_turn_shows_nothing_of_it() -> void:
	_open()
	_cast("Raider")

	assert_null(_face("Raider").sickness_spiral())
	assert_eq(_face("Raider").darkness(), 0.0)


func test_the_spiral_of_a_redrawn_board_is_on_the_frame_the_one_before_it_had_reached() -> void:
	_open()
	_cast("Bear")
	var before: SicknessSpiral = _face("Bear").sickness_spiral()
	before.show_at(1.0)

	_cast("Raider")

	var after: SicknessSpiral = _face("Bear").sickness_spiral()
	assert_ne(after, before, "The board was rebuilt.")
	assert_eq(after.frame(), SicknessSpiral.frame_at(Time.get_ticks_msec() / 1000.0), "It shows the game's clock, not its own.")


## Opens the screen with a free Bear and a free hasty Raider in hand, and plays to the Hero's
## first main phase.
func _open() -> void:
	var cards: Array[MmCardDefinition] = [
		Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0)),
		Scenario.creature("Raider", 2, 1, [HasteAbility.new()] as Array[MmAbility], Scenario.mana_cost(0)),
	]
	var deck: Array[MmCardDefinition] = []
	for index: int in 40:
		deck.append(cards[index % cards.size()])
	_screen = EncounterScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.set_process(false)
	_screen.size = SCREEN
	_presenter = EncounterPresenter.new(Scenario.setup_with(deck, Scenario.copies(Scenario.vanilla("Card"), 40)), DefaultAnswerAgent.new())
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
			break
	for attempt: int in 10:
		var now: EncounterSnapshot = _presenter.snapshot()
		if now.view.stack.is_empty() or not (now.decision is PriorityDecision):
			return
		_presenter.pass_priority()
		_presenter.wait_until_idle()


func _face(card_name: String) -> BattlefieldFace:
	for permanent: MmObjectView in _presenter.snapshot().view.battlefield:
		if permanent.name == card_name:
			return _screen.face_of(permanent.id) as BattlefieldFace
	return null
