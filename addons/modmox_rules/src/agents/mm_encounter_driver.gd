class_name MmEncounterDriver
extends RefCounted
## Runs an encounter by asking each player's Agent for answers (glossary "Encounter
## Driver"). A player with no Agent is a human: the driver stops at their decisions and
## carries on after the game submits their answer and calls run() again.

## Why run() returned.
enum Status {
	## The encounter has ended.
	OVER,
	## A player with no Agent must decide.
	WAITING_FOR_HUMAN,
	## The stop condition was met.
	STOPPED,
	## decision_cap answers were given.
	CAPPED,
	## An Agent gave an illegal answer, which is a bug in that Agent.
	REJECTED,
	## A Simulation Copy could not go on (MmEngine.has_failed()).
	FAILED,
}

var engine: MmEngine
## How many answers one run() may give before it stops; 0 for no limit.
var decision_cap: int = 0
## Whether Agents are handed the deciding player's view. Simulations skip building views,
## since no player watches them.
var builds_views: bool = true
## Why the last REJECTED stop happened.
var rejection: String = ""

var _agents: Dictionary[int, MmAgent] = {}


## [param agents] maps player IDs to their Agents; a player missing from it is a human.
func _init(driven_engine: MmEngine, agents: Dictionary[int, MmAgent]) -> void:
	engine = driven_engine
	_agents = agents.duplicate()


## Answers decisions until the encounter ends or a human must decide.
func run() -> Status:
	return run_until(Callable())


## Like run(), but also stops, before answering, once [param stop] returns true for the
## engine.
func run_until(stop: Callable) -> Status:
	var answered: int = 0
	while true:
		if engine.has_failed():
			return Status.FAILED
		if engine.is_over():
			return Status.OVER
		if stop.is_valid() and stop.call(engine):
			return Status.STOPPED
		var decision: MmPendingDecision = engine.pending_decision()
		var agent: MmAgent = _agents.get(decision.player_id, null) as MmAgent
		if agent == null:
			return Status.WAITING_FOR_HUMAN
		if decision_cap > 0 and answered >= decision_cap:
			return Status.CAPPED
		var view: MmPlayerView = engine.view_for(engine.game_state().player(decision.player_id)) if builds_views else null
		var answer: Variant = agent.answer(decision, view, engine.simulation_source_for(decision.player_id))
		var error: String = engine.submit(answer)
		if error != "":
			rejection = "%s answered %s to %s: %s" % [agent.get_script().resource_path.get_file(), answer, decision.describe(), error]
			push_error(rejection)
			return Status.REJECTED
		answered += 1
	return Status.OVER
