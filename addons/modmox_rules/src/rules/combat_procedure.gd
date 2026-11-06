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
## The blockers that deal damage in this step, in ID order, and how many are assigned.
var _striking_blocker_ids: Array[int] = []
var _next_blocker: int = 0
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
	for blocker_id: int in combat.blockers(state):
		if procedure._strikes_in_this_step(blocker_id):
			procedure._striking_blocker_ids.append(blocker_id)
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
	copy._striking_blocker_ids = _striking_blocker_ids.duplicate()
	copy._next_blocker = _next_blocker
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
			var legal: Dictionary[int, Array] = {}
			var most: Dictionary[int, int] = {}
			var candidates: Array[int] = [] if attackers.is_empty() else _blocker_candidates(defending_id, attackers, legal, most)
			if not candidates.is_empty():
				return DeclareBlockersDecision.new(defending_id, candidates, attackers, legal, most)
		Kind.COMBAT_DAMAGE:
			while _next_attacker < _striking_attacker_ids.size():
				var division: DivideCombatDamageDecision = _assign_or_ask(_striking_attacker_ids[_next_attacker])
				if division != null:
					return division
				_next_attacker += 1
			while _next_blocker < _striking_blocker_ids.size():
				var blocker_division: DivideCombatDamageDecision = _assign_blocker_or_ask(_striking_blocker_ids[_next_blocker])
				if blocker_division != null:
					return blocker_division
				_next_blocker += 1
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
				# CR 508.1f, except with vigilance (CR 702.20b).
				if not _state.characteristics_of(_state.object(id)).has_ability(VigilanceAbility):
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
			_assign(division.source_id, division.recipients[index], amounts[index] as int)
		if _next_attacker < _striking_attacker_ids.size():
			_next_attacker += 1
		else:
			_next_blocker += 1
	else:
		assert(false, "Combat cannot answer %s." % decision.describe())


## CR 508.1a: untapped creatures the active player controls that are not summoning sick
## and do not have defender (CR 702.3b).
func _attacker_candidates() -> Array[int]:
	var candidates: Array[int] = []
	for permanent: MmGameObject in ManaPayment.sorted_permanents_of(_state, _state.active_player_id):
		if _is_untapped_creature(permanent) and not _state.is_summoning_sick(permanent) \
				and not _state.characteristics_of(permanent).has_ability(DefenderAbility):
			candidates.append(permanent.id)
	return candidates


## CR 509.1a: untapped creatures the defending player controls that can block at least
## one attacker. Fills [param legal] with the attackers each one can block, and
## [param most] with how many it may block (CR 509.1a, BlockAdditionalAbility).
func _blocker_candidates(defending_id: int, attackers: Array[int], legal: Dictionary[int, Array], most: Dictionary[int, int]) -> Array[int]:
	var candidates: Array[int] = []
	for permanent: MmGameObject in ManaPayment.sorted_permanents_of(_state, defending_id):
		if not _is_untapped_creature(permanent):
			continue
		var blockable: Array[int] = []
		for attacker_id: int in attackers:
			if _can_block(permanent, _state.object(attacker_id)):
				blockable.append(attacker_id)
		if blockable.is_empty():
			continue
		candidates.append(permanent.id)
		legal[permanent.id] = blockable
		var allowed: int = 1
		for ability: MmAbility in _state.characteristics_of(permanent).abilities:
			if ability is BlockAdditionalAbility:
				allowed += (ability as BlockAdditionalAbility).count
		most[permanent.id] = allowed
	return candidates


## CR 702.9b and 702.17b: a creature with flying can be blocked only by creatures with
## flying or reach. CR 702.16c: nor can a creature it has protection from block it.
func _can_block(blocker: MmGameObject, attacker: MmGameObject) -> bool:
	if ProtectionAbility.protects(_state, attacker, blocker.id):
		return false
	if not _state.characteristics_of(attacker).has_ability(FlyingAbility):
		return true
	var blocking: MmCharacteristics = _state.characteristics_of(blocker)
	return blocking.has_ability(FlyingAbility) or blocking.has_ability(ReachAbility)


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
	if blockers.size() == 1 and (not tramples or power <= _lethal_damage(blockers[0], attacker_id)):
		_assign(attacker_id, MmReference.to_object(blockers[0]), power)  # CR 510.1c
		return null
	var recipients: Array[MmReference] = []
	var lethal: Array[int] = []
	for blocker_id: int in blockers:
		recipients.append(MmReference.to_object(blocker_id))
		lethal.append(_lethal_damage(blocker_id, attacker_id))
	if tramples:
		recipients.append(defending_player)
	return DivideCombatDamageDecision.new(attacker.controller_id, attacker_id, power, recipients, lethal)


## CR 702.19b: lethal damage counts damage already marked on the creature and damage
## assigned to it earlier in this step. CR 702.2c: from a source with deathtouch, 1 damage
## is lethal.
func _lethal_damage(creature_id: int, source_id: int) -> int:
	var creature: MmGameObject = _state.object(creature_id)
	var already: int = creature.damage_marked
	for index: int in _recipients.size():
		if _recipients[index].is_object() and _recipients[index].id == creature_id:
			already += _amounts[index]
	var lethal: int = maxi(0, _state.characteristics_of(creature).toughness - already)
	if lethal > 0 and _state.characteristics_of(_state.object(source_id)).has_ability(DeathtouchAbility):
		return 1
	return lethal


## CR 510.1d: a blocker that strikes in this step assigns its combat damage to the
## attacker it blocks; one whose attackers have all left assigns none. A creature blocking
## several attackers has its damage divided among them by its controller. Returns that
## decision, or null once the damage is assigned.
func _assign_blocker_or_ask(blocker_id: int) -> DivideCombatDamageDecision:
	var blocker: MmGameObject = _state.object(blocker_id)
	var power: int = _state.characteristics_of(blocker).power
	var blocked: Array[int] = _state.combat.attackers_blocked_by(_state, blocker_id)
	if power <= 0 or blocked.is_empty():
		return null
	if blocked.size() == 1:
		_assign(blocker_id, MmReference.to_object(blocked[0]), power)
		return null
	var recipients: Array[MmReference] = []
	var lethal: Array[int] = []
	for attacker_id: int in blocked:
		recipients.append(MmReference.to_object(attacker_id))
		lethal.append(_lethal_damage(attacker_id, blocker_id))
	return DivideCombatDamageDecision.new(blocker.controller_id, blocker_id, power, recipients, lethal)


## CR 510.2: all combat damage in the step is dealt at once. State-based actions are then
## checked as players would receive priority (CR 510.3). Dealing it is this step's last
## action, so if its batch waits for a replacement choice, the turn procedure asks it and
## the batch carries on from there (A143).
func _deal_assigned_damage() -> void:
	var damage: Array[MmEvent] = []
	for index: int in _source_ids.size():
		if _amounts[index] > 0:
			damage.append(DamageEvent.new(_source_ids[index], _recipients[index], _amounts[index], true))
	if not damage.is_empty():
		_state.perform_resumably(damage)


func _assign(source_id: int, recipient: MmReference, amount: int) -> void:
	_source_ids.append(source_id)
	_recipients.append(recipient)
	_amounts.append(amount)
