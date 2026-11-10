extends GutTest
## Milestone 11, step 1 (A160): how fast the engine copies a game and plays a turn, which
## decides whether Flat Monte Carlo can stay in GDScript. Forge spends about 20 ms per
## rollout on desktop; if a copy plus one turn of play costs much more, the GDExtension
## port is planned before Monte Carlo.
##
## This is a report, not a timing assertion: it asserts only that every encounter finishes,
## and prints its numbers. By default it plays 2 seeds (A185); for all 8, run it on its own:
##   MODMOX_FULL_BENCHMARK=1 tools/test.sh -gselect=test_benchmark
##
## At the start of each Game Turn it also times a real rollout: a Simulation Copy
## (ADR 0020) played to the start of the next Game Turn by the same policy.
##
## The policy is deliberately simple (no Agent exists yet): keep every hand, play a land,
## cast the first affordable spell, attack with everything, block one attacker per
## blocker, and pay with mana of a color still owed.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Soak := preload("res://addons/modmox_ai/tests/test_soak.gd")
## Monte Carlo decisions timed by default.
const DEFAULT_MONTE_CARLO_DECISIONS: int = 6
const CARDS: String = "res://content/cards/alpha/%s.tres"
const ALL_SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const DEFAULT_SEEDS: Array[int] = [1, 2]
const DECISION_CAP: int = 5000
## duplicate_state() calls timed at the start of each turn, averaged.
const COPIES_PER_SAMPLE: int = 3
## Game Turn buckets, so the cost of a long encounter's growing event log shows.
const BUCKETS: Array[String] = ["turns 1-4", "turns 5-8", "turns 9-12", "turns 13+"]

var _copy_usec: Dictionary[String, Array] = {}
var _rollout_usec: Dictionary[String, Array] = {}
var _turn_usec: Dictionary[String, Array] = {}
var _turn_decisions: Dictionary[String, Array] = {}
var _turn_checkpoints: Dictionary[String, Array] = {}


func test_benchmark_copying_and_playing_turns() -> void:
	for bucket: String in BUCKETS:
		_copy_usec[bucket] = []
		_rollout_usec[bucket] = []
		_turn_usec[bucket] = []
		_turn_decisions[bucket] = []
		_turn_checkpoints[bucket] = []
	var turns_played: Array[int] = []

	var seeds: Array[int] = ALL_SEEDS if OS.get_environment("MODMOX_FULL_BENCHMARK") != "" else DEFAULT_SEEDS
	for encounter_seed: int in seeds:
		var engine: MmEngine = MmEngine.start(_benchmark_setup(encounter_seed))
		var error: String = _play_to_end(engine)
		assert_eq(error, "", "Seed %d: %s" % [encounter_seed, error])
		assert_true(engine.is_over(), "Seed %d did not finish." % encounter_seed)
		turns_played.append(engine.game_state().game_turn)

	_print_report(seeds, turns_played)


## Milestone 12, step 1 (A187): how long a Flat Monte Carlo priority decision takes at
## each AI Difficulty. Easy AIs play the soak's encounters; at every priority decision
## where Normal would roll out, each level answers it too and is timed. Their answers are
## thrown away. The gate: Normal's median must stay under the slow-decision warning.
## By default it times the first DEFAULT_MONTE_CARLO_DECISIONS such decisions of seed 1;
## MODMOX_FULL_BENCHMARK=1 times every one in seeds 1 to 4.
func test_benchmark_monte_carlo_decisions() -> void:
	var full: bool = OS.get_environment("MODMOX_FULL_BENCHMARK") != ""
	var seeds: Array[int] = [1]
	if full:
		seeds.append_array([2, 3, 4])
	var limit: int = 1000000 if full else DEFAULT_MONTE_CARLO_DECISIONS
	var levels: Dictionary[String, AiDifficulty] = {
		"easy": AiDifficulty.easy(), "normal": AiDifficulty.normal(), "hard": AiDifficulty.hard()}
	var msec: Dictionary[String, Array] = {}
	var rollouts: Dictionary[String, Array] = {}
	for level: String in levels:
		msec[level] = []
		rollouts[level] = []
	var timed: int = 0
	var switched: Array[String] = []
	for encounter_seed: int in seeds:
		var engine: MmEngine = MmEngine.start(Soak.soak_setup(encounter_seed))
		var easy: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
		while not engine.is_over() and timed < limit:
			var decision: MmPendingDecision = engine.pending_decision()
			var answer: Variant = easy.answer(decision, null, engine.simulation_source_for(decision.player_id))
			if decision is PriorityDecision and _would_roll_out(engine, decision):
				timed += 1
				var answers: Dictionary[String, Variant] = {}
				var normal_detail: String = ""
				for level: String in levels:
					var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, levels[level])
					var started: int = Time.get_ticks_usec()
					answers[level] = agent.answer(decision, null, engine.simulation_source_for(decision.player_id))
					msec[level].append((Time.get_ticks_usec() - started) / 1000.0)
					rollouts[level].append(agent.rollout_count())
					if level == "normal":
						normal_detail = agent.explain_detail()
				if answers["normal"] != answers["easy"]:
					switched.append("  turn %d %s: one-step %s, Monte Carlo %s; %s" % [engine.game_state().game_turn,
						MmTurn.Step.find_key(engine.game_state().step), _describe_action(engine, answers["easy"]),
						_describe_action(engine, answers["normal"]), normal_detail])
			assert_eq(engine.submit(answer), "")
	assert_true(timed > 0)
	var lines: Array[String] = ["", "=== ModMox Monte Carlo benchmark: %d priority decisions, seeds %s ===" % [timed, seeds]]
	lines.append("%-7s %10s %10s %10s %12s %14s" % ["level", "median ms", "mean ms", "max ms", "rollouts", "ms per rollout"])
	for level: String in levels:
		var total_rollouts: float = _mean(rollouts[level]) * rollouts[level].size()
		var per_rollout: float = 0.0 if total_rollouts == 0 else _mean(msec[level]) * msec[level].size() / total_rollouts
		lines.append("%-7s %10.1f %10.1f %10.1f %12.1f %14.2f" % [level, _median(msec[level]), _mean(msec[level]),
			_max(msec[level]), _mean(rollouts[level]), per_rollout])
	lines.append("gate: Normal's median must stay under %d ms (A187)." % AiProfile.new().slow_decision_warning_ms)
	lines.append("Normal changed the one-step pick in %d of %d decisions:" % [switched.size(), timed])
	lines.append_array(switched)
	print("\n".join(lines))


## Whether a Normal Agent would run Flat Monte Carlo on [param decision].
func _would_roll_out(engine: MmEngine, decision: MmPendingDecision) -> bool:
	if (decision as PriorityDecision).actions.size() < 2:
		return false
	var probe: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())
	probe.answer(decision, null, engine.simulation_source_for(decision.player_id))
	return probe.explain() in [AiAgent.Reason.BEST_SCORE, AiAgent.Reason.SCORES_WORSE_THAN_PASS]


## Two 40-card decks of existing Content, 17 lands each: red-green and white-black.
func _benchmark_setup(encounter_seed: int) -> MmEncounterSetup:
	var setup: MmEncounterSetup = MmEncounterSetup.new()
	setup.hero = Scenario.player_setup(Scenario.run_cards(_deck({
		"mountain": 9, "forest": 8,
		"lightning_bolt": 4, "grizzly_bears": 4, "hill_giant": 3, "giant_growth": 3,
		"elvish_archers": 3, "giant_spider": 2, "keldon_warlord": 2, "wall_of_stone": 2,
	})))
	setup.villain = Scenario.player_setup(Scenario.run_cards(_deck({
		"plains": 9, "swamp": 8,
		"white_knight": 3, "black_knight": 3, "serra_angel": 2, "samite_healer": 3,
		"drudge_skeletons": 3, "terror": 3, "dark_ritual": 2, "crusade": 2, "fog": 2,
	})))
	setup.encounter_seed = encounter_seed
	return setup


func _deck(counts: Dictionary[String, int]) -> Array[MmCardDefinition]:
	var definitions: Array[MmCardDefinition] = []
	for file_name: String in counts:
		var definition: MmCardDefinition = load(CARDS % file_name) as MmCardDefinition
		definitions.append_array(Scenario.copies(definition, counts[file_name]))
	return definitions


## Plays the encounter to its end with the simple policy, timing every answer.
func _play_to_end(engine: MmEngine) -> String:
	var attempted_casts: Dictionary[int, int] = {}
	var sampled_turn: int = -1
	for _index: int in DECISION_CAP:
		if engine.is_over():
			return ""
		var state: MmGameState = engine.game_state()
		var bucket: String = _bucket(state.game_turn)
		if state.game_turn != sampled_turn and engine.pending_decision() is PriorityDecision:
			sampled_turn = state.game_turn
			_copy_usec[bucket].append(_time_copies(state))
			_rollout_usec[bucket].append(_time_rollout(engine))
			_turn_usec[bucket].append(0)
			_turn_decisions[bucket].append(0)
			_turn_checkpoints[bucket].append(0)

		var decision: MmPendingDecision = engine.pending_decision()
		var answer: Variant = _answer(engine, decision, attempted_casts)
		var events_before: int = state.event_log.size()
		var started: int = Time.get_ticks_usec()
		var error: String = engine.submit(answer)
		var elapsed: int = Time.get_ticks_usec() - started
		if error != "":
			return "%s rejected: %s" % [decision.describe(), error]

		if sampled_turn != -1:
			var last: int = _turn_usec[bucket].size() - 1
			_turn_usec[bucket][last] += elapsed
			_turn_decisions[bucket][last] += 1
			if _was_undo_barrier(engine, decision, events_before):
				_turn_checkpoints[bucket][last] += 1
	return "Gave up after %d decisions." % DECISION_CAP


## The average time of one duplicate_state() of [param state], in microseconds.
func _time_copies(state: MmGameState) -> int:
	var started: int = Time.get_ticks_usec()
	for _copy: int in COPIES_PER_SAMPLE:
		var copy: MmGameState = state.duplicate_state()
		assert_not_null(copy)
	return (Time.get_ticks_usec() - started) / COPIES_PER_SAMPLE


## The time of one real rollout, in microseconds: a Simulation Copy made and played by the
## simple policy to the start of the next Game Turn, or to the end of the encounter.
func _time_rollout(engine: MmEngine) -> int:
	var attempted_casts: Dictionary[int, int] = {}
	var started: int = Time.get_ticks_usec()
	var copy: MmEngine = engine.simulation_copy(engine.pending_decision().player_id, MmRng.new(engine.decision_count()))
	var game_turn: int = copy.game_state().game_turn
	for _index: int in DECISION_CAP:
		if copy.is_over() or copy.has_failed() or copy.game_state().game_turn != game_turn:
			break
		var error: String = copy.submit(_answer(copy, copy.pending_decision(), attempted_casts))
		assert_eq(error, "")
		if error != "":
			break
	return Time.get_ticks_usec() - started


## Mirrors MmEngine's undo-barrier rule (ADR 0015) from public state, so the report can
## subtract the checkpoint copies a simulation copy would not take.
func _was_undo_barrier(engine: MmEngine, answered: MmPendingDecision, events_before: int) -> bool:
	var pending: MmPendingDecision = engine.pending_decision()
	if pending == null or pending.player_id != answered.player_id:
		return true
	var log: Array[MmEvent] = engine.game_state().event_log
	for index: int in range(events_before, log.size()):
		var event: MmEvent = log[index]
		if event is ShuffleEvent or event is AbilityLeftStackEvent:
			return true
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.from_zone_kind in [MmZone.Kind.LIBRARY, MmZone.Kind.STACK]:
			return true
	return false


func _bucket(game_turn: int) -> String:
	return BUCKETS[clampi((game_turn - 1) / 4, 0, BUCKETS.size() - 1)]


# --- The simple policy -------------------------------------------------------------

## Answers [param decision]. The answer is a Variant because each decision kind takes a
## different shape.
func _answer(engine: MmEngine, decision: MmPendingDecision, attempted_casts: Dictionary[int, int]) -> Variant:
	if decision is PriorityDecision:
		return _priority_answer(engine, decision as PriorityDecision, attempted_casts)
	if decision is PayManaDecision:
		return _payment_answer(engine, decision as PayManaDecision)
	if decision is ChooseTargetDecision:
		return _target_answer(engine, decision as ChooseTargetDecision)
	if decision is DeclareAttackersDecision:
		return (decision as DeclareAttackersDecision).candidate_ids.duplicate()
	if decision is DeclareBlockersDecision:
		return _blockers_answer(decision as DeclareBlockersDecision)
	if decision is DivideCombatDamageDecision:
		return Scenario.all_to_first(decision as DivideCombatDamageDecision)
	if decision is KeepOrMulliganDecision:
		return KeepOrMulliganDecision.Choice.KEEP
	if decision is ChoosePlayOrDrawDecision:
		return ChoosePlayOrDrawDecision.Choice.PLAY
	if decision is ChooseCardsToBottomDecision:
		var bottom: ChooseCardsToBottomDecision = decision as ChooseCardsToBottomDecision
		return bottom.candidate_ids.slice(0, bottom.count)
	if decision is ChooseCardsToDiscardDecision:
		var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
		return discard.candidate_ids.slice(0, discard.count)
	if decision is OrderTriggersDecision:
		return range((decision as OrderTriggersDecision).source_object_ids.size())
	return 0  # ChooseReplacementEffectDecision: the first option.


## A land if one may be played, else the first spell not already tried this turn, else pass.
## A cast whose payment could not be finished rewinds to priority (ADR 0015), so each
## object is tried at most once per Game Turn to avoid a loop.
func _priority_answer(engine: MmEngine, decision: PriorityDecision, attempted_casts: Dictionary[int, int]) -> int:
	var land: int = Scenario.action_index(decision, func(action: MmAction) -> bool: return action is PlayLandAction)
	if land != -1:
		return land
	var game_turn: int = engine.game_state().game_turn
	for index: int in decision.actions.size():
		var cast: CastSpellAction = decision.actions[index] as CastSpellAction
		if cast != null and attempted_casts.get(cast.object_id, -1) != game_turn:
			attempted_casts[cast.object_id] = game_turn
			return index
	return Scenario.pass_index(decision)


## Mana of a color still owed if any option gives one, otherwise the first option.
func _payment_answer(engine: MmEngine, decision: PayManaDecision) -> int:
	if decision.remaining_symbols.is_empty():
		return 0
	var state: MmGameState = engine.game_state()
	var pool: Array[MmMana] = state.player(decision.player_id).mana_pool()
	for index: int in decision.actions.size():
		var action: MmAction = decision.actions[index]
		var produced: int = -1
		if action is PayWithManaAction:
			produced = pool[(action as PayWithManaAction).unit_index].type
		elif action is ActivateAbilityAction:
			produced = _mana_type_made(state, action as ActivateAbilityAction)
		if produced != -1 and decision.remaining_symbols.has(produced as MmMana.Type):
			return index
	return 0


func _mana_type_made(state: MmGameState, action: ActivateAbilityAction) -> int:
	var source: MmGameObject = state.object(action.object_id)
	var ability: ActivatedAbility = state.characteristics_of(source).abilities[action.ability_index] as ActivatedAbility
	if ability != null:
		for effect: MmEffect in ability.effects:
			if effect is AddManaEffect:
				return (effect as AddManaEffect).mana_type
	return -1


## The opponent if they are a candidate, else the first candidate the opponent controls,
## else the first candidate.
func _target_answer(engine: MmEngine, decision: ChooseTargetDecision) -> int:
	var state: MmGameState = engine.game_state()
	var fallback: int = 0
	for index: int in decision.candidates.size():
		var candidate: MmReference = decision.candidates[index]
		if candidate.kind == MmReference.Kind.PLAYER:
			if candidate.id != decision.player_id:
				return index
		elif fallback == 0 and state.object(candidate.id).controller_id != decision.player_id:
			fallback = index
	return fallback


## Each blocker blocks the first attacker it can, one attacker each.
func _blockers_answer(decision: DeclareBlockersDecision) -> Array:
	var pairs: Array = []
	for blocker: int in decision.candidate_blocker_ids:
		var blockable: Array = decision.blockable_by_blocker[blocker]
		if not blockable.is_empty():
			pairs.append([blocker, blockable[0]])
	return pairs


# --- The report --------------------------------------------------------------------

func _print_report(seeds: Array[int], turns_played: Array[int]) -> void:
	var lines: Array[String] = []
	lines.append("")
	lines.append("=== ModMox benchmark: %d seeded encounters, Game Turns played %s ===" % [seeds.size(), turns_played])
	lines.append("%-11s %6s %10s %10s %10s %9s %13s %12s" % [
		"bucket", "turns", "copy ms", "turn ms", "decisions", "checkpts", "est. rollout", "rollout ms"])
	var worst_rollout: float = 0.0
	var all_rollouts: Array = []
	for bucket: String in BUCKETS:
		var turns: int = _turn_usec[bucket].size()
		if turns == 0:
			continue
		var copy_ms: float = _mean(_copy_usec[bucket]) / 1000.0
		var turn_ms: float = _mean(_turn_usec[bucket]) / 1000.0
		var checkpoints: float = _mean(_turn_checkpoints[bucket])
		# The estimate from before Simulation Copies existed: one copy plus the turn, minus
		# the checkpoint copies the real engine made. "rollout ms" is the measured cost.
		var estimate_ms: float = copy_ms + maxf(turn_ms - checkpoints * copy_ms, 0.0)
		var rollout_ms: float = _mean(_rollout_usec[bucket]) / 1000.0
		worst_rollout = maxf(worst_rollout, rollout_ms)
		all_rollouts.append_array(_rollout_usec[bucket])
		lines.append("%-11s %6d %10.2f %10.2f %10.1f %9.1f %10.2f ms %9.2f ms" % [
			bucket, turns, copy_ms, turn_ms, _mean(_turn_decisions[bucket]), checkpoints, estimate_ms, rollout_ms])
	lines.append("AI RNG for one decision: %.4f ms" % _time_ai_rng())
	lines.append("gate: Forge spends about 20 ms per rollout; measured %.2f ms on average, %.2f ms in the worst bucket." % [
		_mean(all_rollouts) / 1000.0, worst_rollout])
	print("\n".join(lines))


## The cost of making one decision's AI RNG and drawing from it (A158), in milliseconds.
func _time_ai_rng() -> float:
	var started: int = Time.get_ticks_usec()
	for index: int in 1000:
		MmRng.for_ai(12345, 1, index).next_int(100)
	return (Time.get_ticks_usec() - started) / 1000.0 / 1000.0


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: Variant in values:
		total += float(value)
	return total / values.size()


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


func _max(values: Array) -> float:
	var most: float = 0.0
	for value: Variant in values:
		most = maxf(most, float(value))
	return most


func _describe_action(engine: MmEngine, index: Variant) -> String:
	var action: MmAction = (engine.pending_decision() as PriorityDecision).actions[index as int]
	if action is PassAction:
		return "pass"
	var cast: CastSpellAction = action as CastSpellAction
	if cast != null:
		return "cast %s" % engine.game_state().object(cast.object_id).definition.name
	var activate: ActivateAbilityAction = action as ActivateAbilityAction
	if activate != null:
		return "activate %s" % engine.game_state().object(activate.object_id).definition.name
	return action.get_script().resource_path.get_file()
