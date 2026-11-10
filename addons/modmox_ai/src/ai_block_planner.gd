class_name AiBlockPlanner
extends RefCounted
## Chooses blocks (A163), reimplementing the behavior Forge's block controller is known
## for, not its code: blocks in rounds that grow more defensive as danger rises. First
## blocks the blocker survives, trades worth making and gang blocks, chump-blocking only if
## life is in danger; if still in danger, trades and chump blocks lead; if the attack would
## be lethal, chump blocks lead.

## Why the last plan() chose as it did, for AiAgent.explain().
var was_in_danger: bool = false
var was_lethal: bool = false

var _state: MmGameState
var _player_id: int
var _profile: AiProfile
var _decision: DeclareBlockersDecision
var _duel: Callable
var _gang: Callable


## [param duel] answers (attacker ID, blocker ID) with [attacker dies, blocker dies];
## [param gang], when valid, answers (attacker ID, [blocker IDs]) with the IDs that die.
func _init(state: MmGameState, player_id: int, profile: AiProfile, decision: DeclareBlockersDecision,
		duel: Callable, gang: Callable) -> void:
	_state = state
	_player_id = player_id
	_profile = profile
	_decision = decision
	_duel = duel
	_gang = gang


## The blocks to declare, as [blocker, attacker] pairs.
func plan() -> Array:
	var blocks: Dictionary[int, int] = {}
	_good_blocks(blocks)
	_trade_blocks(blocks, false)
	_gang_blocks(blocks)
	if _in_danger(blocks):
		was_in_danger = true
		_chump_blocks(blocks)
	if _in_danger(blocks):
		was_in_danger = true
		blocks = {}
		_good_blocks(blocks)
		_trade_blocks(blocks, true)
		_chump_blocks(blocks)
	if _is_lethal(blocks):
		was_lethal = true
		blocks = {}
		_chump_blocks(blocks)
		_good_blocks(blocks)
	var pairs: Array = []
	for blocker_id: int in blocks:
		pairs.append([blocker_id, blocks[blocker_id]])
	return pairs


## Each attacker, most dangerous first, gets a blocker that survives, preferring one that
## kills it, then the least valuable.
func _good_blocks(blocks: Dictionary[int, int]) -> void:
	for attacker_id: int in _attackers_by_threat():
		if blocks.values().has(attacker_id):
			continue
		var best: int = -1
		var best_kills: bool = false
		for blocker_id: int in _free_blockers(blocks, attacker_id):
			var outcome: Array[bool] = _duel.call(attacker_id, blocker_id)
			if outcome[1]:
				continue
			if best == -1 or (outcome[0] and not best_kills) \
					or (outcome[0] == best_kills and _value(blocker_id) < _value(best)):
				best = blocker_id
				best_kills = outcome[0]
		if best != -1:
			blocks[best] = attacker_id


## Blocks where both die. Worth it if the attacker is worth more, or, when
## [param when_even], at least as much.
func _trade_blocks(blocks: Dictionary[int, int], when_even: bool) -> void:
	for attacker_id: int in _attackers_by_threat():
		if blocks.values().has(attacker_id):
			continue
		for blocker_id: int in _blockers_by_value(_free_blockers(blocks, attacker_id)):
			var outcome: Array[bool] = _duel.call(attacker_id, blocker_id)
			var worth: bool = _value(attacker_id) > _value(blocker_id) \
				or (when_even and _value(attacker_id) >= _value(blocker_id))
			if outcome[0] and outcome[1] and worth:
				blocks[blocker_id] = attacker_id
				break


## Two blockers on an attacker neither kills alone, when it dies and losing at most the
## cheaper of them is worth it.
func _gang_blocks(blocks: Dictionary[int, int]) -> void:
	if not _gang.is_valid():
		return
	for attacker_id: int in _attackers_by_threat():
		if blocks.values().has(attacker_id):
			continue
		var free: Array[int] = _blockers_by_value(_free_blockers(blocks, attacker_id))
		for first: int in range(free.size()):
			var placed: bool = false
			for second: int in range(first + 1, free.size()):
				var pair: Array[int] = [free[first], free[second]]
				var dead: Array[int] = _gang.call(attacker_id, pair)
				var lost: int = 0
				for blocker_id: int in pair:
					if dead.has(blocker_id):
						lost += _value(blocker_id)
				if dead.has(attacker_id) and lost < _value(attacker_id) and not (dead.has(pair[0]) and dead.has(pair[1])):
					blocks[pair[0]] = attacker_id
					blocks[pair[1]] = attacker_id
					placed = true
					break
			if placed:
				break


## The least valuable free blockers block the biggest unblocked attackers while life is
## in danger.
func _chump_blocks(blocks: Dictionary[int, int]) -> void:
	for attacker_id: int in _attackers_by_power():
		if not _in_danger(blocks):
			return
		if blocks.values().has(attacker_id):
			continue
		var free: Array[int] = _blockers_by_value(_free_blockers(blocks, attacker_id))
		if not free.is_empty():
			blocks[free[0]] = attacker_id


func _in_danger(blocks: Dictionary[int, int]) -> bool:
	return _life_after(blocks) <= _profile.life_danger_threshold


func _is_lethal(blocks: Dictionary[int, int]) -> bool:
	return _life_after(blocks) <= 0


## Life after combat damage: unblocked attackers hit, and so does a blocked trampler's power
## beyond its blockers' toughness.
func _life_after(blocks: Dictionary[int, int]) -> int:
	var damage: int = 0
	for attacker_id: int in _decision.attacker_ids:
		var blockers: Array[int] = []
		for blocker_id: int in blocks:
			if blocks[blocker_id] == attacker_id:
				blockers.append(blocker_id)
		var power: int = maxi(_characteristics(attacker_id).power, 0)
		if blockers.is_empty():
			damage += power
		elif _characteristics(attacker_id).has_ability(TrampleAbility):
			var absorbed: int = 0
			for blocker_id: int in blockers:
				absorbed += _characteristics(blocker_id).toughness
			damage += maxi(power - absorbed, 0)
	return _state.player(_player_id).life - damage


func _free_blockers(blocks: Dictionary[int, int], attacker_id: int) -> Array[int]:
	var free: Array[int] = []
	for blocker_id: int in _decision.candidate_blocker_ids:
		if not blocks.has(blocker_id) and (_decision.blockable_by_blocker[blocker_id] as Array).has(attacker_id):
			free.append(blocker_id)
	return free


func _attackers_by_threat() -> Array[int]:
	var attackers: Array[int] = _decision.attacker_ids.duplicate()
	attackers.sort_custom(func(first: int, second: int) -> bool: return _value(first) > _value(second))
	return attackers


func _attackers_by_power() -> Array[int]:
	var attackers: Array[int] = _decision.attacker_ids.duplicate()
	attackers.sort_custom(func(first: int, second: int) -> bool:
		return _characteristics(first).power > _characteristics(second).power)
	return attackers


func _blockers_by_value(blocker_ids: Array[int]) -> Array[int]:
	var sorted: Array[int] = blocker_ids.duplicate()
	sorted.sort_custom(func(first: int, second: int) -> bool: return _value(first) < _value(second))
	return sorted


func _value(object_id: int) -> int:
	return AiBoardEvaluator.creature_value(_state, _state.object(object_id))


func _characteristics(object_id: int) -> MmCharacteristics:
	return _state.characteristics_of(_state.object(object_id))
