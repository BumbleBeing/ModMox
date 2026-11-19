class_name CastProcedure
extends RefCounted
## Casting a spell (CR 601.2) or activating an ability that uses the stack (CR 602.2):
## announce it onto the stack, choose its mode if it is modal, choose its targets, make
## any choice a part of its cost asks (paying that part then), then pay its mana one step
## at a time and the rest of its cost. A card cast from its graveyard is cast for its
## flashback cost (CR 702.34a), and one cast from the top of its library uses up a
## permission to (ADR 0054).
## When the payment can no longer be finished it reports itself stuck, and the engine
## rewinds the whole attempt (CR 728, ADR 0015).

enum Stage { CHOOSE_MODE, CHOOSE_TARGETS, PAY_MANA, DONE, STUCK, PAY_COSTS }

var _state: MmGameState
var _player_id: int
var _stack_object_id: int
## The permanent, Emblem or Potion whose ability is being activated, or 0 for a spell, and
## the ability's place among its abilities.
var _source_object_id: int = 0
var _ability_index: int = 0
var _ability: MmAbility
var _target_requirements: Array[TargetRequirement] = []
var _next_target: int = 0
var _remaining_generic: int = 0
var _remaining_symbols: Array[MmMana.Type] = []
var _stage: Stage = Stage.CHOOSE_TARGETS
## The parts of the cost that are not mana (CR 601.2h): an ability's costs, or a flashback
## cost's. Those that ask a choice are paid as it is answered, the rest once the mana is.
var _costs: Array[MmCost] = []
var _next_cost: int = 0
var _paid_cost_indexes: Array[int] = []


## Begins casting [param card] from [param player_id]'s hand, from their graveyard for its
## flashback cost, or from the top of their library with a permission, which is used now
## (CR 601.3, ADR 0054): CR 601.2a moves it to the stack.
static func cast_spell(state: MmGameState, player_id: int, card: MmGameObject) -> CastProcedure:
	var characteristics: MmCharacteristics = state.characteristics_of(card)
	var procedure: CastProcedure = CastProcedure.new(state, player_id)
	var spell: SpellAbility = spell_ability_of(characteristics)
	procedure._ability = spell
	if spell != null and spell.is_modal():
		procedure._stage = Stage.CHOOSE_MODE  # CR 601.2b: the mode comes before targets.
	elif spell != null:
		procedure._target_requirements = spell.targets
	# CR 601.2f: the total cost is fixed now. Choosing modes and targets first, as the rules
	# order it, can change nothing it counts. Later: cost increases and additional costs.
	var mana: MmManaCost = mana_to_pay(state, player_id, card)
	var is_flashback: bool = card.zone().kind == MmZone.Kind.GRAVEYARD
	if is_flashback:
		procedure._costs = flashback_of(characteristics).costs
	if mana != null:
		procedure._remaining_generic = mana.generic
		procedure._remaining_symbols = mana.symbols.duplicate()
	if card.zone().kind == MmZone.Kind.LIBRARY:
		var permission: Array[int] = top_of_library_permission(state, player_id, card)
		assert(not permission.is_empty(), "Nothing lets player %d cast %s from their library." % [player_id, characteristics.name])
		state.perform(CastPermissionUsedEvent.new(permission[0], permission[1], characteristics.name))
	var move: ZoneChangeEvent = ZoneChangeEvent.new(card, state.stack, MmZone.BOTTOM, ZoneChangeEvent.Reason.CAST)
	move.cast_with_flashback = is_flashback
	state.perform(move)
	procedure._stack_object_id = move.new_object_id
	return procedure


## Begins activating ability [param ability_index] of [param source]: CR 602.2a puts the
## ability on the stack.
static func activate_ability(state: MmGameState, player_id: int, source: MmGameObject, ability_index: int) -> CastProcedure:
	var procedure: CastProcedure = CastProcedure.new(state, player_id)
	var ability: ActivatedAbility = state.characteristics_of(source).abilities[ability_index] as ActivatedAbility
	procedure._ability = ability
	procedure._target_requirements = ability.targets
	procedure._costs = ability.costs
	procedure._source_object_id = source.id
	procedure._ability_index = ability_index
	if ability.mana_cost != null:
		# CR 602.2b: an activation's mana is paid like a spell's (CR 601.2g-h).
		procedure._remaining_generic = ability.mana_cost.generic
		procedure._remaining_symbols = ability.mana_cost.symbols.duplicate()
	var put: AbilityPutOnStackEvent = AbilityPutOnStackEvent.new(source.id, ability_index, player_id)
	state.perform(put)
	procedure._stack_object_id = put.new_object_id
	return procedure


## The mana [param player_id] pays to cast [param card] (CR 601.2f): its mana cost from the
## hand or the top of the library, or its flashback cost from its graveyard (an alternative cost, CR 118.9), less
## every cost reduction it has (CR 118.7, ADR 0050). Null when that cost has no mana in it.
static func mana_to_pay(state: MmGameState, player_id: int, card: MmGameObject) -> MmManaCost:
	var characteristics: MmCharacteristics = state.characteristics_of(card)
	var mana: MmManaCost = characteristics.mana_cost
	if card.zone().kind == MmZone.Kind.GRAVEYARD:
		var flashback: FlashbackAbility = flashback_of(characteristics)
		mana = null if flashback == null else flashback.mana_cost
	if mana == null:
		return null
	for ability: MmAbility in characteristics.abilities:
		var reducing: CostReductionAbility = ability as CostReductionAbility
		if reducing != null:
			mana = mana.reduced_by(reducing.reduction(state, card, player_id))
	return mana


## What lets [param player_id] cast [param card] from the top of their own library now
## (ADR 0054): the ID of the permanent or Emblem they control whose
## CastFromTopOfLibraryAbility allows it and is not Spent this turn, and that ability's
## place among its abilities. With several, the lowest object ID, then the lowest place.
## Empty when [param card] is not the top card of that player's library, or nothing allows
## it.
static func top_of_library_permission(state: MmGameState, player_id: int, card: MmGameObject) -> Array[int]:
	var library: MmZone = state.player(player_id).library
	if card.zone() != library or library.top() != card:
		return []
	var candidate: MmReference = MmReference.to_object(card.id)
	for source: MmGameObject in TriggerDetection.observers(state):
		if source.controller_id != player_id:
			continue
		var abilities: Array[MmAbility] = state.characteristics_of(source).abilities
		for index: int in abilities.size():
			var permission: CastFromTopOfLibraryAbility = abilities[index] as CastFromTopOfLibraryAbility
			if permission == null or source.is_permission_used_in(index, state.game_turn):
				continue
			if permission.filter == null or permission.filter.matches(state, candidate, MmEffectContext.new(player_id, source.id)):
				return [source.id, index]
	return []


## The card's flashback ability (CR 702.34a), or null for a card without flashback.
static func flashback_of(characteristics: MmCharacteristics) -> FlashbackAbility:
	for ability: MmAbility in characteristics.abilities:
		if ability is FlashbackAbility:
			return ability as FlashbackAbility
	return null


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
	copy._ability_index = _ability_index
	copy._ability = _ability
	copy._target_requirements = _target_requirements
	copy._next_target = _next_target
	copy._remaining_generic = _remaining_generic
	copy._remaining_symbols = _remaining_symbols.duplicate()
	copy._costs = _costs
	copy._next_cost = _next_cost
	copy._paid_cost_indexes = _paid_cost_indexes.duplicate()
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
			Stage.CHOOSE_MODE:
				var decision: ChooseModeDecision = _mode_decision()
				if decision == null:
					_stage = Stage.STUCK
					return null
				if decision.modes.size() > 1:
					return decision
				_choose_mode(decision.modes[0])  # The only mode that can be chosen needs no asking.
			Stage.CHOOSE_TARGETS:
				if _next_target >= _target_requirements.size():
					_stage = Stage.PAY_COSTS
				else:
					var choice: MmPendingDecision = TargetChoice.decision_for(_state, _player_id, _stack_object_id,
						_target_requirements, _next_target, _context())
					if choice != null:
						return choice
					_next_target += 1  # An "up to" with nothing to choose chooses none, unasked.
			Stage.PAY_COSTS:
				while _next_cost < _costs.size():
					var cost: MmCost = _costs[_next_cost]
					if not cost.can_pay(_state, _cost_source(), _player_id):
						_stage = Stage.STUCK  # Something since has made it unpayable.
						return null
					var choice: MmPendingDecision = cost.choice(_state, _cost_source(), _player_id)
					if choice != null:
						return choice
					_next_cost += 1
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
	if decision is ChoosePermanentsDecision:
		var chosen: Array[int] = []
		for id: Variant in answer as Array:
			chosen.append(id as int)
		chosen.sort()
		# CR 601.2h: costs are paid in any order; this part now, as it is chosen.
		_costs[_next_cost].pay(_state, _cost_source(), _player_id, chosen)
		_paid_cost_indexes.append(_next_cost)
		_next_cost += 1
		return
	if decision is ChooseTargetsDecision:
		TargetChoice.perform_answer(_state, decision, answer, _target_requirements)
		_next_target += 1
		return
	var index: int = answer
	if decision is ChooseModeDecision:
		_choose_mode((decision as ChooseModeDecision).modes[index])
	elif decision is ChooseTargetDecision:
		TargetChoice.perform_answer(_state, decision, answer, _target_requirements)
		_next_target += 1
	elif decision is PayManaDecision:
		var action: MmAction = (decision as PayManaDecision).actions[index]
		if action is PayWithManaAction:
			_spend((action as PayWithManaAction).unit_index)
		elif action is ActivateAbilityAction:
			_pay_with_mana_ability(action as ActivateAbilityAction)
	else:
		assert(false, "Casting cannot answer %s." % decision.describe())


## The modes that may be chosen, each with what its targets could be, or null when none
## may (CR 700.2a).
func _mode_decision() -> ChooseModeDecision:
	return ChooseModeDecision.of(_state, _player_id, _stack_object_id, (_ability as SpellAbility).modes, _context())


func _choose_mode(mode_index: int) -> void:
	_state.perform(ModeChosenEvent.new(_stack_object_id, mode_index))
	_target_requirements = (_ability as SpellAbility).modes[mode_index].targets
	_stage = Stage.CHOOSE_TARGETS


## Unit spends from the pool first, then mana abilities, each in a fixed order (ADR 0012).
func _payment_options() -> Array[MmAction]:
	var options: Array[MmAction] = []
	var pool: Array[MmMana] = _state.player(_player_id).mana_pool()
	for unit_index: int in pool.size():
		if ManaPayment.symbol_paid_by(pool[unit_index].type, _remaining_symbols, _remaining_generic) != ManaPayment.CANNOT_PAY:
			options.append(PayWithManaAction.new(unit_index))
	for source: MmGameObject in ManaPayment.sorted_sources_of(_state, _player_id):
		var abilities: Array[MmAbility] = _state.characteristics_of(source).abilities
		for ability_index: int in abilities.size():
			var ability: ActivatedAbility = abilities[ability_index] as ActivatedAbility
			if ability == null or not ManaPayment.pays_while_paying(_state, source, ability, ability_index):
				continue
			if ability.mana_cost != null:
				continue  # Later: mana abilities with mana in their cost.
			var context: MmEffectContext = MmEffectContext.new(_player_id, source.id)
			for type: MmMana.Type in ManaPayment.mana_made_by(_state, ability, context):
				if ManaPayment.symbol_paid_by(type, _remaining_symbols, _remaining_generic) != ManaPayment.CANNOT_PAY:
					options.append(ActivateAbilityAction.new(source.id, ability_index))
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
	if ability.is_once_each_game:
		_state.perform(AbilitySpentEvent.new(source.id, action.ability_index))  # CR 602.5b
	ability.pay_costs(_state, source)
	ability.resolve_effects(_state, MmEffectContext.new(source.controller_id, source.id))
	var unit_index: int = pool_size_before
	while unit_index < _state.player(_player_id).mana_pool().size():
		var type: MmMana.Type = _state.player(_player_id).mana_pool()[unit_index].type
		if ManaPayment.symbol_paid_by(type, _remaining_symbols, _remaining_generic) == ManaPayment.CANNOT_PAY:
			unit_index += 1
		else:
			_spend(unit_index)


## What a part of the cost is paid for: the ability's source, or the spell itself.
func _cost_source() -> MmGameObject:
	return _state.object(_source_object_id if _source_object_id != 0 else _stack_object_id)


## Pays every part of the cost not yet paid, in order.
func _pay_remaining_costs() -> void:
	var nothing_chosen: Array[int] = []
	for index: int in _costs.size():
		if not _paid_cost_indexes.has(index):
			_costs[index].pay(_state, _cost_source(), _player_id, nothing_chosen)


## CR 601.2h and 602.2b: pay the remaining, non-mana costs. The spell or ability is now
## cast or activated.
func _finish() -> void:
	var activated: ActivatedAbility = _ability as ActivatedAbility
	if activated != null:
		if activated.is_once_each_game:
			# CR 602.5b: it has been activated, whatever becomes of it on the stack. Marked
			# before the costs are paid, since a cost may remove the source.
			_state.perform(AbilitySpentEvent.new(_source_object_id, _ability_index))
		_pay_remaining_costs()
	else:
		_pay_remaining_costs()
		# CR 601.2i: the spell is now cast, which "whenever a player casts" triggers wait for.
		_state.perform(SpellCastEvent.new(_stack_object_id, _player_id))


func _context() -> MmEffectContext:
	return MmEffectContext.of_stack_object(_state.object(_stack_object_id))
