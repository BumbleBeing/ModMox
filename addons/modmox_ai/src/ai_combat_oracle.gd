class_name AiCombatOracle
extends RefCounted
## Answers "if these attack and these block, what happens?" by running the engine's own
## combat on a Simulation Copy (glossary "Combat Oracle", A163), so first strike, trample,
## deathtouch, protection, prevention and regeneration all come out right. Made for one
## decision: every question uses the same re-dealt world, and answers are cached.

var _source: MmSimulationSource
var _world_seed: int
var _profile: AiProfile
var _fights: Dictionary[String, AiFightResult] = {}
var _blockable: Dictionary[int, Array] = {}
var _has_blockable: bool = false


func _init(source: MmSimulationSource, world_seed: int, profile: AiProfile) -> void:
	_source = source
	_world_seed = world_seed
	_profile = profile


## For the attacking player: which of the other player's creatures could block which of
## [param candidate_ids], as the engine itself would allow (blocker ID → attacker IDs).
func blockable(candidate_ids: Array[int]) -> Dictionary[int, Array]:
	if _has_blockable:
		return _blockable
	_has_blockable = true
	var copy: MmEngine = _source.simulation_copy(MmRng.new(_world_seed))
	if copy.submit(candidate_ids.duplicate()) != "":
		return _blockable
	_play_until_blocks(copy)
	var blocks: DeclareBlockersDecision = copy.pending_decision() as DeclareBlockersDecision
	if blocks != null:
		_blockable = blocks.blockable_by_blocker.duplicate(true)
	return _blockable


## [attacker dies, blocker dies] if [param blocker_id] alone blocks [param attacker_id].
func duel(attacker_id: int, blocker_id: int) -> Array[bool]:
	var attackers: Array[int] = [attacker_id]
	var result: AiFightResult = fight(attackers, [[blocker_id, attacker_id]])
	var outcome: Array[bool] = [result.dead_ids.has(attacker_id), result.dead_ids.has(blocker_id)]
	return outcome


## The outcome of a combat. When the copy is at its player's attackers decision,
## [param attacker_ids] attack; at a blockers decision they are already attacking and
## are ignored. [param blocks] are [blocker, attacker] pairs.
func fight(attacker_ids: Array[int], blocks: Array) -> AiFightResult:
	var key: String = "%s|%s" % [attacker_ids, blocks]
	if _fights.has(key):
		return _fights[key]
	var copy: MmEngine = _source.simulation_copy(MmRng.new(_world_seed))
	var result: AiFightResult = AiFightResult.new()
	var involved: Array[int] = attacker_ids.duplicate()
	for pair: Variant in blocks:
		involved.append_array(pair as Array)
	var defender_id: int = 1 - _source.player_id
	if copy.pending_decision() is DeclareAttackersDecision:
		if copy.submit(attacker_ids.duplicate()) != "":
			_fights[key] = result
			return result
		_play_until_blocks(copy)
	else:
		defender_id = _source.player_id
		involved.append_array(copy.game_state().combat.attackers(copy.game_state()))
	var life_before: int = copy.game_state().player(defender_id).life
	if copy.pending_decision() is DeclareBlockersDecision and copy.submit(blocks.duplicate(true)) != "":
		copy.submit([])
	AiSimulation.play_out(copy, _source.player_id, _profile)
	var state: MmGameState = copy.game_state()
	for id: int in involved:
		var survivor: MmGameObject = state.object(id)
		if (survivor == null or survivor.zone() != state.battlefield) and not result.dead_ids.has(id):
			result.dead_ids.append(id)
	result.damage_to_defender = life_before - state.player(defender_id).life
	_fights[key] = result
	return result


## Plays a copy on, after attackers are declared, until blockers must be declared or
## combat damage begins.
func _play_until_blocks(copy: MmEngine) -> void:
	var agents: Dictionary[int, MmAgent] = {}
	agents[0] = AiAgent.new(_profile, AiAgent.Mode.CHEAP)
	agents[1] = AiAgent.new(_profile, AiAgent.Mode.CHEAP)
	var driver: MmEncounterDriver = MmEncounterDriver.new(copy, agents)
	driver.builds_views = false
	driver.decision_cap = AiSimulation.DECISION_CAP
	driver.run_until(func(running: MmEngine) -> bool:
		return running.pending_decision() is DeclareBlockersDecision \
			or running.game_state().step != MmTurn.Step.DECLARE_ATTACKERS)
