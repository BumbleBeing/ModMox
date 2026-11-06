class_name MmEngine
extends RefCounted
## The rules engine's whole public interface for one encounter. Start it from an Encounter
## Setup, then answer each Pending Decision until none remains (ADR 0003).

## Tags mid-encounter saves (ADR 0010). Bump it whenever a change could make an existing
## decision log replay differently.
const VERSION: String = "0.2.0"

var _state: MmGameState
var _pregame: PregameProcedure
var _pending: MmPendingDecision = null
## Every accepted answer, in order. Plain data, so it can be saved (ADR 0010).
var _decision_log: Array = []


## Starts an encounter and runs it to the first decision.
static func start(setup: MmEncounterSetup) -> MmEngine:
	return MmEngine.new(setup)


## Starts an encounter and feeds it [param answers] in order, as when loading a save.
static func replay(setup: MmEncounterSetup, answers: Array) -> MmEngine:
	var engine: MmEngine = MmEngine.new(setup)
	for answer: Variant in answers:
		var error: String = engine.submit(answer)
		if error != "":
			push_error("Replay stopped: answer %s was rejected: %s" % [answer, error])
			break
	return engine


func _init(setup: MmEncounterSetup) -> void:
	var error: String = setup.validate()
	assert(error == "", "Invalid Encounter Setup: " + error)
	_state = MmGameState.new(setup)
	_pregame = PregameProcedure.new(_state, setup.starting_player_rule)
	_advance()


## The decision the engine is waiting on, or null if none.
func pending_decision() -> MmPendingDecision:
	return _pending


## Answers the pending decision. Returns "" when accepted. Returns the reason when the
## answer is illegal, in which case nothing changes and the same decision stays pending.
## The answer is a Variant because each kind of decision takes a different shape.
func submit(answer: Variant) -> String:
	if _pending == null:
		return "No decision is pending."
	var error: String = _pending.validate(answer)
	if error != "":
		return error
	var stored: Variant = (answer as Array).duplicate(true) if answer is Array else answer
	_decision_log.append(stored)
	var answered: MmPendingDecision = _pending
	_pending = null
	_pregame.apply_answer(answered, stored)
	_advance()
	return ""


## The player representing the human's character. For setup and presentation only.
func hero() -> MmPlayer:
	return _state.player(MmEncounterSetup.HERO_PLAYER_ID)


## The player representing the adversary. For setup and presentation only.
func villain() -> MmPlayer:
	return _state.player(MmEncounterSetup.VILLAIN_PLAYER_ID)


## What [param player] may legally see.
func view_for(player: MmPlayer) -> MmPlayerView:
	return MmPlayerView.build(_state, player.id)


## The full game state. Read-only: change it only by answering decisions.
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


func _advance() -> void:
	# Later (milestone 3): once the pregame is over, the turn structure takes over.
	_pending = _pregame.next_decision()
