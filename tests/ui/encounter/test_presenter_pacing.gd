extends GutTest
## Pacing in the Encounter Presenter: the Villain's next answer is held back until the Hero
## has had time to read what the last one did (A357 to A359), by a clock handed in from
## outside so that nothing here sleeps through a wait.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")
const SlowAgent := preload("res://tests/ui/encounter/support/slow_agent.gd")
const Rule := MmEncounterSetup.StartingPlayerRule
const ACTION: int = 500
const MANA: int = 270
const STEP: int = 100

var _now: int = 0
var _snapshots: Array[EncounterSnapshot] = []
## What the clock said when each of _snapshots was handed out.
var _times: Array[int] = []


func before_each() -> void:
	_now = 1000
	_snapshots.clear()
	_times.clear()


func test_a_presenter_waits_for_nothing_until_it_is_told_to() -> void:
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup(Rule.VILLAIN_CHOOSES), DefaultAnswerAgent.new())
	presenter.clock = _clock

	assert_eq(presenter.action_wait_msec, 0)
	assert_eq(presenter.mana_wait_msec, 0)
	presenter.start()
	for answer: int in 2:
		_let_the_villain_answer(presenter)
		var before: EncounterSnapshot = presenter.snapshot()
		presenter.poll()
		assert_ne(presenter.snapshot(), before, "Collected at once, with the clock standing still.")
	presenter.wait_until_idle()


func test_the_clock_is_the_real_one_unless_another_is_handed_in() -> void:
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup(), DefaultAnswerAgent.new())

	var before: int = Time.get_ticks_msec()
	var read: int = presenter.clock.call()

	assert_between(read, before, Time.get_ticks_msec())


func test_after_a_villain_action_the_next_answer_waits_for_the_action_wait() -> void:
	var presenter: EncounterPresenter = _paced(Scenario.setup(Rule.VILLAIN_CHOOSES), DefaultAnswerAgent.new())
	presenter.start()
	_let_the_villain_answer(presenter)
	presenter.poll()
	var shown: EncounterSnapshot = presenter.snapshot()
	assert_eq(Pacing.wait_for(shown.events, ACTION, MANA), ACTION, "The Villain chose who starts.")
	assert_true(shown.is_villain_thinking, "And is asked again at once.")

	_let_the_villain_answer(presenter)
	_now += ACTION - 1
	presenter.poll()
	assert_eq(presenter.snapshot(), shown, "A millisecond short, the answer is still held back.")
	assert_true(presenter.is_villain_thinking())
	assert_eq(presenter.answer(0), EncounterPresenter.BUSY, "And the engine is still the worker's.")
	_now += 1
	presenter.poll()

	assert_ne(presenter.snapshot(), shown)
	presenter.wait_until_idle()


func test_each_kind_of_snapshot_is_left_up_for_its_own_wait() -> void:
	var land: MmCardDefinition = Scenario.basic_land("Forest")
	var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(2))
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.copies(Scenario.vanilla("Card"), 40), Scenario.deck_of(land, 20, bear, 20))
	var presenter: EncounterPresenter = _paced(setup, AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy()))
	presenter.start()
	var seen: Dictionary[int, int] = {0: 0, MANA: 0, ACTION: 0}

	for step: int in 400:
		if presenter.snapshot().is_over() or (seen[0] > 0 and seen[MANA] > 0 and seen[ACTION] > 1):
			break
		if not presenter.is_villain_thinking():
			# The Hero's own answer is never waited after.
			presenter.answer(Scenario.default_answer(presenter.snapshot().decision))
			_expect_collected_after(presenter, 0)
			continue
		var wait: int = Pacing.wait_for(presenter.snapshot().events, ACTION, MANA)
		seen[wait] += 1
		_expect_collected_after(presenter, wait)

	assert_gt(seen[0], 0, "A pass that only moved the game on a step.")
	assert_gt(seen[MANA], 0, "A land tapped for mana.")
	assert_gt(seen[ACTION], 1, "A land played, a spell cast.")
	presenter.wait_until_idle()


func test_a_thought_longer_than_the_wait_is_collected_as_soon_as_it_ends() -> void:
	var agent: SlowAgent = SlowAgent.new()
	agent.delay_msec = 150
	var presenter: EncounterPresenter = _paced(Scenario.setup(Rule.VILLAIN_CHOOSES), agent)
	presenter.start()
	_let_the_villain_answer(presenter)
	presenter.poll()
	var shown: EncounterSnapshot = presenter.snapshot()

	_now += ACTION
	presenter.poll()
	assert_eq(presenter.snapshot(), shown, "The wait is over but the Villain has not answered yet.")
	_let_the_villain_answer(presenter)
	presenter.poll()

	assert_ne(presenter.snapshot(), shown, "Thinking time counted toward the wait.")
	presenter.wait_until_idle()


func test_the_first_villain_answer_after_the_heros_is_not_held_back() -> void:
	var presenter: EncounterPresenter = _paced(
			Scenario.setup_with(Scenario.copies(Scenario.free_shock("Zap", 2), 40), Scenario.copies(Scenario.vanilla("Card"), 40)),
			DefaultAnswerAgent.new())
	presenter.start()
	presenter.wait_until_idle()
	for attempt: int in 30:
		var priority: PriorityDecision = presenter.snapshot().decision as PriorityDecision
		if priority != null and Scenario.action_index(priority, func(action: MmAction) -> bool: return action is CastSpellAction) != -1:
			break
		presenter.answer(Scenario.default_answer(presenter.snapshot().decision))
		presenter.wait_until_idle()
	var cast: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	presenter.answer(Scenario.action_index(cast, func(action: MmAction) -> bool: return action is CastSpellAction))
	presenter.answer(0)
	presenter.wait_until_idle()
	assert_eq(Pacing.wait_for(presenter.snapshot().events, ACTION, MANA), ACTION,
			"The Villain's pass let the first spell resolve, which the next Villain answer would wait after.")
	cast = presenter.snapshot().decision as PriorityDecision
	presenter.answer(Scenario.action_index(cast, func(action: MmAction) -> bool: return action is CastSpellAction))

	assert_eq(presenter.answer(0), "", "The Hero chooses a target, and their spell is passed for them.")
	var shown: EncounterSnapshot = presenter.snapshot()
	assert_eq(Pacing.wait_for(shown.events, ACTION, MANA), ACTION, "What the Hero did would be worth a wait.")
	assert_true(shown.is_villain_thinking)
	_let_the_villain_answer(presenter)
	presenter.poll()

	assert_ne(presenter.snapshot(), shown, "The wait is only between two Villain answers (A359).")
	presenter.wait_until_idle()


func test_the_hero_is_asked_the_moment_the_villains_answer_is_collected() -> void:
	var presenter: EncounterPresenter = _paced(Scenario.setup(Rule.VILLAIN_CHOOSES), DefaultAnswerAgent.new())
	presenter.changed.connect(_remember)
	presenter.start()

	for step: int in 40:
		if presenter.snapshot().decision != null:
			break
		_expect_collected_after(presenter, Pacing.wait_for(presenter.snapshot().events, ACTION, MANA))

	var last: EncounterSnapshot = _snapshots.back()
	assert_not_null(last.decision, "The snapshot that shows the Villain's last answer already asks the Hero.")
	assert_eq(last, presenter.snapshot())
	assert_eq(presenter.answer(-1) == EncounterPresenter.BUSY, false, "And an answer is taken at once.")


func test_time_spent_paused_counts_toward_the_wait() -> void:
	var presenter: EncounterPresenter = _paced(Scenario.setup(Rule.VILLAIN_CHOOSES), DefaultAnswerAgent.new())
	presenter.start()
	_let_the_villain_answer(presenter)
	presenter.poll()
	var shown: EncounterSnapshot = presenter.snapshot()
	_let_the_villain_answer(presenter)

	presenter.set_paused(true)
	_now += ACTION
	presenter.poll()
	assert_eq(presenter.snapshot(), shown)
	presenter.set_paused(false)
	presenter.poll()

	assert_ne(presenter.snapshot(), shown, "Resuming adds no wait of its own (A368).")
	presenter.wait_until_idle()


func test_waiting_until_idle_and_conceding_do_not_wait() -> void:
	var presenter: EncounterPresenter = _paced(Scenario.setup(Rule.VILLAIN_CHOOSES), DefaultAnswerAgent.new())
	presenter.start()
	_let_the_villain_answer(presenter)
	presenter.poll()
	assert_true(presenter.is_villain_thinking())

	presenter.wait_until_idle()
	assert_not_null(presenter.snapshot().decision, "Leaving the screen never sits through a wait.")
	assert_false(presenter.is_villain_answer_ready(), "Nobody is thinking, so no answer is waiting.")

	var other: EncounterPresenter = _paced(Scenario.setup(Rule.VILLAIN_CHOOSES), DefaultAnswerAgent.new())
	other.start()
	_let_the_villain_answer(other)
	other.poll()
	assert_true(other.is_villain_thinking())
	assert_eq(other.concede(), "")
	assert_true(other.snapshot().is_over())


func test_a_snapshot_says_whether_it_came_from_a_rewind() -> void:
	var forest: MmCardDefinition = Scenario.basic_land("Forest")
	var presenter: EncounterPresenter = EncounterPresenter.new(
			Scenario.setup_with(Scenario.copies(forest, 40), Scenario.copies(forest, 40)), DefaultAnswerAgent.new())
	presenter.set_auto_passing(false)
	presenter.changed.connect(_remember)
	presenter.start()
	presenter.wait_until_idle()
	for attempt: int in 30:
		var priority: PriorityDecision = presenter.snapshot().decision as PriorityDecision
		if priority != null and Scenario.action_index(priority, func(action: MmAction) -> bool: return action is PlayLandAction) != -1:
			break
		presenter.answer(Scenario.default_answer(presenter.snapshot().decision))
		presenter.wait_until_idle()
	var play: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	presenter.answer(Scenario.action_index(play, func(action: MmAction) -> bool: return action is PlayLandAction))
	for snapshot: EncounterSnapshot in _snapshots:
		assert_false(snapshot.is_rewind)

	assert_eq(presenter.undo(), "")
	assert_true(presenter.snapshot().is_rewind, "An undo (A365).")

	presenter.set_auto_passing(false)
	assert_false(presenter.snapshot().is_rewind, "Looking again at the same decision is not a rewind.")
	presenter.answer(Scenario.action_index(play, func(action: MmAction) -> bool: return action is PlayLandAction))
	assert_false(presenter.snapshot().is_rewind, "Nor is what happens after one.")


func test_canceling_a_cast_is_a_rewind_too() -> void:
	var presenter: EncounterPresenter = EncounterPresenter.new(
			Scenario.setup_with(Scenario.copies(Scenario.free_shock("Zap", 2), 40), Scenario.copies(Scenario.vanilla("Card"), 40)),
			DefaultAnswerAgent.new())
	presenter.set_auto_passing(false)
	presenter.start()
	presenter.wait_until_idle()
	for attempt: int in 30:
		var priority: PriorityDecision = presenter.snapshot().decision as PriorityDecision
		if priority != null and Scenario.action_index(priority, func(action: MmAction) -> bool: return action is CastSpellAction) != -1:
			break
		presenter.answer(Scenario.default_answer(presenter.snapshot().decision))
		presenter.wait_until_idle()
	var cast: PriorityDecision = presenter.snapshot().decision as PriorityDecision
	presenter.answer(Scenario.action_index(cast, func(action: MmAction) -> bool: return action is CastSpellAction))
	assert_true(presenter.snapshot().decision is ChooseTargetDecision)
	assert_false(presenter.snapshot().is_rewind)

	assert_eq(presenter.cancel_cast(), "")

	assert_true(presenter.snapshot().is_rewind)


func test_a_presenter_holds_no_step_until_it_is_told_to() -> void:
	var presenter: EncounterPresenter = EncounterPresenter.new(Scenario.setup(), DefaultAnswerAgent.new())
	presenter.clock = _clock
	presenter.changed.connect(_remember)

	assert_eq(presenter.step_wait_msec, 0)
	presenter.start()
	presenter.wait_until_idle()

	for snapshot: EncounterSnapshot in _snapshots:
		assert_true(snapshot.is_villain_thinking or snapshot.decision != null or snapshot.is_over(), "The Hero is passed for at once.")


func test_a_step_the_hero_is_passed_through_is_shown_for_the_step_wait() -> void:
	var presenter: EncounterPresenter = _stepped()
	presenter.start()
	_play_until(presenter, _is_held)
	var held: EncounterSnapshot = presenter.snapshot()
	assert_true(_is_held.call(held), "A snapshot that asks nobody: the Hero will be passed for.")
	assert_true(Pacing.starts_step(held.events), "It shows a step starting.")
	assert_true(presenter.is_passing_for_hero())

	assert_eq(presenter.pass_priority(), EncounterPresenter.NOT_PRIORITY)
	assert_eq(presenter.answer(0), EncounterPresenter.NOT_PRIORITY)
	_now += STEP - 1
	presenter.poll()
	assert_eq(presenter.snapshot(), held, "A millisecond short, the step is still showing.")
	_now += 1
	presenter.poll()

	assert_ne(presenter.snapshot(), held)
	presenter.wait_until_idle()


func test_time_spent_paused_counts_toward_the_step_wait() -> void:
	var presenter: EncounterPresenter = _stepped()
	presenter.start()
	_play_until(presenter, _is_held)
	var held: EncounterSnapshot = presenter.snapshot()

	presenter.set_paused(true)
	_now += STEP
	presenter.poll()
	assert_eq(presenter.snapshot(), held)
	presenter.set_paused(false)
	presenter.poll()

	assert_ne(presenter.snapshot(), held)
	presenter.wait_until_idle()


func test_the_villains_answer_waits_out_a_step_that_has_just_started() -> void:
	var presenter: EncounterPresenter = _stepped()
	presenter.start()
	_play_until(presenter, func(snapshot: EncounterSnapshot) -> bool:
		return snapshot.is_villain_thinking and Pacing.starts_step(snapshot.events))
	var shown: EncounterSnapshot = presenter.snapshot()
	assert_true(shown.is_villain_thinking and Pacing.starts_step(shown.events))
	assert_eq(Pacing.wait_for(shown.events, 0, 0), 0, "Nothing else would hold the answer back.")

	_let_the_villain_answer(presenter)
	_now += STEP - 1
	presenter.poll()
	assert_eq(presenter.snapshot(), shown)
	_now += 1
	presenter.poll()

	assert_ne(presenter.snapshot(), shown)
	presenter.wait_until_idle()


func test_no_step_is_left_sooner_than_the_step_wait_after_it_was_first_shown() -> void:
	var presenter: EncounterPresenter = _stepped()
	presenter.start()

	_play_until(presenter, func(snapshot: EncounterSnapshot) -> bool: return snapshot.view.game_turn > 3)

	var steps_seen: int = 0
	var first_shown: int = 0
	for index: int in _snapshots.size():
		var view: MmPlayerView = _snapshots[index].view
		var before: MmPlayerView = _snapshots[index - 1].view if index > 0 else null
		if before != null and before.game_turn == view.game_turn and before.step == view.step:
			continue
		if before != null:
			assert_gte(_times[index] - first_shown, STEP, "Turn %d, step %d." % [before.game_turn, before.step])
		first_shown = _times[index]
		steps_seen += 1
	assert_gt(steps_seen, 20, "Three turns of steps went by.")
	presenter.wait_until_idle()


func test_changing_a_stop_while_a_step_is_shown_does_not_cut_it_short() -> void:
	var presenter: EncounterPresenter = _stepped()
	presenter.start()
	_play_until(presenter, _is_held)
	var view: MmPlayerView = presenter.snapshot().view

	presenter.toggle_stop(view.active_player_id, MmTurn.Step.UPKEEP)
	presenter.toggle_stop(view.active_player_id, MmTurn.Step.UPKEEP)

	assert_true(_is_held.call(presenter.snapshot()), "Still held: the stops are as they were.")
	assert_eq(presenter.snapshot().view.step, view.step)
	assert_eq(presenter.snapshot().view.game_turn, view.game_turn)
	presenter.wait_until_idle()


func test_waiting_until_idle_sits_through_no_step() -> void:
	var presenter: EncounterPresenter = _stepped()
	presenter.start()
	_play_until(presenter, _is_held)

	presenter.wait_until_idle()

	assert_false(presenter.is_passing_for_hero())
	assert_true(presenter.snapshot().decision != null or presenter.snapshot().is_over(), "The Hero is asked, with the clock standing still.")


func test_an_undo_is_taken_while_a_step_is_shown() -> void:
	var presenter: EncounterPresenter = _stepped()
	presenter.start()
	_play_until(presenter, func(snapshot: EncounterSnapshot) -> bool: return _is_held.call(snapshot) and snapshot.can_undo)
	if not presenter.snapshot().can_undo:
		pass_test("The Hero had nothing to undo in this game.")
		return

	assert_eq(presenter.undo(), "")

	assert_true(presenter.snapshot().is_rewind)
	presenter.wait_until_idle()


func _clock() -> int:
	return _now


func _remember(snapshot: EncounterSnapshot) -> void:
	_snapshots.append(snapshot)
	_times.append(_now)


## A snapshot that asks nobody anything while the encounter goes on: the Hero is about to be
## passed for.
func _is_held(snapshot: EncounterSnapshot) -> bool:
	return snapshot.decision == null and not snapshot.is_villain_thinking and not snapshot.is_over()


## A presenter that holds steps and nothing else, between two decks of lands, remembering
## its snapshots.
func _stepped() -> EncounterPresenter:
	var forest: MmCardDefinition = Scenario.basic_land("Forest")
	var presenter: EncounterPresenter = EncounterPresenter.new(
			Scenario.setup_with(Scenario.copies(forest, 40), Scenario.copies(forest, 40)), DefaultAnswerAgent.new())
	presenter.clock = _clock
	presenter.step_wait_msec = STEP
	presenter.changed.connect(_remember)
	return presenter


## Plays on, the Hero answering as a person would, never sooner than the step wait, until
## the snapshot is one [param is_there] accepts or the encounter is over.
func _play_until(presenter: EncounterPresenter, is_there: Callable) -> void:
	for turn: int in 2000:
		var snapshot: EncounterSnapshot = presenter.snapshot()
		if snapshot.is_over() or is_there.call(snapshot):
			return
		_now += STEP
		if snapshot.is_villain_thinking:
			_let_the_villain_answer(presenter)
			presenter.poll()
		elif snapshot.decision != null:
			presenter.answer(Scenario.default_answer(snapshot.decision))
		else:
			presenter.poll()
	fail_test("The encounter never got there.")


func _paced(setup: MmEncounterSetup, agent: MmAgent) -> EncounterPresenter:
	var presenter: EncounterPresenter = EncounterPresenter.new(setup, agent)
	presenter.clock = _clock
	presenter.action_wait_msec = ACTION
	presenter.mana_wait_msec = MANA
	return presenter


## Waits, in real time, for the thought in progress to end. Nothing is collected.
func _let_the_villain_answer(presenter: EncounterPresenter) -> void:
	for attempt: int in 2000:
		if presenter.is_villain_answer_ready():
			return
		OS.delay_msec(2)
	fail_test("The Villain never answered.")


## The Villain's answer is held back until [param wait] milliseconds have gone by on the
## clock, and collected then.
func _expect_collected_after(presenter: EncounterPresenter, wait: int) -> void:
	var shown: EncounterSnapshot = presenter.snapshot()
	_let_the_villain_answer(presenter)
	if wait > 0:
		_now += wait - 1
		presenter.poll()
		assert_eq(presenter.snapshot(), shown, "Held back for %d ms." % wait)
		_now += 1
	presenter.poll()
	assert_ne(presenter.snapshot(), shown, "Collected after %d ms." % wait)
