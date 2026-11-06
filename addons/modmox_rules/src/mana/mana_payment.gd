class_name ManaPayment
extends RefCounted
## Rules for paying mana costs: which symbol a unit of mana pays, and whether a cost can be
## paid at all from a player's pool plus their available mana abilities.

## What symbol_paid_by() returns when the mana pays generic mana.
const PAYS_GENERIC: int = -2
## What symbol_paid_by() returns when the mana cannot pay anything still owed.
const CANNOT_PAY: int = -1


## The index in [param symbols] of the symbol a unit of [param type] should pay, PAYS_GENERIC,
## or CANNOT_PAY. A matching symbol always comes first: with only plain symbols that is
## never worse, because a symbol can be paid only by its own type and generic by anything.
static func symbol_paid_by(type: MmMana.Type, symbols: Array[MmMana.Type], generic: int) -> int:
	var index: int = symbols.find(type)
	if index != -1:
		return index
	return PAYS_GENERIC if generic > 0 else CANNOT_PAY


## Whether [param player_id] could pay [param cost] right now with their pool and the mana
## abilities they could activate. Exact: each source permanent is used for at most one of
## its mana abilities, since they share the {T} cost.
static func can_afford(state: MmGameState, player_id: int, cost: MmManaCost) -> bool:
	if cost == null:
		return false
	var available: Array[MmMana.Type] = []
	for unit: MmMana in state.player(player_id).mana_pool():
		available.append(unit.type)
	# Later: costs other than {T} on mana abilities, which could let one source pay twice.
	var choices_per_source: Array = []
	for permanent: MmGameObject in sorted_permanents_of(state, player_id):
		var choices: Array = []
		var abilities: Array[MmAbility] = state.characteristics_of(permanent).abilities
		for index: int in abilities.size():
			var ability: ActivatedAbility = abilities[index] as ActivatedAbility
			if ability != null and ability.is_mana_ability() and ability.can_pay_costs(state, permanent):
				choices.append(mana_made_by(state, ability, MmEffectContext.new(player_id, permanent.id)))
		if not choices.is_empty():
			choices_per_source.append(choices)
	return _covers_with_choices(available, choices_per_source, 0, cost)


## The types of mana [param ability] would add, one entry per unit.
static func mana_made_by(state: MmGameState, ability: ActivatedAbility, context: MmEffectContext) -> Array[MmMana.Type]:
	var made: Array[MmMana.Type] = []
	for effect: MmEffect in ability.effects:
		var add_mana: AddManaEffect = effect as AddManaEffect
		if add_mana != null:
			for _index: int in add_mana.amount.evaluate(state, context):
				made.append(add_mana.mana_type)
	return made


## The permanents [param player_id] controls, in ID order.
static func sorted_permanents_of(state: MmGameState, player_id: int) -> Array[MmGameObject]:
	var result: Array[MmGameObject] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.controller_id == player_id:
			result.append(permanent)
	result.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return result


## Tries one choice per source, in order, and checks the result covers the cost. More mana
## never hurts, so every source is always used for one of its abilities.
static func _covers_with_choices(available: Array[MmMana.Type], choices_per_source: Array, source_index: int, cost: MmManaCost) -> bool:
	if source_index == choices_per_source.size():
		return _covers(available, cost)
	for choice: Variant in choices_per_source[source_index]:
		var with_choice: Array[MmMana.Type] = available.duplicate()
		with_choice.append_array(choice)
		if _covers_with_choices(with_choice, choices_per_source, source_index + 1, cost):
			return true
	return false


## Whether the mana in [param available] can pay [param cost]: every symbol by its own type,
## and the generic amount by whatever is left.
static func _covers(available: Array[MmMana.Type], cost: MmManaCost) -> bool:
	var left: Array[MmMana.Type] = available.duplicate()
	for symbol: MmMana.Type in cost.symbols:
		var index: int = left.find(symbol)
		if index == -1:
			return false
		left.remove_at(index)
	return left.size() >= cost.generic
