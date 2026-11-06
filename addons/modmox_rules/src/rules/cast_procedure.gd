class_name CastProcedure
extends RefCounted
## Casting a spell (CR 601.2) or activating an ability that uses the stack (CR 602.2):
## announce it onto the stack, choose its targets, then pay its cost one step at a time.
## When the payment can no longer be finished it reports itself stuck, and the engine
## rewinds the whole attempt (CR 728, ADR 0015).

enum Stage { CHOOSE_TARGETS, PAY_MANA, DONE, STUCK }

var _state: MmGameState
var _player_id: int
var _stack_object_id: int
## The permanent whose ability is being activated, or 0 for a spell.
var _source_object_id: int = 0
var _ability: MmAbility
var _target_specs: Array[TargetSpec] = []
var _next_target: int = 0
var _remaining_generic: int = 0
var _remaining_symbols: Array[MmMana.Type] = []
var _stage: Stage = Stage.CHOOSE_TARGETS


## Begins casting [param card] from [param player_id]'s hand: CR 601.2a moves it to the stack.
static func cast_spell(state: MmGameState, player_id: int, card: MmGameObject) -> CastProcedure:
	var characteristics: MmCharacteristics = state.characteristics_of(card)
	var procedure: CastProcedure = CastProcedure.new(state, player_id)
	var spell: SpellAbility = spell_ability_of(characteristics)
	procedure._ability = spell
	if spell != null:
		procedure._target_specs = spell.targets
	# Later: cost increases, reductions and additional costs (CR 601.2f).
	procedure._remaining_generic = characteristics.mana_cost.generic
	procedure._remaining_symbols = characteristics.mana_cost.symbols.duplicate()
	var move: ZoneChangeEvent = ZoneChangeEvent.new(card, state.stack, MmZone.BOTTOM, ZoneChangeEvent.Reason.CAST)
	state.perform(move)
	procedure._stack_object_id = move.new_object_id
	return procedure


## Begins activating ability [param ability_index] of [param source]: CR 602.2a puts the
## ability on the stack.
static func activate_ability(state: MmGameState, player_id: int, source: MmGameObject, ability_index: int) -> CastProcedure:
	var procedure: CastProcedure = CastProcedure.new(state, player_id)
	var ability: ActivatedAbility = state.characteristics_of(source).abilities[ability_index] as ActivatedAbility
	procedure._ability = ability
	procedure._target_specs = ability.targets
	procedure._source_object_id = source.id
	# Later: mana in activation costs, such as "{1}, {T}: ...".
	var put: AbilityPutOnStackEvent = AbilityPutOnStackEvent.new(source.id, ability_index, player_id)
	state.perform(put)
	procedure._stack_object_id = put.new_object_id
	return procedure


## The spell ability of an instant or sorcery, or null, as for a creature with no spell
## ability.
static func spell_ability_of(characteristics: MmCharacteristics) -> SpellAbility:
	for ability: MmAbility in characteristics.abilities:
		if ability is SpellAbility:
			return ability as SpellAbility
	return null


func _init(state: MmGameState, player_id: int) -> void:
	_state = state
	_player_id = player_id


## A copy of this procedure working on [param state], a copy of the original state.
func copy_for(state: MmGameState) -> CastProcedure:
	var copy: CastProcedure = CastProcedure.new(state, _player_id)
	copy._stack_object_id = _stack_object_id
	copy._source_object_id = _source_object_id
	copy._ability = _ability
	copy._target_specs = _target_specs
	copy._next_target = _next_target
	copy._remaining_generic = _remaining_generic
	copy._remaining_symbols = _remaining_symbols.duplicate()
	copy._stage = _stage
	return copy


func is_done() -> bool:
	return _stage == Stage.DONE


func is_stuck() -> bool:
	return _stage == Stage.STUCK


## The next choice the caster must make, or null once the procedure is done or stuck.
func next_decision() -> MmPendingDecision:
	while true:
		match _stage:
			Stage.CHOOSE_TARGETS:
				if _next_target < _target_specs.size():
					var legal: Array[MmReference] = _target_specs[_next_target].legal_targets(_state, _context())
					return ChooseTargetDecision.new(_player_id, _stack_object_id, _next_target, legal)
				_stage = Stage.PAY_MANA
			Stage.PAY_MANA:
				if _remaining_generic == 0 and _remaining_symbols.is_empty():
					_finish()
					_stage = Stage.DONE
					return null
				var options: Array[MmAction] = _payment_options()
				if options.is_empty():
					_stage = Stage.STUCK
					return null
				return PayManaDecision.new(_player_id, options, _remaining_generic, _remaining_symbols)
			_:
				return null
	return null


## Applies an already-validated [param answer] to [param decision].
func apply_answer(decision: MmPendingDecision, answer: Variant) -> void:
	var index: int = answer
	if decision is ChooseTargetDecision:
		var chosen: MmReference = (decision as ChooseTargetDecision).candidates[index]
		_state.perform(TargetChosenEvent.new(_stack_object_id, _next_target, chosen))
		_next_target += 1
	elif decision is PayManaDecision:
		var action: MmAction = (decision as PayManaDecision).actions[index]
		if action is PayWithManaAction:
			_spend((action as PayWithManaAction).unit_index)
		elif action is ActivateAbilityAction:
			_pay_with_mana_ability(action as ActivateAbilityAction)
	else:
		assert(false, "Casting cannot answer %s." % decision.describe())


## Unit spends from the pool first, then mana abilities, each in a fixed order (ADR 0012).
func _payment_options() -> Array[MmAction]:
	var options: Array[MmAction] = []
	var pool: Array[MmMana] = _state.player(_player_id).mana_pool()
	for unit_index: int in pool.size():
		if ManaPayment.symbol_paid_by(pool[unit_index].type, _remaining_symbols, _remaining_generic) != ManaPayment.CANNOT_PAY:
			options.append(PayWithManaAction.new(unit_index))
	for permanent: MmGameObject in ManaPayment.sorted_permanents_of(_state, _player_id):
		var abilities: Array[MmAbility] = _state.characteristics_of(permanent).abilities
		for ability_index: int in abilities.size():
			var ability: ActivatedAbility = abilities[ability_index] as ActivatedAbility
			if ability == null or not ability.is_mana_ability() or not ability.can_pay_costs(_state, permanent):
				continue
			var context: MmEffectContext = MmEffectContext.new(_player_id, permanent.id)
			for type: MmMana.Type in ManaPayment.mana_made_by(_state, ability, context):
				if ManaPayment.symbol_paid_by(type, _remaining_symbols, _remaining_generic) != ManaPayment.CANNOT_PAY:
					options.append(ActivateAbilityAction.new(permanent.id, ability_index))
					break
	return options


## Spends the pool unit at [param unit_index] on whatever it should pay.
func _spend(unit_index: int) -> void:
	var type: MmMana.Type = _state.player(_player_id).mana_pool()[unit_index].type
	var paid: int = ManaPayment.symbol_paid_by(type, _remaining_symbols, _remaining_generic)
	assert(paid != ManaPayment.CANNOT_PAY, "That mana cannot pay anything still owed.")
	_state.perform(ManaSpentEvent.new(_player_id, unit_index))
	if paid == ManaPayment.PAYS_GENERIC:
		_remaining_generic -= 1
	else:
		_remaining_symbols.remove_at(paid)


## CR 605.3a: mana abilities may be activated while paying. The new mana goes straight to
## the cost; whatever the cost no longer needs stays in the pool.
func _pay_with_mana_ability(action: ActivateAbilityAction) -> void:
	var source: MmGameObject = _state.object(action.object_id)
	var ability: ActivatedAbility = _state.characteristics_of(source).abilities[action.ability_index] as ActivatedAbility
	var pool_size_before: int = _state.player(_player_id).mana_pool().size()
	ability.pay_costs(_state, source)
	ability.resolve_effects(_state, MmEffectContext.new(source.controller_id, source.id))
	var unit_index: int = pool_size_before
	while unit_index < _state.player(_player_id).mana_pool().size():
		var type: MmMana.Type = _state.player(_player_id).mana_pool()[unit_index].type
		if ManaPayment.symbol_paid_by(type, _remaining_symbols, _remaining_generic) == ManaPayment.CANNOT_PAY:
			unit_index += 1
		else:
			_spend(unit_index)


## CR 601.2h and 602.2b: pay the remaining, non-mana costs. The spell or ability is now
## cast or activated.
func _finish() -> void:
	var activated: ActivatedAbility = _ability as ActivatedAbility
	if activated != null:
		activated.pay_costs(_state, _state.object(_source_object_id))
	# Later (milestone 8): "whenever you cast" triggers (CR 601.2i).


func _context() -> MmEffectContext:
	return MmEffectContext.new(_player_id, _stack_object_id)
