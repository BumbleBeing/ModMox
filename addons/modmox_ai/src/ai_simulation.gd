class_name AiSimulation
extends RefCounted
## One-step simulation (A181) and rollouts (A190): play a choice out on a Simulation Copy
## with CHEAP Agents answering for both players, then score the result with the Board
## Evaluator.

## A copy that could not go on scores below any real outcome.
const FAILED: int = -2 * AiBoardEvaluator.WIN
## The most answers one play-out may give, so a runaway copy always stops.
const DECISION_CAP: int = 400
## A rollout plays the rest of the current Game Turn and then this many more (A190).
const ROLLOUT_EXTRA_TURNS: int = 1
## The most answers one rollout may give.
const ROLLOUT_DECISION_CAP: int = 1500


## Submits [param answer] on [param copy], plays on until the choice has played out, and
## returns [param player_id]'s score of the result.
static func score_answer(copy: MmEngine, answer: Variant, player_id: int, profile: AiProfile) -> int:
	if copy.submit(answer) != "":
		return FAILED
	return score_after_play_out(copy, player_id, profile)


## Plays [param copy] on to the end of the current choice and scores it.
static func score_after_play_out(copy: MmEngine, player_id: int, profile: AiProfile) -> int:
	play_out(copy, player_id, profile)
	if copy.has_failed():
		return FAILED
	return AiBoardEvaluator.score(copy.game_state(), player_id, profile)


## Plays [param copy] on with CHEAP Agents until whatever was just chosen has played out:
## the stack is empty and [param player_id] has priority again, or the step ends. In
## combat it plays on until combat is over, so the damage counts. [param profile] answers
## for [param player_id]; the other player gets the default AI Profile (A180).
static func play_out(copy: MmEngine, player_id: int, profile: AiProfile) -> void:
	var agents: Dictionary[int, MmAgent] = {}
	agents[player_id] = AiAgent.new(profile, AiAgent.Mode.CHEAP)
	agents[1 - player_id] = AiAgent.new(AiProfile.new(), AiAgent.Mode.CHEAP)
	var driver: MmEncounterDriver = MmEncounterDriver.new(copy, agents)
	driver.builds_views = false
	driver.decision_cap = DECISION_CAP
	var start: MmGameState = copy.game_state()
	var start_turn: int = start.game_turn
	var start_step: MmTurn.Step = start.step
	var in_combat: bool = AiTiming.COMBAT_STEPS.has(start_step)
	driver.run_until(func(running: MmEngine) -> bool:
		var state: MmGameState = running.game_state()
		if state.game_turn != start_turn:
			return true
		if in_combat:
			return not AiTiming.COMBAT_STEPS.has(state.step)
		if state.step != start_step:
			return true
		var pending: MmPendingDecision = running.pending_decision()
		return pending is PriorityDecision and pending.player_id == player_id \
			and state.stack.is_empty() and state.pending_triggers.is_empty())


## Submits [param answer] on [param copy], rolls it out, and returns [param player_id]'s
## score of the result.
static func score_rollout(copy: MmEngine, answer: Variant, player_id: int, profile: AiProfile) -> int:
	if copy.submit(answer) != "":
		return FAILED
	roll_out(copy, player_id, profile)
	if copy.has_failed():
		return FAILED
	return AiBoardEvaluator.score(copy.game_state(), player_id, profile)


## Plays [param copy] on with CHEAP Agents through the rest of the current Game Turn and
## the whole next one, or until the game ends (A190). Whose turn it is does not matter.
## [param profile] answers for [param player_id]; the other player gets the default AI
## Profile (A180, A201).
static func roll_out(copy: MmEngine, player_id: int, profile: AiProfile) -> void:
	var agents: Dictionary[int, MmAgent] = {}
	agents[player_id] = AiAgent.new(profile, AiAgent.Mode.CHEAP)
	agents[1 - player_id] = AiAgent.new(AiProfile.new(), AiAgent.Mode.CHEAP)
	var driver: MmEncounterDriver = MmEncounterDriver.new(copy, agents)
	driver.builds_views = false
	driver.decision_cap = ROLLOUT_DECISION_CAP
	var last_turn: int = copy.game_state().game_turn + ROLLOUT_EXTRA_TURNS
	driver.run_until(func(running: MmEngine) -> bool:
		return running.game_state().game_turn > last_turn)
