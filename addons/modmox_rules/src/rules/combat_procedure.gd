class_name CombatProcedure
extends RefCounted
## The turn-based actions of the combat steps that need players' choices: declaring
## attackers (CR 508.1), declaring blockers (CR 509.1), and assigning and dealing combat
## damage (CR 510.1-510.2). The turn procedure runs one at the start of each of those
## steps, and gives players priority once it is done. A decision with only one possible
## answer is never asked.

enum Kind { DECLARE_ATTACKERS, DECLARE_BLOCKERS, COMBAT_DAMAGE }

var _state: MmGameState
var _kind: Kind
var _is_done: bool = false
## Combat damage: the attackers that deal damage in this step, in ID order, and how many
## of them have had their damage assigned.
var _striking_attacker_ids: Array[int] = []
var _next_attacker: int = 0
## Combat damage assigned so far, as three lists of the same length.
var _source_ids: Array[int] = []
var _recipients: Array[MmReference] = []
var _amounts: Array[int] = []


## CR 508.1: the active player will declare attackers.
static func declare_attackers(state: MmGameState) -> CombatProcedure:
	return CombatProcedure.new(state, Kind.DECLARE_ATTACKERS)


## CR 509.1: the defending player will declare blockers.
static func declare_blockers(state: MmGameState) -> CombatProcedure:
	return CombatProcedure.new(state, Kind.DECLARE_BLOCKERS)


## Begins a combat damage step. CR 510.4: if a first or double striker is in combat as the
## first combat damage step begins, it is the extra first-strike step, and only those
## creatures strike in it; the turn procedure then adds the regular step after it.
static func combat_damage(state: MmGameState) -> CombatProcedure:
	var combat: MmCombat = state.combat
	var first_strike_ids: Array[int] = []
	if not combat.has_begun_damage_step():
		for id: int in combat.attackers(state) + combat.blockers(state):
			var characteristics: MmCharacteristics = state.characteristics_of(state.object(id))
			if characteristics.has_ability(FirstStrikeAbility) or characteristics.has_ability(DoubleStrikeAbility):
				first_strike_ids.append(id)
	state.perform(CombatDamageStepEvent.new(not first_strike_ids.is_empty(), first_strike_ids))
	var procedure: CombatProcedure = CombatProcedure.new(state, Kind.COMBAT_DAMAGE)
	for attacker_id: int in combat.attackers(state):
		if procedure._strikes_in_this_step(attacker_id):
			procedure._striking_attacker_ids.append(attacker_id)
	return procedure


func _init(state: MmGameState, kind: Kind) -> void:
	_state = state
	_kind = kind


## A copy of this procedure working on [param state], a copy of the original state.
func copy_for(state: MmGameState) -> CombatProcedure:
	var copy: CombatProcedure = CombatProcedure.new(state, _kind)
	copy._is_done = _is_done
	copy._striking_attacker_ids = _striking_attacker_ids.duplicate()
	copy._next_attacker = _next_attacker
	copy._source_ids = _source_ids.duplicate()
	copy._recipients = _recipients.duplicate()  # MmReferences never change, so sharing them is safe.
	copy._amounts = _amounts.duplicate()
	return copy


## The next choice a player must make, or null once this step's actions are done.
func next_decision() -> MmPendingDecision:
	if _is_done:
		return null
	match _kind:
		Kind.DECLARE_ATTACKERS:
			var candidates: Array[int] = _attacker_candidates()
			if not candidates.is_empty():
				return DeclareAttackersDecision.new(_state.active_player_id, candidates)
		Kind.DECLARE_BLOCKERS:
			var attackers: Array[int] = _state.combat.attackers(_state)
			var defending_id: int = _state.combat.defending_player_id
			var candidates: Array[int] = [] if attackers.is_empty() else _blocker_candidates(defending_id)
			if not candidates.is_empty():
				return DeclareBlockersDecision.new(defending_id, candidates, attackers)
		Kind.COMBAT_DAMAGE:
			while _next_attacker < _striking_attacker_ids.size():
				var division: DivideCombatDamageDecision = _assign_or_ask(_striking_attacker_ids[_next_attacker])
				if division != null:
					return division
				_next_attacker += 1
			_assign_blockers_damage()
			_deal_assigned_damage()
	_is_done = true
	return null


## Applies an already-validated [param answer] to [param decision].
func apply_answer(decision: MmPendingDecision, answer: Variant) -> void:
	if decision is DeclareAttackersDecision:
		var attacker_ids: Array[int] = []
		for id: Variant in answer as Array:
			attacker_ids.append(id as int)
		attacker_ids.sort()
		if not attacker_ids.is_empty():
			var defending_id: int = _state.opponent_of(decision.player_id).id
			_state.perform(AttackersDeclaredEvent.new(decision.player_id, attacker_ids, defending_id))
			for id: int in attacker_ids:
				# CR 508.1f. Later (milestone 9): vigilance.
				_state.perform(TapEvent.new(id))
		_is_done = true
	elif decision is DeclareBlockersDecision:
		var blocker_ids: Array[int] = []
		var attacker_ids: Array[int] = []
		for pair: Variant in answer as Array:
			blocker_ids.append((pair as Array)[0] as int)
			attacker_ids.append((pair as Array)[1] as int)
		if not blocker_ids.is_empty():
			_state.perform(BlockersDeclaredEvent.new(decision.player_id, blocker_ids, attacker_ids))
		_is_done = true
	elif decision is DivideCombatDamageDecision:
		var division: DivideCombatDamageDecision = decision as DivideCombatDamageDecision
		var amounts: Array = answer
		for index: int in division.recipients.size():
			_assign(division.attacker_id, division.recipients[index], amounts[index] as int)
		_next_attacker += 1
	else:
		assert(false, "Combat cannot answer %s." % decision.describe())


## CR 508.1a: untapped creatures the active player controls that are not summoning sick.
func _attacker_candidates() -> Array[int]:
	var candidates: Array[int] = []
	for permanent: MmGameObject in ManaPayment.sorted_permanents_of(_state, _state.active_player_id):
		if _is_untapped_creature(permanent) and not _state.is_summoning_sick(permanent):
			candidates.append(permanent.id)
	return candidates


## CR 509.1a: untapped creatures the defending player controls.
func _blocker_candidates(defending_id: int) -> Array[int]:
	var candidates: Array[int] = []
	for permanent: MmGameObject in ManaPayment.sorted_permanents_of(_state, defending_id):
		if _is_untapped_creature(permanent):
			candidates.append(permanent.id)
	return candidates


func _is_untapped_creature(permanent: MmGameObject) -> bool:
	return not permanent.is_tapped and _state.characteristics_of(permanent).has_card_type(MmCardTypes.CardType.CREATURE)


## CR 510.4 and 702.4b: in the first-strike step, the creatures that had first or double
## strike as it began; in the regular step, every other creature, and double strikers again.
func _strikes_in_this_step(id: int) -> bool:
	var combat: MmCombat = _state.combat
	if combat.is_first_strike_damage_step:
		return combat.struck_first(id)
	return not combat.struck_first(id) or _state.characteristics_of(_state.object(id)).has_ability(DoubleStrikeAbility)


## Assigns [param attacker_id]'s combat damage when there is only one way to do it (CR
## 510.1a-c, 702.19), or returns the decision that lets its controller divide it.
func _assign_or_ask(attacker_id: int) -> DivideCombatDamageDecision:
	var attacker: MmGameObject = _state.object(attacker_id)
	var characteristics: MmCharacteristics = _state.characteristics_of(attacker)
	var power: int = characteristics.power
	if power <= 0:
		return null  # CR 510.1a: a creature with 0 or less power assigns no combat damage.
	var combat: MmCombat = _state.combat
	var defending_player: MmReference = MmReference.to_player(combat.defending_player_id)
	var tramples: bool = characteristics.has_ability(TrampleAbility)
	if not combat.is_blocked(attacker_id):
		_assign(attacker_id, defending_player, power)  # CR 510.1a
		return null
	var blockers: Array[int] = combat.blockers_of(_state, attacker_id)
	if blockers.is_empty():
		# CR 510.1c: a blocked creature with no blockers left assigns no damage, unless it
		# has trample, when it assigns all of it to the player (CR 702.19e).
		if tramples:
			_assign(attacker_id, defending_player, power)
		return null
	if blockers.size() == 1 and (not tramples or power <= _lethal_damage(blockers[0])):
		_assign(attacker_id, MmReference.to_object(blockers[0]), power)  # CR 510.1c
		return null
	var recipients: Array[MmReference] = []
	var lethal: Array[int] = []
	for blocker_id: int in blockers:
		recipients.append(MmReference.to_object(blocker_id))
		lethal.append(_lethal_damage(blocker_id))
	if tramples:
		recipients.append(defending_player)
	return DivideCombatDamageDecision.new(attacker.controller_id, attacker_id, power, recipients, lethal)


## CR 702.19b: lethal damage counts damage already marked on the creature and damage
## assigned to it earlier in this step. Later (milestone 9): deathtouch (CR 702.2c).
func _lethal_damage(creature_id: int) -> int:
	var creature: MmGameObject = _state.object(creature_id)
	var already: int = creature.damage_marked
	for index: int in _recipients.size():
		if _recipients[index].is_object() and _recipients[index].id == creature_id:
			already += _amounts[index]
	return maxi(0, _state.characteristics_of(creature).toughness - already)


## CR 510.1d: each blocker that strikes in this step assigns all its combat damage to the
## attacker it blocks; one whose attacker has left assigns none.
func _assign_blockers_damage() -> void:
	for blocker_id: int in _state.combat.blockers(_state):
		if not _strikes_in_this_step(blocker_id):
			continue
		var power: int = _state.characteristics_of(_state.object(blocker_id)).power
		var blocked: Array[int] = _state.combat.attackers_blocked_by(_state, blocker_id)
		if power <= 0 or blocked.is_empty():
			continue
		# Later: a creature blocking several attackers divides its damage among them.
		assert(blocked.size() == 1, "A creature blocking several attackers is not supported yet.")
		_assign(blocker_id, MmReference.to_object(blocked[0]), power)


## CR 510.2: all combat damage in the step is dealt at once. State-based actions are then
## checked as players would receive priority (CR 510.3).
func _deal_assigned_damage() -> void:
	for index: int in _source_ids.size():
		if _amounts[index] > 0:
			_state.perform(DamageEvent.new(_source_ids[index], _recipients[index], _amounts[index], true))


func _assign(source_id: int, recipient: MmReference, amount: int) -> void:
	_source_ids.append(source_id)
	_recipients.append(recipient)
	_amounts.append(amount)
