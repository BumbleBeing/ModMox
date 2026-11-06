class_name MmCombat
extends RefCounted
## Who is attacking and blocking in the current combat (CR 506), and which creatures have
## struck first. Part of the game state, changed only by events, and empty outside combat.
##
## Creatures are recorded by object ID. A creature that leaves the battlefield becomes a
## new object (ADR 0008), so the queries that take the state leave it out: that is how it
## is removed from combat (CR 506.4).

## The player being attacked, or MmGameState.NO_PLAYER before attackers are declared.
var defending_player_id: int = MmGameState.NO_PLAYER
## Whether the current combat damage step is the extra, earlier one for first and double
## strikers (CR 510.4).
var is_first_strike_damage_step: bool = false

var _attacker_ids: Array[int] = []
## CR 509.1h: an attacker stays blocked even once its blockers are gone.
var _blocked_attacker_ids: Array[int] = []
## Each block, as two lists of the same length: the blocker and the attacker it blocks.
var _block_blocker_ids: Array[int] = []
var _block_attacker_ids: Array[int] = []
var _damage_steps_begun: int = 0
## The creatures that had first strike or double strike as the first-strike combat damage
## step began, and so dealt their damage in it.
var _first_strike_ids: Array[int] = []


## An independent copy, for copies of the game state.
func duplicate_combat() -> MmCombat:
	var copy: MmCombat = MmCombat.new()
	copy.defending_player_id = defending_player_id
	copy.is_first_strike_damage_step = is_first_strike_damage_step
	copy._attacker_ids = _attacker_ids.duplicate()
	copy._blocked_attacker_ids = _blocked_attacker_ids.duplicate()
	copy._block_blocker_ids = _block_blocker_ids.duplicate()
	copy._block_attacker_ids = _block_attacker_ids.duplicate()
	copy._damage_steps_begun = _damage_steps_begun
	copy._first_strike_ids = _first_strike_ids.duplicate()
	return copy


## Whether any creature was declared as an attacker this combat, even if it has since left
## (CR 508.8 asks only whether attackers were declared).
func has_declared_attackers() -> bool:
	return not _attacker_ids.is_empty()


## Whether a combat damage step has begun this combat.
func has_begun_damage_step() -> bool:
	return _damage_steps_begun > 0


## The attacking creatures still on the battlefield, in ID order.
func attackers(state: MmGameState) -> Array[int]:
	return _present(state, _attacker_ids)


## The blocking creatures still on the battlefield, in ID order.
func blockers(state: MmGameState) -> Array[int]:
	return _present(state, _block_blocker_ids)


func is_attacking(object_id: int) -> bool:
	return _attacker_ids.has(object_id)


func is_blocking(object_id: int) -> bool:
	return _block_blocker_ids.has(object_id)


## CR 509.1h: whether [param attacker_id] became blocked, even if its blockers have left.
func is_blocked(attacker_id: int) -> bool:
	return _blocked_attacker_ids.has(attacker_id)


## The creatures still blocking [param attacker_id], in ID order.
func blockers_of(state: MmGameState, attacker_id: int) -> Array[int]:
	var found: Array[int] = []
	for index: int in _block_blocker_ids.size():
		if _block_attacker_ids[index] == attacker_id:
			found.append(_block_blocker_ids[index])
	return _present(state, found)


## The attackers still being blocked by [param blocker_id], in ID order.
func attackers_blocked_by(state: MmGameState, blocker_id: int) -> Array[int]:
	var found: Array[int] = []
	for index: int in _block_blocker_ids.size():
		if _block_blocker_ids[index] == blocker_id:
			found.append(_block_attacker_ids[index])
	return _present(state, found)


## Whether [param object_id] struck in this combat's first-strike combat damage step.
func struck_first(object_id: int) -> bool:
	return _first_strike_ids.has(object_id)


## Event-only: records the declared attackers and the player they attack.
func declare_attackers(attacker_ids: Array[int], defending_id: int) -> void:
	_attacker_ids.append_array(attacker_ids)
	defending_player_id = defending_id


## Event-only: records blocks, as parallel lists of blockers and the attackers they block.
func declare_blocks(blocker_ids: Array[int], attacker_ids: Array[int]) -> void:
	for index: int in blocker_ids.size():
		_block_blocker_ids.append(blocker_ids[index])
		_block_attacker_ids.append(attacker_ids[index])
		if not _blocked_attacker_ids.has(attacker_ids[index]):
			_blocked_attacker_ids.append(attacker_ids[index])


## Event-only: a combat damage step begins. [param first_strike_ids] are the creatures that
## strike in it when it is the first-strike step.
func begin_damage_step(first_strike: bool, first_strike_ids: Array[int]) -> void:
	_damage_steps_begun += 1
	is_first_strike_damage_step = first_strike
	if first_strike:
		_first_strike_ids = first_strike_ids.duplicate()


## Event-only: CR 511.3: every creature is removed from combat.
func clear() -> void:
	defending_player_id = MmGameState.NO_PLAYER
	is_first_strike_damage_step = false
	_attacker_ids.clear()
	_blocked_attacker_ids.clear()
	_block_blocker_ids.clear()
	_block_attacker_ids.clear()
	_damage_steps_begun = 0
	_first_strike_ids.clear()


## A description of everything recorded, for the state fingerprint.
func describe() -> String:
	return "combat defending %d attackers %s blocked %s blocks %s->%s damage steps %d first strike %s %s" % [
		defending_player_id, _attacker_ids, _blocked_attacker_ids, _block_blocker_ids, _block_attacker_ids,
		_damage_steps_begun, is_first_strike_damage_step, _first_strike_ids]


## The IDs in [param ids] of objects still on the battlefield, in ID order.
## Later (milestone 9): also leave out a permanent that stopped being a creature (CR 506.4).
func _present(state: MmGameState, ids: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for id: int in ids:
		var game_object: MmGameObject = state.object(id)
		if game_object != null and game_object.zone() == state.battlefield and not result.has(id):
			result.append(id)
	result.sort()
	return result
