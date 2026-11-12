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


## Submits [param answer] on [param copy], [param repeats] times if it is a Repeat Plan,
## plays on until the choice has played out, or through the Game Turn with
## [param through_turn], and returns [param player_id]'s score of the result.
static func score_answer(copy: MmEngine, answer: Variant, player_id: int, profile: AiProfile,
		repeats: int = 1, through_turn: bool = false) -> int:
	if submit_plan(copy, answer, repeats, player_id, profile) == 0:
		return FAILED
	return score_after_play_out(copy, player_id, profile, through_turn)


## Plays [param copy] on to the end of the current choice and scores it.
static func score_after_play_out(copy: MmEngine, player_id: int, profile: AiProfile, through_turn: bool = false) -> int:
	play_out(copy, player_id, profile, through_turn)
	if copy.has_failed():
		return FAILED
	return AiBoardEvaluator.score(copy.game_state(), player_id, profile)


## Submits [param answer] on [param copy]. With more than one of [param repeats] it is a
## Repeat Plan (glossary): the same ability is activated again, each time once the last
## activation has resolved and [param player_id] has priority, for as long as the engine
## still offers it in the same step. Returns how many times the answer was submitted; 0 if
## the first was rejected.
static func submit_plan(copy: MmEngine, answer: Variant, repeats: int, player_id: int, profile: AiProfile) -> int:
	var first: PriorityDecision = copy.pending_decision() as PriorityDecision
	var activate: ActivateAbilityAction = null
	if repeats > 1 and first != null and answer is int:
		activate = first.actions[answer as int] as ActivateAbilityAction
	if copy.submit(answer) != "":
		return 0
	if activate == null:
		return 1
	var step: MmTurn.Step = copy.game_state().step
	var game_turn: int = copy.game_state().game_turn
	var made: int = 1
	while made < repeats:
		_play_until_resolved(copy, player_id, profile, activate)
		var state: MmGameState = copy.game_state()
		var pending: PriorityDecision = copy.pending_decision() as PriorityDecision
		if copy.has_failed() or copy.is_over() or pending == null or pending.player_id != player_id \
				or state.step != step or state.game_turn != game_turn:
			break
		var again: int = _index_of(pending, activate)
		if again == -1 or copy.submit(again) != "":
			break
		made += 1
	return made


## Plays [param copy] on with CHEAP Agents until none of [param activate]'s activations is
## left on the stack and [param player_id] has priority, or the step ends.
static func _play_until_resolved(copy: MmEngine, player_id: int, profile: AiProfile, activate: ActivateAbilityAction) -> void:
	var driver: MmEncounterDriver = _cheap_driver(copy, player_id, profile, DECISION_CAP)
	var start: MmGameState = copy.game_state()
	var start_turn: int = start.game_turn
	var start_step: MmTurn.Step = start.step
	driver.run_until(func(running: MmEngine) -> bool:
		var state: MmGameState = running.game_state()
		if state.game_turn != start_turn or state.step != start_step:
			return true
		var pending: MmPendingDecision = running.pending_decision()
		if not (pending is PriorityDecision and pending.player_id == player_id):
			return false
		for item: MmGameObject in state.stack.objects():
			if item.ability != null and item.source_object_id == activate.object_id and item.controller_id == player_id:
				return false
		return true)


static func _index_of(decision: PriorityDecision, activate: ActivateAbilityAction) -> int:
	for index: int in decision.actions.size():
		var other: ActivateAbilityAction = decision.actions[index] as ActivateAbilityAction
		if other != null and other.object_id == activate.object_id and other.ability_index == activate.ability_index:
			return index
	return -1


## CHEAP Agents for both players of [param copy]: [param profile] answers for
## [param player_id]; the other player gets the default AI Profile (A180).
static func _cheap_driver(copy: MmEngine, player_id: int, profile: AiProfile, cap: int) -> MmEncounterDriver:
	var agents: Dictionary[int, MmAgent] = {}
	agents[player_id] = AiAgent.new(profile, AiAgent.Mode.CHEAP)
	agents[1 - player_id] = AiAgent.new(AiProfile.new(), AiAgent.Mode.CHEAP)
	var driver: MmEncounterDriver = MmEncounterDriver.new(copy, agents)
	driver.builds_views = false
	driver.decision_cap = cap
	return driver


## Plays [param copy] on with CHEAP Agents until whatever was just chosen has played out:
## the stack is empty and [param player_id] has priority again, or the step ends. In
## combat it plays on until combat is over, so the damage counts. With
## [param through_turn] it plays on until the Game Turn is over instead, so everything that
## lasts until end of turn has worn off. [param profile] answers for [param player_id]; the
## other player gets the default AI Profile (A180).
static func play_out(copy: MmEngine, player_id: int, profile: AiProfile, through_turn: bool = false) -> void:
	var driver: MmEncounterDriver = _cheap_driver(copy, player_id, profile, DECISION_CAP)
	var start: MmGameState = copy.game_state()
	var start_turn: int = start.game_turn
	var start_step: MmTurn.Step = start.step
	var in_combat: bool = AiTiming.COMBAT_STEPS.has(start_step)
	driver.run_until(func(running: MmEngine) -> bool:
		var state: MmGameState = running.game_state()
		if state.game_turn != start_turn:
			return true
		if through_turn:
			return false
		if in_combat:
			return not AiTiming.COMBAT_STEPS.has(state.step)
		if state.step != start_step:
			return true
		var pending: MmPendingDecision = running.pending_decision()
		return pending is PriorityDecision and pending.player_id == player_id \
			and state.stack.is_empty() and state.pending_triggers.is_empty())


## Submits [param answer] on [param copy], [param repeats] times if it is a Repeat Plan,
## rolls it out, and returns [param player_id]'s score of the result. The horizon is counted
## from the decision, before the answer is submitted, so a pass that ends the Game Turn is
## played no further than any other answer (A190, A193).
static func score_rollout(copy: MmEngine, answer: Variant, player_id: int, profile: AiProfile, repeats: int = 1) -> int:
	var last_turn: int = copy.game_state().game_turn + ROLLOUT_EXTRA_TURNS
	if submit_plan(copy, answer, repeats, player_id, profile) == 0:
		return FAILED
	_roll_out_through(copy, last_turn, player_id, profile)
	if copy.has_failed():
		return FAILED
	return AiBoardEvaluator.score(copy.game_state(), player_id, profile)


## Plays [param copy] on with CHEAP Agents through the rest of the current Game Turn and
## the whole next one, or until the game ends (A190). Whose turn it is does not matter.
## [param profile] answers for [param player_id]; the other player gets the default AI
## Profile (A180, A201).
static func roll_out(copy: MmEngine, player_id: int, profile: AiProfile) -> void:
	_roll_out_through(copy, copy.game_state().game_turn + ROLLOUT_EXTRA_TURNS, player_id, profile)


static func _roll_out_through(copy: MmEngine, last_turn: int, player_id: int, profile: AiProfile) -> void:
	var driver: MmEncounterDriver = _cheap_driver(copy, player_id, profile, ROLLOUT_DECISION_CAP)
	driver.run_until(func(running: MmEngine) -> bool:
		return running.game_state().game_turn > last_turn)
