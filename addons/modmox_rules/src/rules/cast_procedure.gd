class_name CastProcedure
extends RefCounted
## Casting a spell (CR 601.2) or activating an ability that uses the stack (CR 602.2):
## announce it onto the stack, choose its mode if it is modal, choose its targets, make
## any choice a part of its cost asks (paying that part then), then pay its mana one step
## at a time, then make any choice an additional cost asks (engine ADR 0086) and pay the
## rest of its cost. A card cast from its graveyard is cast for its flashback cost
## (CR 702.34a), and one cast from the top of its library uses up a permission to
## (ADR 0054). An Adventurer card may be cast as its Adventure (CR 715.3).
## When the payment can no longer be finished it reports itself stuck, and the engine
## rewinds the whole attempt (CR 728, ADR 0015).

enum Stage { CHOOSE_MODE, CHOOSE_TARGETS, PAY_MANA, DONE, STUCK, PAY_COSTS, CHOOSE_X, PAY_COSTS_AFTER_MANA }

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
## The mana still owed (CR 601.2g-h), nothing until the cost is known.
var _payment: ManaPaymentProgress
var _stage: Stage = Stage.CHOOSE_TARGETS
## The mana cost of a spell with {X} in it, whose X is still to be chosen or was (ADR 0076),
## or null. Card data, never changed.
var _x_cost: MmManaCost = null
## The parts of the cost that are not mana (CR 601.2h): an ability's costs, or a flashback
## cost's, then a spell's additional costs. Those that ask a choice are paid as it is
## answered, the rest once the mana is.
var _costs: Array[MmCost] = []
## How many of [member _costs] are asked before the mana (ADR 0048). The rest, a spell's
## additional costs, are asked once it is paid (CR 601.2g-h, engine ADR 0086).
var _costs_before_mana: int = 0
var _next_cost: int = 0
var _paid_cost_indexes: Array[int] = []


## Begins casting [param card] from [param player_id]'s hand, from their graveyard for its
## flashback cost, or from the top of their library with a permission, which is used now
## (CR 601.3, ADR 0054): CR 601.2a moves it to the stack. [param as_adventure] casts it as its
## Adventure, with only the Adventure's characteristics (CR 715.3a-b, engine ADR 0078), and
## [param bestowed] as an Aura spell for its bestow cost (CR 702.103a-b, engine ADR 0089).
static func cast_spell(state: MmGameState, player_id: int, card: MmGameObject, as_adventure: bool = false,
		bestowed: bool = false) -> CastProcedure:
	var characteristics: MmCharacteristics = state.characteristics_of(card)
	if as_adventure:
		characteristics = characteristics.adventure
	elif bestowed:
		characteristics = BestowRules.as_bestowed(state, card)
	var procedure: CastProcedure = CastProcedure.new(state, player_id)
	var spell: SpellAbility = spell_ability_of(characteristics)
	procedure._ability = spell
	if spell != null and spell.is_modal():
		procedure._stage = Stage.CHOOSE_MODE  # CR 601.2b: the mode comes before targets.
	elif spell != null:
		procedure._target_requirements = spell.targets
	# CR 601.2f: the total cost is fixed now. Choosing modes and targets first, as the rules
	# order it, can change nothing it counts. Later: cost increases.
	var mana: MmManaCost = mana_to_pay(state, player_id, card, as_adventure, bestowed)
	if mana != null and mana.x_count > 0:
		procedure._x_cost = mana
		if procedure._stage != Stage.CHOOSE_MODE:
			procedure._stage = Stage.CHOOSE_X  # CR 601.2b: X after any mode, before targets.
	var is_flashback: bool = card.zone().kind == MmZone.Kind.GRAVEYARD
	var costs: Array[MmCost] = []
	if is_flashback:
		costs.append_array(flashback_of(characteristics).costs)
	procedure._costs_before_mana = costs.size()
	costs.append_array(additional_costs_of(characteristics))
	procedure._costs = costs
	procedure._payment = ManaPaymentProgress.of_cost(player_id, mana)
	if card.zone().kind == MmZone.Kind.LIBRARY:
		var permission: Array[int] = top_of_library_permission(state, player_id, card)
		assert(not permission.is_empty(), "Nothing lets player %d cast %s from their library." % [player_id, characteristics.name])
		state.perform(CastPermissionUsedEvent.new(permission[0], permission[1], characteristics.name))
	var move: ZoneChangeEvent = ZoneChangeEvent.new(card, state.stack, MmZone.BOTTOM, ZoneChangeEvent.Reason.CAST)
	move.cast_with_flashback = is_flashback
	move.cast_as_adventure = as_adventure
	move.is_bestowed = bestowed
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
	procedure._costs_before_mana = ability.costs.size()
	procedure._source_object_id = source.id
	procedure._ability_index = ability_index
	# CR 602.2b: an activation's mana is paid like a spell's (CR 601.2f-h), less any
	# reduction, fixed now (ADR 0050).
	procedure._payment = ManaPaymentProgress.of_cost(player_id, ability.mana_to_pay(state, source))
	procedure._payment.tapping_source_id = ability.tapping_source_id(source)
	var put: AbilityPutOnStackEvent = AbilityPutOnStackEvent.new(source.id, ability_index, player_id)
	state.perform(put)
	procedure._stack_object_id = put.new_object_id
	return procedure


## The mana [param player_id] pays to cast [param card] (CR 601.2f): its mana cost from the
## hand or the top of the library, or its flashback cost from its graveyard (an alternative cost, CR 118.9), less
## every cost reduction it has (CR 118.7, ADR 0050) and every SpellsCostLessAbility of a
## permanent or Emblem [param player_id] controls. Null when that cost has no mana in it.
## [param as_adventure]: its Adventure's mana cost and reductions (CR 715.3a).
## [param bestowed]: its bestow cost instead, an alternative cost (CR 118.9, 702.103a).
static func mana_to_pay(state: MmGameState, player_id: int, card: MmGameObject, as_adventure: bool = false,
		bestowed: bool = false) -> MmManaCost:
	var characteristics: MmCharacteristics = state.characteristics_of(card)
	if as_adventure:
		characteristics = characteristics.adventure
	var mana: MmManaCost = characteristics.mana_cost
	if bestowed:
		var bestow: BestowAbility = BestowRules.bestow_of(characteristics)
		mana = null if bestow == null else bestow.mana_cost
	elif card.zone().kind == MmZone.Kind.GRAVEYARD:
		var flashback: FlashbackAbility = flashback_of(characteristics)
		mana = null if flashback == null else flashback.mana_cost
	if mana == null:
		return null
	for ability: MmAbility in characteristics.abilities:
		var reducing: CostReductionAbility = ability as CostReductionAbility
		if reducing != null:
			mana = mana.reduced_by(reducing.reduction(state, card, player_id))
	# Engine ADR 0050's addendum: the caster's permanents and Emblems may make it cost less too.
	for source: MmGameObject in TriggerDetection.observers(state):
		if source.controller_id != player_id:
			continue
		for ability: MmAbility in state.characteristics_of(source).abilities:
			var cheaper: SpellsCostLessAbility = ability as SpellsCostLessAbility
			if cheaper != null:
				mana = mana.reduced_by(cheaper.reduction(state, player_id))
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


## The largest X [param player_id] could pay now for [param cost], a cost with {X}, with the
## rest of it (ADR 0076).
static func most_x(state: MmGameState, player_id: int, cost: MmManaCost) -> int:
	var x: int = 0
	while ManaPayment.can_afford(state, player_id, cost.with_x(x + 1)):
		x += 1
	return x


## Every additional cost of a spell with [param characteristics] (CR 601.2f, 118.8), in the
## order of its AdditionalCostAbility abilities.
static func additional_costs_of(characteristics: MmCharacteristics) -> Array[MmCost]:
	var costs: Array[MmCost] = []
	for ability: MmAbility in characteristics.abilities:
		var additional: AdditionalCostAbility = ability as AdditionalCostAbility
		if additional != null:
			costs.append_array(additional.costs)
	return costs


## The card's flashback ability (CR 702.34a), or null for a card without flashback.
static func flashback_of(characteristics: MmCharacteristics) -> FlashbackAbility:
	for ability: MmAbility in characteristics.abilities:
		if ability is FlashbackAbility:
			return ability as FlashbackAbility
	return null


## The spell ability of an instant or sorcery, or of an Aura its enchant ability makes
## (CR 303.4a, ADR 0064), or null, as for a creature with no spell ability.
static func spell_ability_of(characteristics: MmCharacteristics) -> SpellAbility:
	var enchant: EnchantAbility = null
	for ability: MmAbility in characteristics.abilities:
		if ability is SpellAbility:
			return ability as SpellAbility
		if enchant == null and ability is EnchantAbility:
			enchant = ability as EnchantAbility
	return null if enchant == null else enchant.aura_spell()


func _init(state: MmGameState, player_id: int) -> void:
	_state = state
	_player_id = player_id
	_payment = ManaPaymentProgress.new(player_id)


## A copy of this procedure working on [param state], a copy of the original state.
func copy_for(state: MmGameState) -> CastProcedure:
	var copy: CastProcedure = CastProcedure.new(state, _player_id)
	copy._stack_object_id = _stack_object_id
	copy._source_object_id = _source_object_id
	copy._ability_index = _ability_index
	copy._ability = _ability
	copy._target_requirements = _target_requirements
	copy._next_target = _next_target
	copy._payment = _payment.copy()
	copy._costs = _costs
	copy._costs_before_mana = _costs_before_mana
	copy._next_cost = _next_cost
	copy._paid_cost_indexes = _paid_cost_indexes.duplicate()
	copy._stage = _stage
	copy._x_cost = _x_cost
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
			Stage.CHOOSE_X:
				return ChooseXDecision.new(_player_id, _stack_object_id, most_x(_state, _player_id, _x_cost))
			Stage.CHOOSE_TARGETS:
				if _next_target >= _target_requirements.size():
					_stage = Stage.PAY_COSTS
				else:
					# ADR 0014: an "up to" with nothing to choose is still asked, so the
					# caster may cancel rather than confirm none.
					return TargetChoice.decision_for(_state, _player_id, _stack_object_id,
						_target_requirements, _next_target, _context(), true)
			Stage.PAY_COSTS:
				var asked: MmPendingDecision = _next_cost_choice(_costs_before_mana)
				if asked != null or _stage == Stage.STUCK:
					return asked
				_stage = Stage.PAY_MANA
			Stage.PAY_MANA:
				if _payment.is_paid():
					_stage = Stage.PAY_COSTS_AFTER_MANA
					continue
				var paying: PayManaDecision = _payment.decision(_state)
				if paying == null:
					_stage = Stage.STUCK
				return paying
			Stage.PAY_COSTS_AFTER_MANA:
				# CR 601.2g-h, engine ADR 0086: once the mana is paid, so a permanent just
				# tapped for mana may be returned.
				var asked: MmPendingDecision = _next_cost_choice(_costs.size())
				if asked != null or _stage == Stage.STUCK:
					return asked
				_finish()
				_stage = Stage.DONE
				return null
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
	elif decision is ChooseXDecision:
		# CR 601.2f: the spell now costs X more for each {X}.
		_state.perform(XChosenEvent.new(_stack_object_id, index))
		_payment.remaining_generic += index * _x_cost.x_count
		_stage = Stage.CHOOSE_TARGETS
	elif decision is ChooseTargetDecision:
		TargetChoice.perform_answer(_state, decision, answer, _target_requirements)
		_next_target += 1
	elif decision is PayManaDecision:
		_payment.apply_answer(_state, decision as PayManaDecision, index)
	else:
		assert(false, "Casting cannot answer %s." % decision.describe())


## The modes that may be chosen, each with what its targets could be, or null when none
## may (CR 700.2a).
func _mode_decision() -> ChooseModeDecision:
	return ChooseModeDecision.of(_state, _player_id, _stack_object_id, (_ability as SpellAbility).modes, _context())


func _choose_mode(mode_index: int) -> void:
	_state.perform(ModeChosenEvent.new(_stack_object_id, mode_index))
	_target_requirements = (_ability as SpellAbility).modes[mode_index].targets
	_stage = Stage.CHOOSE_X if _x_cost != null else Stage.CHOOSE_TARGETS


## The choice the next of [member _costs] before [param end] asks, or null once each has been
## asked or asks none. One that can no longer be paid makes the procedure stuck.
func _next_cost_choice(end: int) -> MmPendingDecision:
	while _next_cost < end:
		var cost: MmCost = _costs[_next_cost]
		if not cost.can_pay(_state, _cost_source(), _player_id):
			_stage = Stage.STUCK  # Something since has made it unpayable.
			return null
		var choice: MmPendingDecision = cost.choice(_state, _cost_source(), _player_id)
		if choice != null:
			return choice
		_next_cost += 1
	return null


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
