class_name AiPaymentPlanner
extends RefCounted
## Chooses how to pay one step of a mana cost (A157, A169): mana already in the pool first,
## then the source that is cheapest to lose: a land, then another source, then a creature,
## then a source whose mana ability taps another creature too, as Jaspera Sentinel's does
## (engine ADR 0105), then a source its mana ability sacrifices, such as a Treasure, which is
## lost for good. The creature such an ability taps is the one least missed (choose_tapped()).
## Colored symbols, hybrid ones too (ADR 0077), are paid before generic mana, with sources
## making that color, so a payment the engine offered is always finished; mana of any color
## is made only in a color that pays something (ADR 0072). An artifact tapped for improvise
## (engine ADR 0099) pays generic mana only: one that loses nothing by it, with no {T}
## ability and no body to block with, before any land; another as a source of its kind.
## Auto-tap (game glossary) pays for the Hero with it too, so both players pay the same way.

## Tiers, cheapest to use first.
const _POOL_FOR_COLOR: int = 0
const _SOURCE_FOR_COLOR: int = 1
const _POOL: int = 2
const _IMPROVISE: int = 3
const _LAND: int = 4
const _OTHER_SOURCE: int = 5
const _CREATURE: int = 6
const _TAPS_ANOTHER: int = 7
const _SACRIFICED: int = 8
const _UNUSABLE: int = 9


## The index of the action in [param decision] to take next, reading [param state].
static func choose(state: MmGameState, decision: PayManaDecision) -> int:
	var needed: Dictionary[int, int] = colors_needed_by_hand(state, decision.player_id)
	var pool: Array[MmMana] = state.player(decision.player_id).mana_pool()
	var best_index: int = 0
	var best_rank: Array[int] = [_UNUSABLE, 0, 0, 0]
	for index: int in decision.actions.size():
		var rank: Array[int] = _rank(state, decision, decision.actions[index], pool, needed)
		if rank < best_rank:
			best_rank = rank
			best_index = index
	return best_index


## The permanents to tap for a mana ability's cost that asks which (engine ADR 0105), as
## Jaspera Sentinel's "Tap an untapped creature you control": first one with no {T} ability
## of its own, which could make mana or do something else, then the least valuable, so a
## creature with summoning sickness, which could not attack anyway, before one that could
## (AiBoardEvaluator.permanent_value()), then the oldest.
static func choose_tapped(state: MmGameState, decision: ChoosePermanentsDecision, profile: AiProfile) -> Array[int]:
	var ranks: Dictionary[int, Array] = {}
	for id: int in decision.candidate_ids:
		var permanent: MmGameObject = state.object(id)
		ranks[id] = [1 if _has_tap_ability(state.characteristics_of(permanent)) else 0,
			AiBoardEvaluator.permanent_value(state, permanent, profile), id]
	var ranked: Array[int] = decision.candidate_ids.duplicate()
	ranked.sort_custom(func(a: int, b: int) -> bool: return ranks[a] < ranks[b])
	var chosen: Array[int] = ranked.slice(0, decision.count)
	chosen.sort()
	return chosen


## How many of each color's symbols the mana costs of [param player_id]'s hand hold.
static func colors_needed_by_hand(state: MmGameState, player_id: int) -> Dictionary[int, int]:
	var needed: Dictionary[int, int] = {}
	for card: MmGameObject in state.player(player_id).hand.objects():
		var cost: MmManaCost = state.characteristics_of(card).mana_cost
		if cost == null:
			continue
		for symbol: MmMana.Type in types_wanted_by(cost):
			needed[symbol] = needed.get(symbol, 0) + 1
	return needed


## The type of mana each of [param cost]'s symbols wants, once for each symbol, and both of
## a hybrid symbol's, since either pays it (ADR 0077).
static func types_wanted_by(cost: MmManaCost) -> Array[MmMana.Type]:
	var wanted: Array[MmMana.Type] = cost.symbols.duplicate()
	for hybrid: Vector2i in cost.hybrid_symbols:
		wanted.append(hybrid.x as MmMana.Type)
		wanted.append(hybrid.y as MmMana.Type)
	return wanted


## The type of mana [param action] gives, or -1 if unknown.
static func mana_type_of(state: MmGameState, action: MmAction, pool: Array[MmMana]) -> int:
	if action is ImproviseAction:
		return -1  # It pays generic mana, of no type.
	if action is PayWithManaAction:
		return pool[(action as PayWithManaAction).unit_index].type
	if action is ActivateAbilityAction and (action as ActivateAbilityAction).mana_type != MmMana.NO_TYPE:
		return (action as ActivateAbilityAction).mana_type  # ADR 0072: the color it was offered for.
	var ability: ActivatedAbility = AiTiming.activated_ability_of(state, action)
	if ability != null:
		for effect: MmEffect in ability.effects:
			if effect is AddManaEffect:
				return (effect as AddManaEffect).mana_type
	return -1


## [tier, kind of source, how much the rest of the hand needs that color, object ID], compared
## in order. A color is paid by a land before another source, and by a creature last, as
## generic mana is: a creature left untapped can still block.
static func _rank(state: MmGameState, decision: PayManaDecision, action: MmAction, pool: Array[MmMana],
		needed: Dictionary[int, int]) -> Array[int]:
	var produced: int = mana_type_of(state, action, pool)
	var demand: int = needed.get(produced, 0)
	var is_pool: bool = action is PayWithManaAction
	if action is ImproviseAction:
		return [_improvise_kind(state, (action as ImproviseAction).object_id), 0, 0, (action as ImproviseAction).object_id]
	var kind: int = _POOL if is_pool else _kind_of(state, action as ActivateAbilityAction)
	if decision.remaining_symbols.has(produced as MmMana.Type) \
			or MmManaCost.hybrid_index_in(decision.remaining_hybrid_symbols, produced as MmMana.Type) != -1:
		return [_POOL_FOR_COLOR if is_pool else _SOURCE_FOR_COLOR, kind, demand, _object_id(action)]
	if (not decision.remaining_symbols.is_empty() or not decision.remaining_hybrid_symbols.is_empty()) \
			and decision.remaining_generic == 0:
		return [_UNUSABLE, 0, 0, 0]
	return [kind, 0, demand, _object_id(action)]


## The tier of the source [param action] taps: one its mana ability sacrifices, one whose
## mana ability taps another creature too, a land, a creature, or anything else.
static func _kind_of(state: MmGameState, action: ActivateAbilityAction) -> int:
	var taps_another: bool = false
	for cost: MmCost in AiTiming.activated_ability_of(state, action).costs:
		if cost is SacrificeThisCost:
			return _SACRIFICED
		taps_another = taps_another or cost is TapCreaturesCost
	if taps_another:
		return _TAPS_ANOTHER
	var characteristics: MmCharacteristics = state.characteristics_of(state.object(action.object_id))
	if characteristics.has_card_type(MmCardTypes.CardType.CREATURE):
		return _CREATURE
	if characteristics.has_card_type(MmCardTypes.CardType.LAND):
		return _LAND
	return _OTHER_SOURCE


## The tier of tapping [param object_id] for improvise: a creature last but a sacrifice, an
## artifact with a {T} ability as another source, and any other before a land.
static func _improvise_kind(state: MmGameState, object_id: int) -> int:
	var characteristics: MmCharacteristics = state.characteristics_of(state.object(object_id))
	if characteristics.has_card_type(MmCardTypes.CardType.CREATURE):
		return _CREATURE
	return _OTHER_SOURCE if _has_tap_ability(characteristics) else _IMPROVISE


## Whether some activated ability of [param characteristics] has {T} in its cost.
static func _has_tap_ability(characteristics: MmCharacteristics) -> bool:
	for ability: MmAbility in characteristics.abilities:
		var activated: ActivatedAbility = ability as ActivatedAbility
		if activated == null:
			continue
		for cost: MmCost in activated.costs:
			if cost is TapCost:
				return true
	return false


static func _object_id(action: MmAction) -> int:
	return (action as ActivateAbilityAction).object_id if action is ActivateAbilityAction else 0
