class_name AiQuickCombat
extends RefCounted
## A fast guess at who survives a one-on-one fight, from power, toughness, first strike,
## deathtouch and indestructible. Used by CHEAP Agents, which must not simulate (A178); a
## FULL Agent asks the Combat Oracle, which runs the engine's own combat instead.


## [attacker dies, blocker dies] if [param blocker_id] blocks [param attacker_id] alone.
static func duel(state: MmGameState, attacker_id: int, blocker_id: int) -> Array[bool]:
	var attacker: MmGameObject = state.object(attacker_id)
	var blocker: MmGameObject = state.object(blocker_id)
	var attacker_kills: bool = _kills(state, attacker, blocker)
	var blocker_kills: bool = _kills(state, blocker, attacker)
	var attacker_first: bool = _strikes_first(state, attacker) and not _strikes_first(state, blocker)
	var blocker_first: bool = _strikes_first(state, blocker) and not _strikes_first(state, attacker)
	if attacker_first and attacker_kills:
		blocker_kills = false
	if blocker_first and blocker_kills:
		attacker_kills = false
	var result: Array[bool] = [blocker_kills, attacker_kills]
	return result


static func _kills(state: MmGameState, source: MmGameObject, victim: MmGameObject) -> bool:
	var dealer: MmCharacteristics = state.characteristics_of(source)
	var target: MmCharacteristics = state.characteristics_of(victim)
	if dealer.power <= 0 or target.has_ability(IndestructibleAbility):
		return false
	if dealer.has_ability(DeathtouchAbility):
		return true
	return dealer.power >= target.toughness - victim.damage_marked


static func _strikes_first(state: MmGameState, creature: MmGameObject) -> bool:
	var characteristics: MmCharacteristics = state.characteristics_of(creature)
	return characteristics.has_ability(FirstStrikeAbility) or characteristics.has_ability(DoubleStrikeAbility)
