class_name EncounterPresenter
extends RefCounted
## The Encounter Presenter (game glossary, ADR 0021): the one object in the GUI that owns
## the engine and the Encounter Driver. It runs the Villain's Agent on a worker thread, a
## decision at a time, takes the Hero's answers, and after every change hands the Encounter
## Screen a snapshot. Nothing else in ui/ may mention the engine or the game state.
##
## While the Villain is thinking, the worker thread is changing the game, so nothing here
## reads the engine until it has finished: the snapshot is made first, and commands are
## refused.

## A snapshot is ready: the game changed, or the Villain began or stopped thinking.
signal changed(snapshot: EncounterSnapshot)

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const BUSY: String = "The Villain is thinking."
const NOT_PRIORITY: String = "You do not have priority."

## The steps auto-pass stops at. Change them with toggle_stop().
var stops: StepStops = StepStops.new()
## Whether the Hero's own spell or ability going on the stack leaves them with priority:
## the screen keeps this equal to whether the hold key is down.
var is_hold_key_down: bool = false

var _engine: MmEngine
var _driver: MmEncounterDriver
## Held so the Agent outlives the driver's use of it on the worker thread.
var _villain_agent: MmAgent
var _is_auto_passing: bool = true
var _task: int = -1
var _has_started: bool = false
var _snapshot: EncounterSnapshot = null
var _events_seen: int = 0
var _is_holding: bool = false
## The Hero's object last seen on top of the stack, so holding is decided once for each.
var _own_top_seen: int = -1


## An encounter from [param setup], with [param villain_agent] answering for the Villain
## and nobody for the Hero. Nothing runs until start().
func _init(setup: MmEncounterSetup, villain_agent: MmAgent) -> void:
	_engine = MmEngine.start(setup)
	_villain_agent = villain_agent
	_driver = MmEncounterDriver.new(_engine, {VILLAIN: villain_agent} as Dictionary[int, MmAgent])
	# One answer for each task, so the screen is told after every Villain decision (A238).
	_driver.decision_cap = 1


## Hands out the first snapshot and sets the Villain thinking if it is theirs to decide.
## Returns at once: the thinking happens on a worker thread.
func start() -> void:
	_has_started = true
	_advance()


## The latest snapshot.
func snapshot() -> EncounterSnapshot:
	return _snapshot


func is_villain_thinking() -> bool:
	return _task != -1


func is_auto_passing() -> bool:
	return _is_auto_passing


## Call every frame on the main thread: once the Villain has answered, carries on.
func poll() -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		_collect()


## Blocks until the Hero must decide or the encounter is over. For leaving the screen
## cleanly, and for tests.
func wait_until_idle() -> void:
	while _task != -1:
		_collect()


## Answers the Hero's Pending Decision. Returns "" when accepted, or the reason when the
## answer is illegal, in which case nothing changes.
func answer(hero_answer: Variant) -> String:
	if _task != -1:
		return BUSY
	if _engine.is_over() or _engine.pending_decision().player_id != HERO:
		return NOT_PRIORITY
	var error: String = _engine.submit(hero_answer)
	if error != "":
		return error
	_is_holding = false
	_advance()
	return ""


## Passes priority, if the Hero has it.
func pass_priority() -> String:
	if _task != -1:
		return BUSY
	var priority: PriorityDecision = null if _engine.is_over() else _engine.pending_decision() as PriorityDecision
	if priority == null or priority.player_id != HERO:
		return NOT_PRIORITY
	return answer(AutoPass.pass_index(priority))


## Undoes the Hero's most recent answer (ADR 0015).
func undo() -> String:
	return _rewind(_engine.undo)


## Abandons the spell or ability the Hero is casting (CR 728).
func cancel_cast() -> String:
	return _rewind(_engine.cancel_cast)


## The Hero concedes (CR 104.3a).
func concede() -> String:
	if _task != -1:
		return BUSY
	var error: String = _engine.concede(_engine.hero())
	if error == "":
		_advance()
	return error


## Turns auto-pass on or off. Turning it on passes at once if it would pass now.
func set_auto_passing(is_on: bool) -> void:
	_is_auto_passing = is_on
	_reconsider()


## Sets or clears the stop at [param step] of [param turn_player_id]'s turn. Clearing the
## stop the Hero is waiting at lets auto-pass carry on.
func toggle_stop(turn_player_id: int, step: MmTurn.Step) -> void:
	stops.toggle(turn_player_id, step)
	_reconsider()


func _rewind(rewind: Callable) -> String:
	if _task != -1:
		return BUSY
	var error: String = rewind.call()
	if error != "":
		return error
	_is_holding = false
	_own_top_seen = -1
	_advance()
	return ""


## Auto-pass or a stop changed: look at the pending decision again, unless the Villain is
## thinking, when the new setting simply applies from the next decision.
func _reconsider() -> void:
	if _has_started and _task == -1:
		_advance()


func _collect() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_advance()


## Carries on until the Hero must decide, the Villain must think, or the encounter is over.
func _advance() -> void:
	while not _engine.is_over():
		var decision: MmPendingDecision = _engine.pending_decision()
		if decision.player_id != HERO:
			# The snapshot comes first: once the task starts, the engine is the worker's.
			_emit()
			_task = WorkerThreadPool.add_task(_think)
			_snapshot.is_villain_thinking = true
			changed.emit(_snapshot)
			return
		if not _passes_for_hero(decision):
			break
		_engine.submit(AutoPass.pass_index(decision as PriorityDecision))
	_emit()
	changed.emit(_snapshot)


## Runs on the worker thread: one answer from the Villain's Agent.
func _think() -> void:
	_driver.run()


func _passes_for_hero(decision: MmPendingDecision) -> bool:
	if not (decision is PriorityDecision):
		return false
	var view: MmPlayerView = _engine.view_for(_engine.hero())
	if not AutoPass.is_own_object_on_top(view):
		_own_top_seen = -1
	elif view.stack.back().id != _own_top_seen:
		# The Hero's own spell or ability has just gone on top: they get priority back
		# only if the hold key is down right now. Letting go later changes nothing.
		_own_top_seen = view.stack.back().id
		_is_holding = is_hold_key_down
		if not _is_holding:
			return true
	if _is_holding:
		return false
	return _is_auto_passing and AutoPass.passes(decision, view, stops)


## Builds the snapshot from the engine. Only ever called while no task is running.
func _emit() -> void:
	var made: EncounterSnapshot = EncounterSnapshot.new()
	made.view = _engine.view_for(_engine.hero())
	made.can_undo = _engine.can_undo()
	made.is_holding_priority = _is_holding
	if not _engine.is_over() and _engine.pending_decision().player_id == HERO:
		made.decision = _engine.pending_decision()
	var entries: Array[MmEvent] = _engine.event_log()
	# ADR 0015: a rewind only shortens the log, so it hands out nothing and is never
	# animated; what happens afterwards is counted from the shorter log.
	if entries.size() > _events_seen:
		made.events = entries.slice(_events_seen)
	_events_seen = entries.size()
	for seen: MmObjectView in made.visible_objects():
		made.looks[seen.id] = CardLook.of_view(seen, _art_key(seen))
	_snapshot = made


## The art of the card [param seen] is, or for an ability, of the card it came from.
func _art_key(seen: MmObjectView) -> String:
	var card_id: int = seen.card_id if seen.card_id != MmGameObject.NO_CARD else seen.source_card_id
	var run_card: MmRunCard = _engine.run_card(card_id)
	if run_card == null or run_card.base == null:
		return ""
	return run_card.base.resource_path.get_file().get_basename()
