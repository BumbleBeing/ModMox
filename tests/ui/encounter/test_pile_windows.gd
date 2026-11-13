extends GutTest
## Which pile windows the game opens to answer a target, and closes again afterward (A443,
## A450).

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const MINE: String = "hero_graveyard"
const NONE: Array[String] = []

var _view: MmPlayerView


func before_each() -> void:
	_view = MmPlayerView.new()
	_view.viewer_id = HERO
	var dead: MmObjectView = MmObjectView.new()
	dead.id = 30
	var permanent: MmObjectView = MmObjectView.new()
	permanent.id = 5
	_view.graveyards = {HERO: [dead], VILLAIN: []}
	_view.battlefield = [permanent]


func test_a_target_only_in_a_graveyard_opens_its_window() -> void:
	var windows: PileWindows = PileWindows.new()
	var decision: ChooseTargetDecision = _target([30])

	windows.follow(decision, DecisionClicks.of(decision, _view), NONE)

	assert_eq(windows.to_open, [MINE] as Array[String])
	assert_eq(windows.to_close, NONE)
	assert_true(windows.closes_with_target(MINE))


func test_it_closes_once_the_target_is_chosen_or_the_cast_is_canceled() -> void:
	var windows: PileWindows = PileWindows.new()
	var decision: ChooseTargetDecision = _target([30])
	windows.follow(decision, DecisionClicks.of(decision, _view), NONE)

	windows.follow(null, DecisionClicks.of(null, _view), [MINE] as Array[String])

	assert_eq(windows.to_close, [MINE] as Array[String])
	assert_eq(windows.to_open, NONE)
	windows.follow(null, DecisionClicks.of(null, _view), NONE)
	assert_eq(windows.to_close, NONE, "Once.")


func test_a_window_the_hero_already_had_open_stays_open() -> void:
	var windows: PileWindows = PileWindows.new()
	var decision: ChooseTargetDecision = _target([30])

	windows.follow(decision, DecisionClicks.of(decision, _view), [MINE] as Array[String])
	assert_eq(windows.to_open, NONE)
	windows.follow(null, DecisionClicks.of(null, _view), [MINE] as Array[String])

	assert_eq(windows.to_close, NONE)


func test_a_window_the_hero_closes_while_asked_is_not_opened_again() -> void:
	var windows: PileWindows = PileWindows.new()
	var decision: ChooseTargetDecision = _target([30])
	var clicks: DecisionClicks = DecisionClicks.of(decision, _view)
	windows.follow(decision, clicks, NONE)
	windows.toggled(MINE, false, clicks)

	windows.follow(decision, clicks, NONE)

	assert_eq(windows.to_open, NONE, "The same decision, shown again.")
	var next: ChooseTargetDecision = _target([30])
	windows.follow(next, DecisionClicks.of(next, _view), NONE)
	assert_eq(windows.to_open, [MINE] as Array[String], "A new decision asks afresh.")


func test_with_a_choice_on_the_board_too_nothing_opens_until_the_pile_is_clicked() -> void:
	var windows: PileWindows = PileWindows.new()
	var decision: ChooseTargetDecision = _target([5, 30])
	var clicks: DecisionClicks = DecisionClicks.of(decision, _view)

	windows.follow(decision, clicks, NONE)
	assert_eq(windows.to_open, NONE)

	windows.toggled(MINE, true, clicks)
	windows.follow(null, DecisionClicks.of(null, _view), [MINE] as Array[String])
	assert_eq(windows.to_close, [MINE] as Array[String], "Opened to answer, so it closes with the answer.")


func test_a_pile_opened_while_nothing_in_it_answers_is_the_heros_own() -> void:
	var windows: PileWindows = PileWindows.new()
	var decision: ChooseTargetDecision = _target([5])
	var clicks: DecisionClicks = DecisionClicks.of(decision, _view)

	windows.toggled(MINE, true, clicks)
	windows.follow(null, DecisionClicks.of(null, _view), [MINE] as Array[String])

	assert_eq(windows.to_close, NONE)
	assert_false(windows.closes_with_target(MINE))


func _target(ids: Array[int]) -> ChooseTargetDecision:
	var candidates: Array[MmReference] = []
	for id: int in ids:
		candidates.append(MmReference.to_object(id))
	return ChooseTargetDecision.new(HERO, 20, 0, candidates)
