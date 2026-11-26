class_name ManaPaymentProgress
extends RefCounted
## A mana cost being paid one step at a time (CR 601.2g-h): what one player still owes, the
## PayManaDecision that asks for the next step, and how its answer pays. Casting pays its
## mana this way, and so does a "you may pay {X}" as it resolves (ADR 0061), so the two pay
## alike.

var player_id: int
var remaining_generic: int = 0
var remaining_symbols: Array[MmMana.Type] = []
## The hybrid symbols still owed (CR 107.4e, ADR 0077).
var remaining_hybrid_symbols: Array[Vector2i] = []
## The permanent whose own {T} is part of the cost this mana is paid for, or 0. It cannot
## tap for this mana too ([method ManaPayment.pays_while_paying]).
var tapping_source_id: int = 0
## Whether this is the mana of a spell with improvise (CR 702.126a, engine ADR 0099), so
## each untapped artifact the payer controls may pay {1} of the generic mana owed.
var improvises: bool = false


func _init(paying_player_id: int, generic: int = 0, symbols: Array[MmMana.Type] = [],
		hybrids: Array[Vector2i] = []) -> void:
	player_id = paying_player_id
	remaining_generic = generic
	remaining_symbols = symbols.duplicate()
	remaining_hybrid_symbols = hybrids.duplicate()


## [param cost] owed by [param paying_player_id], or nothing owed for a null cost.
static func of_cost(paying_player_id: int, cost: MmManaCost) -> ManaPaymentProgress:
	if cost == null:
		return ManaPaymentProgress.new(paying_player_id)
	return ManaPaymentProgress.new(paying_player_id, cost.generic, cost.symbols, cost.hybrid_symbols)


func copy() -> ManaPaymentProgress:
	var progress: ManaPaymentProgress = ManaPaymentProgress.new(player_id, remaining_generic, remaining_symbols,
		remaining_hybrid_symbols)
	progress.tapping_source_id = tapping_source_id
	progress.improvises = improvises
	return progress


func is_paid() -> bool:
	return remaining_generic == 0 and remaining_symbols.is_empty() and remaining_hybrid_symbols.is_empty()


## The next step of the payment, or null when nothing on offer can pay what is still owed.
func decision(state: MmGameState) -> PayManaDecision:
	var options: Array[MmAction] = _options(state)
	if options.is_empty():
		return null
	return PayManaDecision.new(player_id, options, remaining_generic, remaining_symbols, remaining_hybrid_symbols)


## Pays with the action at [param index] of [param paying], a validated answer.
func apply_answer(state: MmGameState, paying: PayManaDecision, index: int) -> void:
	var action: MmAction = paying.actions[index]
	if action is PayWithManaAction:
		_spend(state, (action as PayWithManaAction).unit_index)
	elif action is ActivateAbilityAction:
		_pay_with_mana_ability(state, action as ActivateAbilityAction)
	elif action is ImproviseAction:
		# CR 702.126a: the artifact taps and pays for {1}.
		state.perform(TapEvent.new((action as ImproviseAction).object_id))
		remaining_generic -= 1


## Unit spends from the pool first, then mana abilities, then improvise's artifacts, each in
## a fixed order (ADR 0012).
## Only what pays something still owed is offered, except that a mana ability adding mana
## of any color is offered in every color, in WUBRG order, once any color would pay
## something (ADR 0072): mana that pays nothing goes to the pool (CR 605.3a).
func _options(state: MmGameState) -> Array[MmAction]:
	var options: Array[MmAction] = []
	var pool: Array[MmMana] = state.player(player_id).mana_pool()
	for unit_index: int in pool.size():
		if _paid_by(pool[unit_index].type) != ManaPayment.CANNOT_PAY:
			options.append(PayWithManaAction.new(unit_index))
	for source: MmGameObject in ManaPayment.sorted_sources_of(state, player_id):
		var abilities: Array[MmAbility] = state.characteristics_of(source).abilities
		for ability_index: int in abilities.size():
			var ability: ActivatedAbility = abilities[ability_index] as ActivatedAbility
			if ability == null \
					or not ManaPayment.pays_while_paying(state, source, ability, ability_index, tapping_source_id):
				continue
			if ability.mana_cost != null:
				continue  # Later: mana abilities with mana in their cost.
			var activations: Array[MmAction] = ActivateAbilityAction.each_for(source.id, ability_index, ability)
			for activation: MmAction in activations:
				if _pays_something(state, ability, activation as ActivateAbilityAction):
					options.append_array(activations)
					break
	if improvises and remaining_generic > 0:
		# CR 702.126a, engine ADR 0099. Later: improvise only once the mana abilities are
		# done, once a mana ability makes more for tapped artifacts; until then the order
		# changes nothing.
		for artifact: MmGameObject in ManaPayment.improvisers_of(state, player_id):
			options.append(ImproviseAction.new(artifact.id))
	return options


## Whether some of the mana [param activation] of [param ability] would make pays something
## still owed.
func _pays_something(state: MmGameState, ability: ActivatedAbility, activation: ActivateAbilityAction) -> bool:
	var context: MmEffectContext = MmEffectContext.new(player_id, activation.object_id)
	context = context.with_chosen_mana_type(activation.mana_type)
	for type: MmMana.Type in ManaPayment.mana_made_by(state, ability, context):
		if _paid_by(type) != ManaPayment.CANNOT_PAY:
			return true
	return false


## Spends the pool unit at [param unit_index] on whatever it should pay.
func _spend(state: MmGameState, unit_index: int) -> void:
	var type: MmMana.Type = state.player(player_id).mana_pool()[unit_index].type
	var paid: int = _paid_by(type)
	assert(paid != ManaPayment.CANNOT_PAY, "That mana cannot pay anything still owed.")
	state.perform(ManaSpentEvent.new(player_id, unit_index))
	if paid == ManaPayment.PAYS_GENERIC:
		remaining_generic -= 1
	elif paid == ManaPayment.PAYS_HYBRID:
		remaining_hybrid_symbols.remove_at(MmManaCost.hybrid_index_in(remaining_hybrid_symbols, type))
	else:
		remaining_symbols.remove_at(paid)


## CR 605.3a: mana abilities may be activated while paying. The new mana goes straight to
## the cost; whatever the cost no longer needs stays in the pool, as mana of any color does
## in a color owed nothing.
func _pay_with_mana_ability(state: MmGameState, action: ActivateAbilityAction) -> void:
	var source: MmGameObject = state.object(action.object_id)
	var ability: ActivatedAbility = state.characteristics_of(source).abilities[action.ability_index] as ActivatedAbility
	var pool_size_before: int = state.player(player_id).mana_pool().size()
	if ability.is_activated_only_once():
		state.perform(AbilitySpentEvent.of(ability, source.id, action.ability_index))  # CR 602.5b
	ability.pay_costs(state, source)
	var context: MmEffectContext = MmEffectContext.new(source.controller_id, source.id)
	ability.resolve_effects(state, context.with_chosen_mana_type(action.mana_type))  # ADR 0072
	var unit_index: int = pool_size_before
	while unit_index < state.player(player_id).mana_pool().size():
		var type: MmMana.Type = state.player(player_id).mana_pool()[unit_index].type
		if _paid_by(type) == ManaPayment.CANNOT_PAY:
			unit_index += 1
		else:
			_spend(state, unit_index)


## What a unit of [param type] would pay of what is still owed (ManaPayment.symbol_paid_by()).
func _paid_by(type: MmMana.Type) -> int:
	return ManaPayment.symbol_paid_by(type, remaining_symbols, remaining_generic, remaining_hybrid_symbols)
