class_name AiLoggingAgent
extends MmAgent
## The AI Log: answers exactly as [member agent] does, and writes down each answer with why
## it was chosen, so a bad play seen in a playtest can be read back afterwards. Each entry
## names the Game Turn and step, the decision, the answer with its cards' names, the reason
## (AiAgent.Reason), how long it took and how many rollouts it played, then the options
## numbered as explain_detail() numbers them and that detail itself: the scores, or the
## aggression of an attack.
##
## It reads only what an Agent may (ADR 0020): its World, the names of cards and the step
## read from it once the answer is given, so the answer never depends on the log. It never
## reads the clock itself (A159): whoever begins it hands it the time it was written and a
## [member clock] that says how long each answer took, so a test hands it fixed ones.
## It writes from whatever thread answers, one entry at a time. A priority decision with
## nothing but Pass, and every mana payment, are left out: there are hundreds and they say
## nothing.

## Where the game keeps its AI Logs. Tests use another.
const FOLDER: String = "user://ai_logs/"
const EXTENSION: String = ".log"

var agent: AiAgent
## The file the log is written to, or "" for a log kept in memory alone.
var path: String = ""
## Milliseconds from some fixed start, read before and after each answer to say how long it
## took; an empty Callable for a log that says nothing of time.
var clock: Callable = Callable()
## Every line written, in order.
var lines: PackedStringArray = PackedStringArray()


func _init(logged_agent: AiAgent, file_path: String = "", answer_clock: Callable = Callable()) -> void:
	agent = logged_agent
	path = file_path
	clock = answer_clock


## A log of [param logged_agent]'s answers in an encounter with [param encounter_seed], in a
## file of its own in [param folder] named for [param written_at], the time it is begun as
## the caller reads it ("2026-11-25T16:50:00"), and the seed. Its first line names the seed
## and the AI Difficulty's search. [param answer_clock] times each answer ([member clock]).
static func begin(folder: String, encounter_seed: int, logged_agent: AiAgent, written_at: String,
		answer_clock: Callable = Callable()) -> AiLoggingAgent:
	DirAccess.make_dir_recursive_absolute(folder)
	var base_name: String = "%s-%d" % [written_at.replace(":", "-"), encounter_seed]
	var file_path: String = folder.path_join(base_name + EXTENSION)
	var number: int = 2
	while FileAccess.file_exists(file_path):
		file_path = folder.path_join("%s-%d%s" % [base_name, number, EXTENSION])
		number += 1
	# A bare new(): a script that extends a script class never names itself as a value.
	var made: AiLoggingAgent = new(logged_agent, file_path, answer_clock)
	made._write(["AI Log of Encounter Seed %d, %s, written %s" % [encounter_seed, _search_of(logged_agent.difficulty),
		written_at]])
	return made


func answer(decision: MmPendingDecision, view: MmPlayerView, source: MmSimulationSource) -> Variant:
	var started: int = clock.call() if clock.is_valid() else 0
	var result: Variant = agent.answer(decision, view, source)
	var elapsed: int = clock.call() - started if clock.is_valid() else -1
	if decision is PayManaDecision:
		return result
	var priority: PriorityDecision = decision as PriorityDecision
	if priority != null and priority.actions.size() == 1:
		return result
	var world: MmGameState = source.world(source.ai_rng())
	if priority == null or _offers_more_than_mana(priority, world):
		_write(_entry(decision, result, world, elapsed))
	return result


## Whether [param decision] offers something besides Pass and mana abilities, which the
## Agent never weighs as plays.
static func _offers_more_than_mana(decision: PriorityDecision, world: MmGameState) -> bool:
	for action: MmAction in decision.actions:
		if action is PassAction:
			continue
		var ability: ActivatedAbility = AiTiming.activated_ability_of(world, action)
		if ability == null or not ability.is_mana_ability():
			return true
	return false


func _entry(decision: MmPendingDecision, result: Variant, world: MmGameState, elapsed: int) -> Array[String]:
	var entry: Array[String] = [""]
	var when: String = "Before the game"
	if world.step != MmTurn.Step.NONE:
		var whose: String = "its own" if world.active_player_id == decision.player_id else "the other player's"
		when = "Game Turn %d (%s), %s" % [world.game_turn, whose, MmTurn.Step.find_key(world.step).to_lower().replace("_", " ")]
	entry.append("%s: %s" % [when, decision.describe()])
	var costs: Array[String] = [AiAgent.Reason.find_key(agent.explain())]
	if elapsed >= 0:
		costs.append("%d ms" % elapsed)
	if agent.rollout_count() > 0:
		costs.append("%d rollouts" % agent.rollout_count())
	if agent.repeat_count() > 1:
		costs.append("a Repeat Plan of %d" % agent.repeat_count())
	entry.append("  chose: %s  [%s]" % [_words_of_answer(decision, result, world), ", ".join(costs)])
	var options: Array[String] = _options_of(decision, world)
	if not options.is_empty():
		entry.append("  options: " + "; ".join(options))
	if agent.explain_detail() != "":
		entry.append("  detail: " + agent.explain_detail())
	return entry


## The answer in words: the action or target chosen with its card's name, the creatures sent
## to attack or block by name, and anything else as it was given.
static func _words_of_answer(decision: MmPendingDecision, result: Variant, world: MmGameState) -> String:
	var actions: Array[MmAction] = _actions_of(decision)
	if not actions.is_empty() and typeof(result) == TYPE_INT:
		return _words_of_action(actions[result], world)
	if decision is ChooseTargetDecision and typeof(result) == TYPE_INT:
		return _words_of_reference((decision as ChooseTargetDecision).candidates[result], world)
	if decision is ChooseTargetsDecision and result is Array:
		var chosen: Array[String] = []
		for index: Variant in result:
			chosen.append(_words_of_reference((decision as ChooseTargetsDecision).candidates[int(index)], world))
		return "none" if chosen.is_empty() else ", ".join(chosen)
	if decision is DeclareAttackersDecision and result is Array:
		var attackers: Array[String] = []
		for id: Variant in result:
			attackers.append(_name_of(int(id), world))
		return "no attack" if attackers.is_empty() else "attack with " + ", ".join(attackers)
	if decision is DeclareBlockersDecision and result is Array:
		var blocks: Array[String] = []
		for pair: Variant in result:
			blocks.append("%s blocks %s" % [_name_of(int(pair[0]), world), _name_of(int(pair[1]), world)])
		return "no blocks" if blocks.is_empty() else "; ".join(blocks)
	return str(result)


## The options of [param decision] in words, each with the number explain_detail() gives it.
static func _options_of(decision: MmPendingDecision, world: MmGameState) -> Array[String]:
	var options: Array[String] = []
	var actions: Array[MmAction] = _actions_of(decision)
	for index: int in actions.size():
		options.append("%d: %s" % [index, _words_of_action(actions[index], world)])
	if decision is ChooseTargetDecision:
		var candidates: Array[MmReference] = (decision as ChooseTargetDecision).candidates
		for index: int in candidates.size():
			options.append("%d: %s" % [index, _words_of_reference(candidates[index], world)])
	return options


static func _actions_of(decision: MmPendingDecision) -> Array[MmAction]:
	if decision is PriorityDecision:
		return (decision as PriorityDecision).actions
	return []


static func _words_of_action(action: MmAction, world: MmGameState) -> String:
	if action is PassAction:
		return "pass"
	var words: String = action.describe()
	if "object_id" in action:
		var game_object: MmGameObject = world.object(int(action.get("object_id")))
		if game_object != null:
			words += " (%s)" % world.characteristics_of(game_object).name
	return words


static func _words_of_reference(reference: MmReference, world: MmGameState) -> String:
	if reference == null:
		return "nothing"
	if reference.is_player():
		return "player %d" % reference.id
	return _name_of(reference.id, world)


static func _name_of(object_id: int, world: MmGameState) -> String:
	var game_object: MmGameObject = world.object(object_id)
	return "object %d" % object_id if game_object == null else world.characteristics_of(game_object).name


## How much [param difficulty] searches, in a few words.
static func _search_of(difficulty: AiDifficulty) -> String:
	if not difficulty.uses_monte_carlo:
		return "one-step simulation, no Monte Carlo"
	return "Flat Monte Carlo over %d candidates and %d samples" % [difficulty.rollout_candidates, difficulty.rollout_samples]


func _write(entry: Array[String]) -> void:
	lines.append_array(PackedStringArray(entry))
	if path == "":
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	for line: String in entry:
		file.store_line(line)
