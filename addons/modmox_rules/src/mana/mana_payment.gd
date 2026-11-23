class_name ManaPayment
extends RefCounted
## Rules for paying mana costs: which symbol a unit of mana pays, and whether a cost can be
## paid at all from a player's pool plus their available mana abilities.

## What symbol_paid_by() returns when the mana pays generic mana.
const PAYS_GENERIC: int = -2
## What symbol_paid_by() returns when the mana cannot pay anything still owed.
const CANNOT_PAY: int = -1
## What symbol_paid_by() returns when the mana pays a hybrid symbol: the first in
## [method MmManaCost.hybrid_index_in] order with its color.
const PAYS_HYBRID: int = -3


## The index in [param symbols] of the symbol a unit of [param type] should pay, PAYS_HYBRID,
## PAYS_GENERIC, or CANNOT_PAY. A matching plain symbol comes first, then a hybrid symbol
## of its color, then generic (ADR 0077): each of those is never worse than the next,
## because a plain symbol can be paid by one type, a hybrid symbol by two, and generic by
## any. Later: two hybrid symbols that share one color, as {B/R}{R/G} do, where the first
## is not always the one red should pay.
static func symbol_paid_by(type: MmMana.Type, symbols: Array[MmMana.Type], generic: int,
		hybrids: Array[Vector2i]) -> int:
	var index: int = symbols.find(type)
	if index != -1:
		return index
	if MmManaCost.hybrid_index_in(hybrids, type) != -1:
		return PAYS_HYBRID
	return PAYS_GENERIC if generic > 0 else CANNOT_PAY


## Whether [param player_id] could pay [param cost] right now with their pool and the mana
## abilities they could activate. Exact: each source permanent is used for at most one of
## its mana abilities, since they share the {T} cost, and mana of any color is any one color
## (ADR 0072). [param tapping_source_id] is the permanent whose own {T} the same cost will
## pay, or 0: it cannot tap for the mana too (pays_while_paying()).
static func can_afford(state: MmGameState, player_id: int, cost: MmManaCost, tapping_source_id: int = 0) -> bool:
	if cost == null:
		return false
	var available: Array[MmMana.Type] = []
	for unit: MmMana in state.player(player_id).mana_pool():
		available.append(unit.type)
	# A source pays once: its mana abilities share {T}, and a Treasure's one ability also
	# sacrifices it. Later: a mana ability that could be activated twice, as one costing
	# only life could, or two that do not share {T}, either of which could let one source
	# pay twice.
	var choices_per_source: Array = []
	for source: MmGameObject in sorted_sources_of(state, player_id):
		var choices: Array = []
		var abilities: Array[MmAbility] = state.characteristics_of(source).abilities
		for index: int in abilities.size():
			var ability: ActivatedAbility = abilities[index] as ActivatedAbility
			if ability == null or not pays_while_paying(state, source, ability, index, tapping_source_id):
				continue
			var context: MmEffectContext = MmEffectContext.new(player_id, source.id)
			var colors: Array[MmMana.Type] = ability.mana_types_to_choose()
			if colors.is_empty():
				choices.append(mana_made_by(state, ability, context))
			for color: MmMana.Type in colors:
				choices.append(mana_made_by(state, ability, context.with_chosen_mana_type(color)))
		if not choices.is_empty():
			choices_per_source.append(choices)
	return _covers_with_choices(available, choices_per_source, 0, cost)


## The types of mana [param ability] would add, one entry per unit, with the color
## [param context] says was chosen for mana of any color (ADR 0072), which adds nothing
## when none was.
static func mana_made_by(state: MmGameState, ability: ActivatedAbility, context: MmEffectContext) -> Array[MmMana.Type]:
	var made: Array[MmMana.Type] = []
	for effect: MmEffect in ability.effects:
		var add_mana: AddManaEffect = effect as AddManaEffect
		if add_mana == null or add_mana.type_added(context) == MmMana.NO_TYPE:
			continue
		for _index: int in add_mana.amount.evaluate(state, context):
			made.append(add_mana.type_added(context) as MmMana.Type)
	return made


## Whether [param ability], number [param ability_index] of [param source], is a mana
## ability that could be activated in the middle of paying a cost (CR 605.3a): its costs
## can be paid, and no Activation Restriction forbids it. "Only as a sorcery" always does
## there, since something is on the stack (CR 602.5d). The permanent
## [param tapping_source_id], whose own {T} is part of the cost being paid, cannot pay with
## a mana ability that taps it: one {T} pays once (CR 107.5, ADR 0048). Later: other costs
## two abilities of one source cannot both be paid, as sacrificing it for mana and for the
## cost.
static func pays_while_paying(state: MmGameState, source: MmGameObject, ability: ActivatedAbility, ability_index: int,
		tapping_source_id: int = 0) -> bool:
	if source.id == tapping_source_id and ability.has_tap_cost():
		return false
	if not ability.is_mana_ability() or not ability.works_in(state, source) or not ability.can_pay_costs(state, source):
		return false
	return not ability.is_sorcery_speed and not (ability.is_once_each_game and source.is_ability_spent(ability_index)) \
		and ability.is_attachment_allowed(state, source)


## Everything [param player_id] may activate abilities from (CR 113.6): the permanents they
## control in ID order, then their Emblems and Potions in ID order (ADR 0036), then the
## cards in their hand in ID order, whose abilities work there only when they say so
## (ActivatedAbility.works_in(), ADR 0059).
static func sorted_sources_of(state: MmGameState, player_id: int) -> Array[MmGameObject]:
	var held: Array[MmGameObject] = []
	for command_object: MmGameObject in state.command.objects():
		if command_object.controller_id == player_id:
			held.append(command_object)
	held.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	var hand: Array[MmGameObject] = []
	hand.assign(state.player(player_id).hand.objects())
	hand.sort_custom(func(a: MmGameObject, b: MmGameObject) -> bool: return a.id < b.id)
	return sorted_permanents_of(state, player_id) + held + hand


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
## each hybrid symbol by either of its types, and the generic amount by whatever is left.
static func _covers(available: Array[MmMana.Type], cost: MmManaCost) -> bool:
	var left: Array[MmMana.Type] = available.duplicate()
	for symbol: MmMana.Type in cost.symbols:
		var index: int = left.find(symbol)
		if index == -1:
			return false
		left.remove_at(index)
	return _covers_hybrid(left, cost.hybrid_symbols, 0, cost.generic)


## Whether [param left] pays the hybrid symbols of [param hybrids] from [param from] on and
## then [param generic]. Exact: each hybrid symbol tries both its halves (CR 107.4e).
static func _covers_hybrid(left: Array[MmMana.Type], hybrids: Array[Vector2i], from: int, generic: int) -> bool:
	if from == hybrids.size():
		return left.size() >= generic
	for half: int in [hybrids[from].x, hybrids[from].y]:
		var index: int = left.find(half as MmMana.Type)
		if index == -1:
			continue
		var rest: Array[MmMana.Type] = left.duplicate()
		rest.remove_at(index)
		if _covers_hybrid(rest, hybrids, from + 1, generic):
			return true
	return false
