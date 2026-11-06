class_name MmEngine
extends RefCounted
## The rules engine's whole public interface for one encounter. Start it from an Encounter
## Setup, then answer each Pending Decision until none remains (ADR 0003).
##
## Recent decisions can be undone back to the last undo barrier (ADR 0015). The engine
## keeps a checkpoint copy of itself at each barrier; undoing restores that copy and
## replays the decisions made since, minus the undone ones. Callers only ever see the
## result: after an undo, read the views again rather than animating anything.

## Tags mid-encounter saves (ADR 0010). Bump it whenever a change could make an existing
## decision log replay differently.
const VERSION: String = "0.9.0"
## The first entry of a concession in the decision log: ["concede", player ID]. No answer
## to a Pending Decision ever has this shape.
const CONCEDE: String = "concede"

## How an encounter ended, for the game around the engine.
enum Outcome { IN_PROGRESS, HERO_WON, VILLAIN_WON, DRAW }

var _state: MmGameState
var _pregame: PregameProcedure
var _turns: TurnProcedure
var _pregame_over: bool = false
var _pending: MmPendingDecision = null
## Every accepted answer, in order. Plain data, so it can be saved (ADR 0010). Undone
## answers are removed, so saves and replays never see them.
var _decision_log: Array = []
## Where in the decision log the cast in progress began, or -1.
var _cast_started_at: int = -1

var _checkpoint_state: MmGameState
var _checkpoint_pregame: PregameProcedure
var _checkpoint_turns: TurnProcedure
var _checkpoint_pregame_over: bool = false
var _checkpoint_pending: MmPendingDecision = null
var _checkpoint_log_size: int = 0
var _replaying: bool = false


## Starts an encounter and runs it to the first decision.
static func start(setup: MmEncounterSetup) -> MmEngine:
	return MmEngine.new(setup)


## Starts an encounter and feeds it [param answers] in order, as when loading a save.
static func replay(setup: MmEncounterSetup, answers: Array) -> MmEngine:
	var engine: MmEngine = MmEngine.new(setup)
	for answer: Variant in answers:
		var error: String = engine._replay_entry(answer)
		if error != "":
			push_error("Replay stopped: answer %s was rejected: %s" % [answer, error])
			break
	return engine


func _init(setup: MmEncounterSetup) -> void:
	var error: String = setup.validate()
	assert(error == "", "Invalid Encounter Setup: " + error)
	_state = MmGameState.new(setup)
	_pregame = PregameProcedure.new(_state, setup.starting_player_rule)
	_turns = TurnProcedure.new(_state)
	_advance()
	_take_checkpoint()


## The decision the engine is waiting on, or null if none.
func pending_decision() -> MmPendingDecision:
	return _pending


## Answers the pending decision. Returns "" when accepted. Returns the reason when the
## answer is illegal, in which case nothing changes and the same decision stays pending.
## The answer is a Variant because each kind of decision takes a different shape.
func submit(answer: Variant) -> String:
	if is_over():
		return "The encounter is over."
	if _pending == null:
		return "No decision is pending."
	var error: String = _pending.validate(answer)
	if error != "":
		return error
	var answered: MmPendingDecision = _pending
	var events_before: int = _state.event_log.size()
	var was_casting: bool = is_casting()
	var stored: Variant = (answer as Array).duplicate(true) if answer is Array else answer
	_decision_log.append(stored)
	_pending = null
	if _pregame_over:
		_turns.apply_answer(answered, stored)
	else:
		_pregame.apply_answer(answered, stored)
	_advance()
	if not was_casting and is_casting():
		_cast_started_at = _decision_log.size() - 1
	if _turns.needs_rewind():
		# CR 728: a cast that can no longer be finished is rewound as if it never began.
		_undo_to(_cast_started_at)
		return ""
	if not is_casting():
		_cast_started_at = -1
	if not _replaying and _is_undo_barrier(answered, events_before):
		_take_checkpoint()
	return ""


## CR 104.3a: [param player] concedes, at any time, even while the other player is
## deciding. Conceding is final. Returns "" when done, or why it cannot happen.
func concede(player: MmPlayer) -> String:
	if is_over():
		return "The encounter is over."
	_decision_log.append([CONCEDE, player.id])
	_state.perform(PlayerLostEvent.new(player.id, MmPlayer.LossReason.CONCEDED))
	_state.perform(EncounterEndedEvent.new(_state.opponent_of(player.id).id))
	_pending = null
	_cast_started_at = -1
	if not _replaying:
		_take_checkpoint()
	return ""


## Whether the encounter has ended. Then nothing more can be answered or undone.
func is_over() -> bool:
	return _state.is_over


## How the encounter ended so far. Names the Hero and Villain, so it is for presentation
## and the game around the engine only (ADR 0005).
func outcome() -> Outcome:
	if not _state.is_over:
		return Outcome.IN_PROGRESS
	if _state.winner_id == MmGameState.NO_PLAYER:
		return Outcome.DRAW
	return Outcome.HERO_WON if _state.winner_id == MmEncounterSetup.HERO_PLAYER_ID else Outcome.VILLAIN_WON


## Whether there is a decision that can be undone.
func can_undo() -> bool:
	return not is_over() and _decision_log.size() > _checkpoint_log_size


## Undoes the most recent decision. Returns "" when done, or why it cannot be undone.
func undo() -> String:
	if is_over():
		return "The encounter is over."
	if not can_undo():
		return "Nothing can be undone past this point."
	_undo_to(_decision_log.size() - 1)
	return ""


## Whether a spell is being cast or an ability activated: its targets or payment are
## still being chosen.
func is_casting() -> bool:
	return _pregame_over and _turns.is_casting()


## Abandons the spell or ability being cast, putting everything back as it was before it
## began, including any lands tapped for it (CR 728).
func cancel_cast() -> String:
	if not is_casting():
		return "Nothing is being cast."
	_undo_to(_cast_started_at)
	return ""


## The player representing the human's character. For setup and presentation only.
func hero() -> MmPlayer:
	return _state.player(MmEncounterSetup.HERO_PLAYER_ID)


## The player representing the adversary. For setup and presentation only.
func villain() -> MmPlayer:
	return _state.player(MmEncounterSetup.VILLAIN_PLAYER_ID)


## What [param player] may legally see.
func view_for(player: MmPlayer) -> MmPlayerView:
	var priority_player_id: int = _pending.player_id if _pending is PriorityDecision else MmGameState.NO_PLAYER
	return MmPlayerView.build(_state, player.id, priority_player_id)


## The full game state. Read-only: change it only by answering decisions. An undo
## replaces it, so fetch it again afterwards rather than keeping it.
func game_state() -> MmGameState:
	return _state


## A copy of every event performed so far, in order.
func event_log() -> Array[MmEvent]:
	return _state.event_log.duplicate()


## A copy of every accepted answer so far, in order.
func decision_log() -> Array:
	return _decision_log.duplicate(true)


## A hash of the game state and the pending decision, equal exactly when they match.
func fingerprint() -> String:
	var pending: String = "none" if _pending == null else _pending.describe()
	return (_state.fingerprint() + "\npending " + pending).sha256_text()


## Feeds one decision log entry back in, as when loading a save: an answer, or a concession.
func _replay_entry(entry: Variant) -> String:
	if entry is Array and (entry as Array).size() == 2 and (entry as Array)[0] is String and (entry as Array)[0] == CONCEDE:
		return concede(_state.player((entry as Array)[1] as int))
	return submit(entry)


## Runs the engine until the next decision: the pregame first, then turns.
func _advance() -> void:
	if not _pregame_over:
		_pending = _pregame.next_decision()
		_pregame_over = _pending == null
	if _pregame_over:
		_pending = _turns.next_decision()


## ADR 0015: a point that cannot fairly be undone past. Hidden information was revealed or
## randomness used (a draw, a shuffle), something left the stack, or the other player now
## has a decision.
func _is_undo_barrier(answered: MmPendingDecision, events_before: int) -> bool:
	if _pending == null or _pending.player_id != answered.player_id:
		return true
	for index: int in range(events_before, _state.event_log.size()):
		var event: MmEvent = _state.event_log[index]
		if event is ShuffleEvent or event is AbilityLeftStackEvent:
			return true
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.from_zone_kind in [MmZone.Kind.LIBRARY, MmZone.Kind.STACK]:
			return true
	return false


func _take_checkpoint() -> void:
	_checkpoint_state = _state.duplicate_state()
	_checkpoint_pregame = _pregame.copy_for(_checkpoint_state)
	_checkpoint_turns = _turns.copy_for(_checkpoint_state)
	_checkpoint_pregame_over = _pregame_over
	_checkpoint_pending = _pending  # Decisions never change, so sharing one is safe.
	_checkpoint_log_size = _decision_log.size()


## Restores the checkpoint and replays the decisions after it, up to [param log_size].
func _undo_to(log_size: int) -> void:
	assert(log_size >= _checkpoint_log_size, "Cannot undo past the last undo barrier.")
	var to_replay: Array = _decision_log.slice(_checkpoint_log_size, log_size)
	_state = _checkpoint_state.duplicate_state()
	_pregame = _checkpoint_pregame.copy_for(_state)
	_turns = _checkpoint_turns.copy_for(_state)
	_pregame_over = _checkpoint_pregame_over
	_pending = _checkpoint_pending
	_decision_log.resize(_checkpoint_log_size)
	_cast_started_at = -1
	_replaying = true
	for answer: Variant in to_replay:
		var error: String = submit(answer)
		assert(error == "", "Replaying an undo window failed: " + error)
	_replaying = false
