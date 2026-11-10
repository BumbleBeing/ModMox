class_name AiPaymentPlanner
extends RefCounted
## Chooses how to pay one step of a mana cost (A157, A169): mana already in the pool first,
## then the source that is cheapest to lose. Colored symbols are paid before generic mana,
## with sources making that color, so a payment the engine offered is always finished.
## The Hero's auto-tapping can use it too, so both pay the same way.

## Tiers, cheapest to use first.
const _POOL_FOR_COLOR: int = 0
const _SOURCE_FOR_COLOR: int = 1
const _POOL: int = 2
const _LAND: int = 3
const _OTHER_SOURCE: int = 4
const _CREATURE: int = 5
const _UNUSABLE: int = 6


## The index of the action in [param decision] to take next, reading [param state].
static func choose(state: MmGameState, decision: PayManaDecision) -> int:
	var needed: Dictionary[int, int] = colors_needed_by_hand(state, decision.player_id)
	var pool: Array[MmMana] = state.player(decision.player_id).mana_pool()
	var best_index: int = 0
	var best_rank: Array[int] = [_UNUSABLE, 0, 0]
	for index: int in decision.actions.size():
		var rank: Array[int] = _rank(state, decision, decision.actions[index], pool, needed)
		if rank < best_rank:
			best_rank = rank
			best_index = index
	return best_index


## How many of each color's symbols the mana costs of [param player_id]'s hand hold.
static func colors_needed_by_hand(state: MmGameState, player_id: int) -> Dictionary[int, int]:
	var needed: Dictionary[int, int] = {}
	for card: MmGameObject in state.player(player_id).hand.objects():
		var cost: MmManaCost = state.characteristics_of(card).mana_cost
		if cost == null:
			continue
		for symbol: MmMana.Type in cost.symbols:
			needed[symbol] = needed.get(symbol, 0) + 1
	return needed


## The type of mana [param action] gives, or -1 if unknown.
static func mana_type_of(state: MmGameState, action: MmAction, pool: Array[MmMana]) -> int:
	if action is PayWithManaAction:
		return pool[(action as PayWithManaAction).unit_index].type
	var ability: ActivatedAbility = AiTiming.activated_ability_of(state, action)
	if ability != null:
		for effect: MmEffect in ability.effects:
			if effect is AddManaEffect:
				return (effect as AddManaEffect).mana_type
	return -1


## [tier, how much the rest of the hand needs that color, object ID], compared in order.
static func _rank(state: MmGameState, decision: PayManaDecision, action: MmAction, pool: Array[MmMana],
		needed: Dictionary[int, int]) -> Array[int]:
	var produced: int = mana_type_of(state, action, pool)
	var demand: int = needed.get(produced, 0)
	var is_pool: bool = action is PayWithManaAction
	if decision.remaining_symbols.has(produced as MmMana.Type):
		return [_POOL_FOR_COLOR if is_pool else _SOURCE_FOR_COLOR, demand, _object_id(action)]
	if not decision.remaining_symbols.is_empty() and decision.remaining_generic == 0:
		return [_UNUSABLE, 0, 0]
	if is_pool:
		return [_POOL, demand, 0]
	var source: MmGameObject = state.object((action as ActivateAbilityAction).object_id)
	var characteristics: MmCharacteristics = state.characteristics_of(source)
	if characteristics.has_card_type(MmCardTypes.CardType.CREATURE):
		return [_CREATURE, demand, source.id]
	if characteristics.has_card_type(MmCardTypes.CardType.LAND):
		return [_LAND, demand, source.id]
	return [_OTHER_SOURCE, demand, source.id]


static func _object_id(action: MmAction) -> int:
	return (action as ActivateAbilityAction).object_id if action is ActivateAbilityAction else 0
