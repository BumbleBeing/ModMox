class_name AiAttackPlanner
extends RefCounted
## Chooses attackers (A163), reimplementing the behavior Forge's attack controller is known
## for, not its code: attack with everything when that is lethal, otherwise set an
## aggression level from 0 to 5 by comparing the two sides' clocks, send each creature that
## clears that level's bar, and hold back enough to survive the swing back. Each creature is
## judged attacking alone; when something its player controls cares whether a creature
## attacks alone (exalted, CR 506.5), the chosen attackers are judged again beside each
## other, and the least valuable that no longer clears the bar stays home, until the rest do.

## The aggression levels.
enum Aggression { STAY_HOME = 0, EVASION_ONLY = 1, SAFE = 2, GOOD_TRADES = 3, EXPECT_TRADES = 4, ALL_OUT = 5 }

## Why the last plan() chose as it did, for AiAgent.explain().
var was_lethal: bool = false
var aggression: Aggression = Aggression.STAY_HOME

var _state: MmGameState
var _player_id: int
var _profile: AiProfile
var _rng: MmRng
var _duel: Callable
var _blockable: Dictionary[int, Array]


## [param duel] answers (attacker ID, blocker ID, the IDs attacking with it, itself
## included) with [attacker dies, blocker dies].
## [param blockable] maps each possible blocker to the attackers it could block.
func _init(state: MmGameState, player_id: int, profile: AiProfile, rng: MmRng, duel: Callable,
		blockable: Dictionary[int, Array]) -> void:
	_state = state
	_player_id = player_id
	_profile = profile
	_rng = rng
	_duel = duel
	_blockable = blockable


## The attackers to declare from [param candidate_ids].
func plan(candidate_ids: Array[int]) -> Array[int]:
	var attacking: Array[int] = []
	if candidate_ids.is_empty():
		return attacking
	if _is_lethal(candidate_ids):
		was_lethal = true
		aggression = Aggression.ALL_OUT
		return candidate_ids.duplicate()
	aggression = _aggression(candidate_ids)
	for attacker_id: int in candidate_ids:
		if _should_attack(attacker_id, aggression, [attacker_id] as Array[int]):
			attacking.append(attacker_id)
	if _cares_about_attacking_alone():
		attacking = _together(attacking)
	return _hold_back(attacking)


## [param attacking], each judged again attacking beside the others: while any of them no
## longer clears the bar, the least valuable of those stays home. One attacker alone was
## judged so already, so at least one is always left.
func _together(attacking: Array[int]) -> Array[int]:
	var kept: Array[int] = attacking.duplicate()
	while kept.size() > 1:
		var weakest: int = -1
		for attacker_id: int in kept:
			if _should_attack(attacker_id, aggression, kept):
				continue
			if weakest == -1 or _value(attacker_id) < _value(weakest):
				weakest = attacker_id
		if weakest == -1:
			break
		kept.erase(weakest)
	return kept


## Whether a triggered ability of a permanent this player controls waits for a creature
## attacking alone (CR 506.5), so who else attacks changes what each attacker does.
func _cares_about_attacking_alone() -> bool:
	for permanent: MmGameObject in _state.battlefield.objects():
		if permanent.controller_id != _player_id:
			continue
		for ability: MmAbility in _state.characteristics_of(permanent).abilities:
			var triggered: TriggeredAbility = ability as TriggeredAbility
			if triggered != null and triggered.trigger is AttackersDeclaredTrigger \
					and (triggered.trigger as AttackersDeclaredTrigger).alone:
				return true
	return false


## Whether attacking with everything kills even if each blocker stops a different one of the
## biggest attackers it can block.
func _is_lethal(candidate_ids: Array[int]) -> bool:
	var by_damage: Array[int] = candidate_ids.duplicate()
	by_damage.sort_custom(func(first: int, second: int) -> bool: return _combat_damage(first) > _combat_damage(second))
	var used: Array[int] = []
	var unblocked: int = 0
	for attacker_id: int in by_damage:
		var stopped: bool = false
		for blocker_id: int in _blockers_of(attacker_id):
			if not used.has(blocker_id):
				used.append(blocker_id)
				stopped = true
				break
		if not stopped:
			unblocked += _combat_damage(attacker_id)
	return unblocked >= _state.opponent_of(_player_id).life


func _aggression(candidate_ids: Array[int]) -> Aggression:
	if _blockable.is_empty():
		return Aggression.ALL_OUT
	var my_damage: int = 0
	for attacker_id: int in candidate_ids:
		my_damage += maxi(_combat_damage(attacker_id), 0)
	var their_damage: int = _their_attack_damage()
	var turns_to_win: int = ceili(float(_state.opponent_of(_player_id).life) / maxi(my_damage, 1))
	var turns_to_lose: int = 99 if their_damage == 0 else ceili(float(_state.player(_player_id).life) / their_damage)
	if turns_to_win + 1 < turns_to_lose:
		return Aggression.EXPECT_TRADES
	if turns_to_win < turns_to_lose:
		return Aggression.GOOD_TRADES
	if turns_to_win == turns_to_lose:
		return Aggression.GOOD_TRADES if _profile.plays_aggressively else Aggression.SAFE
	return Aggression.SAFE if _profile.plays_aggressively else Aggression.EVASION_ONLY


## Whether [param attacker_id] clears [param level]'s bar attacking with [param attacking].
func _should_attack(attacker_id: int, level: Aggression, attacking: Array[int]) -> bool:
	var blockers: Array[int] = _blockers_of(attacker_id)
	var killers: Array[int] = []
	var victims: Array[int] = []
	for blocker_id: int in blockers:
		var outcome: Array[bool] = _duel.call(attacker_id, blocker_id, attacking)
		if outcome[0]:
			killers.append(blocker_id)
		if outcome[1]:
			victims.append(blocker_id)
	var unblockable: bool = blockers.is_empty()
	var is_safe: bool = killers.is_empty()
	match level:
		Aggression.ALL_OUT:
			return true
		Aggression.EXPECT_TRADES:
			return unblockable or is_safe or victims.size() == blockers.size()
		Aggression.GOOD_TRADES:
			return is_safe or _trades_well(attacker_id, killers, victims)
		Aggression.SAFE:
			return is_safe and (unblockable or not victims.is_empty() or _profile.plays_aggressively)
		Aggression.EVASION_ONLY:
			return unblockable
	return false


## Whether every blocker that would kill [param attacker_id] dies too, and is worth at least
## as much, or the AI Profile's chance to attack into a trade comes up.
func _trades_well(attacker_id: int, killers: Array[int], victims: Array[int]) -> bool:
	for killer_id: int in killers:
		if not victims.has(killer_id):
			return false
	var mine: int = _value(attacker_id)
	for killer_id: int in killers:
		if _value(killer_id) < mine:
			return _rng.next_int(100) < _profile.chance_to_attack_into_trade
	return true


## Keeps attackers home, sturdiest first, until the other player's swing back could not kill.
func _hold_back(attacking: Array[int]) -> Array[int]:
	var kept: Array[int] = attacking.duplicate()
	while not kept.is_empty() and _swing_back(kept) >= _state.player(_player_id).life:
		var sturdiest: int = -1
		for attacker_id: int in kept:
			if _has(attacker_id, VigilanceAbility):
				continue
			if sturdiest == -1 or _toughness(attacker_id) > _toughness(sturdiest):
				sturdiest = attacker_id
		if sturdiest == -1:
			break
		kept.erase(sturdiest)
	return kept


## The damage the other player's creatures could deal next turn if each creature left
## untapped by this attack blocks one of the biggest.
func _swing_back(attacking: Array[int]) -> int:
	var damages: Array[int] = []
	for creature: MmGameObject in _creatures_of(1 - _player_id):
		if not _has(creature.id, DefenderAbility):
			damages.append(_combat_damage(creature.id))
	damages.sort()
	damages.reverse()
	var defenders: int = 0
	for creature: MmGameObject in _creatures_of(_player_id):
		if not attacking.has(creature.id) or _has(creature.id, VigilanceAbility):
			defenders += 1
	var total: int = 0
	for index: int in range(defenders, damages.size()):
		total += damages[index]
	return total


func _their_attack_damage() -> int:
	var total: int = 0
	for creature: MmGameObject in _creatures_of(1 - _player_id):
		if not _has(creature.id, DefenderAbility):
			total += maxi(_combat_damage(creature.id), 0)
	return total


func _blockers_of(attacker_id: int) -> Array[int]:
	var blockers: Array[int] = []
	for blocker_id: int in _blockable:
		if (_blockable[blocker_id] as Array).has(attacker_id):
			blockers.append(blocker_id)
	return blockers


func _creatures_of(player_id: int) -> Array[MmGameObject]:
	var creatures: Array[MmGameObject] = []
	for permanent: MmGameObject in _state.battlefield.objects():
		if permanent.controller_id == player_id and _state.characteristics_of(permanent).has_card_type(MmCardTypes.CardType.CREATURE):
			creatures.append(permanent)
	return creatures


## The combat damage [param object_id] would assign: its power, or its toughness when an
## ability says so (CombatProcedure.combat_damage_amount()).
func _combat_damage(object_id: int) -> int:
	return CombatProcedure.combat_damage_amount(_state, _state.object(object_id))


func _value(object_id: int) -> int:
	return AiBoardEvaluator.creature_value(_state, _state.object(object_id))


func _toughness(object_id: int) -> int:
	return _state.characteristics_of(_state.object(object_id)).toughness


func _has(object_id: int, kind: Script) -> bool:
	return _state.characteristics_of(_state.object(object_id)).has_ability(kind)
