class_name CombatSelection
extends RefCounted
## The Hero's half-made answer to one combat decision: the attackers chosen so far, the
## blocks paired so far, or how much damage each recipient has been given. Declaring
## attackers, declaring blockers and dividing combat damage are each answered all at once
## (ADR 0016), so the clicks that build an answer change this and nothing else, until the
## Hero confirms. The Encounter Screen keeps it outside the nodes it redraws, and makes a
## new one when the decision changes (A322).

## Stands for "no blocker is picked up".
const NONE: int = -1

var _decision: MmPendingDecision = null
var _attackers: Array[int] = []
## [blocker ID, attacker ID] pairs, in the order they were made.
var _pairs: Array = []
var _picked: int = NONE
var _amounts: Array[int] = []
## What the selection was before each change, for undo().
var _history: Array = []


## Whether [param decision] is of a kind answered through a selection.
static func covers(decision: MmPendingDecision) -> bool:
	return decision is DeclareAttackersDecision or decision is DeclareBlockersDecision or decision is DivideCombatDamageDecision


## An empty selection for [param decision], or one that selects nothing if the decision is
## of another kind or null. Dividing damage starts from default_split().
func _init(decision: MmPendingDecision = null) -> void:
	_decision = decision if covers(decision) else null
	if _decision is DivideCombatDamageDecision:
		_amounts = default_split(_decision as DivideCombatDamageDecision)


## How to divide the damage before the Hero changes anything: lethal damage to as many
## recipients as it reaches, in the order they stand. What is left over goes to the attacked
## player with trample, and otherwise to the first recipient that is still alive, or to the
## first of all.
static func default_split(divide: DivideCombatDamageDecision) -> Array[int]:
	var amounts: Array[int] = []
	var left: int = divide.amount
	for index: int in divide.recipients.size():
		var lethal: int = divide.lethal_amounts[index] if index < divide.lethal_amounts.size() else 0
		var given: int = lethal if lethal > 0 and left >= lethal else 0
		amounts.append(given)
		left -= given
	if left > 0 and not amounts.is_empty():
		var onto: int = 0
		if divide.includes_player():
			onto = amounts.size() - 1
		else:
			for index: int in amounts.size():
				if amounts[index] == 0:
					onto = index
					break
		amounts[onto] += left
	return amounts


## Whether this selection is for [param decision], and so should be kept across a redraw.
func is_for(decision: MmPendingDecision) -> bool:
	return decision == _decision


## Whether there is a combat decision being answered here.
func is_active() -> bool:
	return _decision != null


func attacker_ids() -> Array[int]:
	return _attackers.duplicate()


## The [blocker ID, attacker ID] pairs made so far.
func pairs() -> Array:
	return _pairs.duplicate(true)


## The blocker picked up and waiting for its attacker, or NONE.
func picked_id() -> int:
	return _picked


func amounts() -> Array[int]:
	return _amounts.duplicate()


## The attackers [param blocker_id] has been paired with.
func blocks_of(blocker_id: int) -> Array[int]:
	var found: Array[int] = []
	for pair: Array in _pairs:
		if pair[0] == blocker_id:
			found.append(pair[1])
	return found


## Whether Game Object [param object_id] has been chosen to attack or paired to block, so
## it stands forward in the lane.
func is_chosen(object_id: int) -> bool:
	return _attackers.has(object_id) or not blocks_of(object_id).is_empty()


## Whether clicking Game Object [param object_id] changes the selection: a creature that
## may attack, a creature that may block, or, while a blocker is picked up, an attacker it
## can block.
func is_clickable(object_id: int) -> bool:
	if _decision is DeclareAttackersDecision:
		return (_decision as DeclareAttackersDecision).candidate_ids.has(object_id)
	if _decision is DeclareBlockersDecision:
		return (_decision as DeclareBlockersDecision).candidate_blocker_ids.has(object_id) or target_ids().has(object_id)
	return false


## While a blocker is picked up: the attackers it can still be paired with or taken off,
## which glow as targets (A313). A blocker at its limit offers only those it already blocks.
func target_ids() -> Array[int]:
	var targets: Array[int] = []
	var blocks: DeclareBlockersDecision = _decision as DeclareBlockersDecision
	if blocks == null or _picked == NONE:
		return targets
	var already: Array[int] = blocks_of(_picked)
	var limit: int = blocks.most_blocks_by_blocker.get(_picked, 1)
	var blockable: Array = blocks.blockable_by_blocker.get(_picked, [])
	for attacker_id: int in blockable:
		if limit <= 1 or already.size() < limit or already.has(attacker_id):
			targets.append(attacker_id)
	return targets


## Clicks Game Object [param object_id]. A creature that may attack is chosen, or put back.
## A creature that may block is picked up. One that already blocks, or is picked up, is
## taken off its blocks and put down with that one click, whichever blocker is in hand. An
## attacker is paired with the blocker picked up: a blocker that blocks one attacker is put
## down, and one that may block several has that pairing switched and stays picked up
## (A323). Returns whether anything changed.
func click(object_id: int) -> bool:
	if not is_clickable(object_id):
		return false
	_remember()
	if _decision is DeclareAttackersDecision:
		if _attackers.has(object_id):
			_attackers.erase(object_id)
		else:
			_attackers.append(object_id)
		return true
	var blocks: DeclareBlockersDecision = _decision as DeclareBlockersDecision
	if blocks.candidate_blocker_ids.has(object_id):
		if _picked == object_id or not blocks_of(object_id).is_empty():
			_unassign(object_id)
			if _picked == object_id:
				_picked = NONE
		else:
			_picked = object_id
		return true
	if blocks.most_blocks_by_blocker.get(_picked, 1) <= 1:
		_unassign(_picked)
		_pairs.append([_picked, object_id])
		_picked = NONE
	elif blocks_of(_picked).has(object_id):
		var blocker_id: int = _picked
		_pairs = _pairs.filter(func(pair: Array) -> bool: return not (pair[0] == blocker_id and pair[1] == object_id))
	else:
		_pairs.append([_picked, object_id])
	return true


## A click on empty board: the blocker picked up is put down with its blocks taken off
## (A314). Returns whether one was picked up.
func put_down() -> bool:
	if _picked == NONE:
		return false
	_remember()
	_unassign(_picked)
	_picked = NONE
	return true


## Chooses every creature that may attack, without confirming (A311).
func select_all() -> bool:
	var attackers: DeclareAttackersDecision = _decision as DeclareAttackersDecision
	if attackers == null or _attackers.size() == attackers.candidate_ids.size():
		return false
	_remember()
	_attackers = attackers.candidate_ids.duplicate()
	return true


## How much of the damage has not been given to anyone yet.
func left_to_assign() -> int:
	var divide: DivideCombatDamageDecision = _decision as DivideCombatDamageDecision
	if divide == null:
		return 0
	var left: int = divide.amount
	for amount: int in _amounts:
		left -= amount
	return left


## Whether recipient [param index] can be given one more: there is damage left, and for the
## attacked player, every blocker already has lethal damage (CR 702.19b).
func can_raise(index: int) -> bool:
	var divide: DivideCombatDamageDecision = _decision as DivideCombatDamageDecision
	if divide == null or index < 0 or index >= _amounts.size() or left_to_assign() <= 0:
		return false
	if divide.recipients[index].is_player():
		for blocker: int in divide.lethal_amounts.size():
			if _amounts[blocker] < divide.lethal_amounts[blocker]:
				return false
	return true


## Whether recipient [param index] can be given one less. A blocker cannot drop below
## lethal while the attacked player has been given damage.
func can_lower(index: int) -> bool:
	var divide: DivideCombatDamageDecision = _decision as DivideCombatDamageDecision
	if divide == null or index < 0 or index >= _amounts.size() or _amounts[index] <= 0:
		return false
	if divide.includes_player() and index < divide.lethal_amounts.size() and _amounts.back() > 0:
		return _amounts[index] > divide.lethal_amounts[index]
	return true


## Gives recipient [param index] one more ([param change] 1) or one less (-1).
func change_amount(index: int, change: int) -> bool:
	if (change > 0 and not can_raise(index)) or (change < 0 and not can_lower(index)) or change == 0:
		return false
	_remember()
	_amounts[index] += signi(change)
	return true


## Whether recipient [param index] has been given at least lethal damage (A319).
func is_lethal(index: int) -> bool:
	var divide: DivideCombatDamageDecision = _decision as DivideCombatDamageDecision
	if divide == null or index < 0 or index >= divide.lethal_amounts.size():
		return false
	return divide.lethal_amounts[index] > 0 and _amounts[index] >= divide.lethal_amounts[index]


## Whether the answer can be given: always for attackers and blockers, and for a division
## once all of the damage is assigned.
func is_complete() -> bool:
	if _decision is DivideCombatDamageDecision:
		return left_to_assign() == 0
	return _decision != null


## The answer this selection gives its decision: attacker IDs in ID order, the pairs, or
## the amounts.
func answer() -> Variant:
	if _decision is DeclareAttackersDecision:
		var ids: Array[int] = _attackers.duplicate()
		ids.sort()
		return ids
	if _decision is DeclareBlockersDecision:
		return _pairs.duplicate(true)
	return _amounts.duplicate()


## What the confirm button reads (A310, A317, A318), or "" with no combat decision.
func confirm_text() -> String:
	if _decision is DeclareAttackersDecision:
		return "No attacks" if _attackers.is_empty() else "Attack with %d" % _attackers.size()
	if _decision is DeclareBlockersDecision:
		return "No blocks" if _pairs.is_empty() else "Confirm blocks"
	if _decision is DivideCombatDamageDecision:
		return "Assign damage"
	return ""


## What the Info Panel adds under its prompt: how blocking is done, until the first block
## is made (A326).
func hint() -> String:
	if _decision is DeclareBlockersDecision and _pairs.is_empty():
		return "Click a creature, then the attacker it blocks."
	return ""


func can_undo() -> bool:
	return not _history.is_empty()


## Takes back the last change (A320). Returns false when there is none, so the caller can
## undo the previous answer instead.
func undo() -> bool:
	if _history.is_empty():
		return false
	var before: Array = _history.pop_back()
	_attackers.assign(before[0])
	_pairs = before[1]
	_picked = before[2]
	_amounts.assign(before[3])
	return true


func _remember() -> void:
	_history.append([_attackers.duplicate(), _pairs.duplicate(true), _picked, _amounts.duplicate()])


func _unassign(blocker_id: int) -> void:
	_pairs = _pairs.filter(func(pair: Array) -> bool: return pair[0] != blocker_id)
