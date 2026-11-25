class_name ResolutionProcedure
extends RefCounted
## CR 608.2: the top of the stack resolves. Targets are rechecked first: if every target is
## now illegal it does not resolve, and otherwise effects simply skip illegal targets. Each
## effect then performs its batches in order. Resolution stops as an effect begins for each
## choice it offers (CR 608.2d) and for any decision it asks of its own, such as a search
## (ADR 0057) or a "you may" (CR 603.5), for each step of paying a "you may pay {X}"
## (ADR 0061) or a cost said yes to, as ward's (ADR 0062), and whenever a batch is waiting for a replacement choice,
## carrying on once it is answered (A143). The spell or ability leaves the stack only once
## every effect is done.

var _state: MmGameState
var _object_id: int
var _effects: Array[MmEffect] = []
var _context: MmEffectContext
var _resolves: bool = false
var _effect_index: int = 0
var _step: int = 0
## The current effect's numbers, worked out once as it began (CR 608.2h).
var _numbers: Array[int] = []
var _is_done: bool = false
## The creature type chosen as a permanent spell enters (CR 614.12, ADR 0052), or "".
var _chosen_creature_type: String = ""
## The answer to the decision the current effect asked of its own as it began, such as a
## search's (ADR 0057) or a "you may"'s, and whether it has one yet.
var _begin_answer: Variant = null
var _has_begin_answer: bool = false
## The X still being paid for a "you may pay {X}" (ADR 0061), or the cost a yes was said
## to (ADR 0062), or null when nothing is being paid.
var _payment: ManaPaymentProgress = null
var _x_being_paid: int = MmEffectContext.NONE_PAID
## Whether [member _payment] is the cost of a yes (ADR 0062), whose answer the current effect
## is given once it is paid, rather than an X.
var _is_paying_for_yes: bool = false
## The effect begun in place of the current one once its X was paid, the one a
## MayPayXEffect wraps, or null.
var _effect_in_place: MmEffect = null


## Begins resolving the top of the stack.
static func begin(state: MmGameState) -> ResolutionProcedure:
	var procedure: ResolutionProcedure = ResolutionProcedure.new(state)
	var resolving: MmGameObject = state.stack.objects().back()
	procedure._object_id = resolving.id
	var specs: Array[TargetRequirement] = []
	var overloaded_specs: Array[TargetRequirement] = []
	if resolving.is_card_or_copy():
		var spell: SpellAbility = CastProcedure.spell_ability_of(state.characteristics_of(resolving))
		if spell != null:
			# ADR 0046: a modal spell does only what its chosen mode does.
			specs = spell.targets_for(resolving.chosen_mode)
			overloaded_specs = spell.overloaded_targets_for(resolving.chosen_mode)
			procedure._effects = spell.effects_for(resolving.chosen_mode)
	elif resolving.ability is TriggeredAbility:
		var triggered: TriggeredAbility = resolving.ability as TriggeredAbility
		# ADR 0046: a modal triggered ability does only what its chosen mode does.
		specs = triggered.targets_for(resolving.chosen_mode)
		procedure._effects = triggered.effects_for(resolving.chosen_mode)
	else:
		var activated: ActivatedAbility = resolving.ability as ActivatedAbility
		specs = activated.targets
		procedure._effects = activated.effects
	var checking: MmEffectContext = MmEffectContext.of_stack_object(resolving)
	var targets: Array[MmReference] = []
	var any_legal: bool = specs.is_empty()
	var any_chosen: bool = false
	for index: int in specs.size():
		var first: int = TargetRequirement.first_place(specs, index)
		for place: int in range(first, first + specs[index].place_count()):
			var chosen: MmReference = resolving.targets[place] if place < resolving.targets.size() else null
			var still_legal: bool = specs[index].is_still_legal(state, chosen, checking)
			targets.append(chosen if still_legal else null)
			any_chosen = any_chosen or chosen != null
			any_legal = any_legal or still_legal
	# CR 608.2b: only a spell or ability whose every chosen target is illegal is kept from
	# resolving. One whose "up to" requirements chose none is targeting nothing.
	any_legal = any_legal or not any_chosen
	var triggered_ability: TriggeredAbility = resolving.ability as TriggeredAbility
	if triggered_ability != null and not triggered_ability.condition_holds(state, checking):
		any_legal = false  # CR 603.4: the intervening "if" no longer holds, so it does nothing.
	procedure._resolves = any_legal
	procedure._context = MmEffectContext.of_stack_object(resolving, targets, TargetRequirement.place_counts(specs))
	if not overloaded_specs.is_empty():
		# CR 702.96b, ADR 0014: what each "each" finds is fixed now, before any effect, so the
		# controller of a creature exiled by the first effect is still found by the second.
		var found: Array[MmReference] = []
		var counts: Array[int] = []
		for overloaded_spec: TargetRequirement in overloaded_specs:
			var each: Array[MmReference] = overloaded_spec.found_when_overloaded(state, checking)
			found.append_array(each)
			counts.append(each.size())
		procedure._context = procedure._context.with_overloaded(found, counts)
	return procedure


func _init(state: MmGameState) -> void:
	_state = state


## A copy of this procedure working on [param state], a copy of the original state.
func copy_for(state: MmGameState) -> ResolutionProcedure:
	var copy: ResolutionProcedure = ResolutionProcedure.new(state)
	copy._object_id = _object_id
	copy._effects = _effects  # Card data, never changed.
	copy._context = _context  # Never changed once made.
	copy._resolves = _resolves
	copy._effect_index = _effect_index
	copy._step = _step
	copy._numbers = _numbers.duplicate()
	copy._is_done = _is_done
	copy._chosen_creature_type = _chosen_creature_type
	copy._begin_answer = _begin_answer  # Plain data, never changed.
	copy._has_begin_answer = _has_begin_answer
	copy._payment = null if _payment == null else _payment.copy()
	copy._x_being_paid = _x_being_paid
	copy._is_paying_for_yes = _is_paying_for_yes
	copy._effect_in_place = _effect_in_place  # Card data, never changed.
	return copy


## Performs the next batches until a replacement choice is needed, which it returns, or
## until the spell or ability has left the stack, when it returns null.
func next_decision() -> MmPendingDecision:
	while not _is_done:
		if _state.is_batch_suspended():
			return _state.replacement_decision()
		if not _resolves or _effect_index >= _effects.size():
			var entering: ChooseCreatureTypeDecision = _creature_type_choice()
			if entering != null:
				return entering
			_leave_stack()
			_is_done = true
			return null
		var effect: MmEffect = _effects[_effect_index] if _effect_in_place == null else _effect_in_place
		if _step == 0:
			if _payment != null:
				var paying: PayManaDecision = _begin_paid_effect()
				if paying != null:
					return paying
				effect = _effects[_effect_index] if _effect_in_place == null else _effect_in_place
			# ADR 0061: what "if you do" chooses is chosen only once X is paid.
			var choice: ChooseObjectDecision = null if effect is MayPayXEffect else _next_choice(effect)
			if choice != null:
				return choice
			if not _has_begin_answer:
				var asked: MmPendingDecision = effect.decision_as_it_begins(_state, _context, _object_id)
				if asked != null:
					return asked
			_numbers = effect.numbers_with_answer(_state, _context, _begin_answer) if _has_begin_answer else effect.numbers(_state, _context)
		var batch: Array[MmEvent] = effect.next_batch(_state, _context, _step, _numbers)
		if batch.is_empty():
			_effect_index += 1
			_step = 0
			_begin_answer = null
			_has_begin_answer = false
			_effect_in_place = null
			continue
		_step += 1
		_state.perform_resumably(batch)
		if effect.remembers_moved_cards():
			_remember_moved(batch)
	return null


## Remembers the new objects of the cards [param batch] moved as "them" (engine ADR 0080).
# Later: a card whose move a replacement effect is still waiting to change, once one can
# change a milled card's.
func _remember_moved(batch: Array[MmEvent]) -> void:
	var ids: Array[int] = []
	for event: MmEvent in batch:
		var move: ZoneChangeEvent = event as ZoneChangeEvent
		if move != null and move.new_object_id != 0:
			ids.append(move.new_object_id)
	_context = _context.with_moved(ids)


## Applies an already-validated answer to a choice this procedure asked.
func apply_answer(decision: MmPendingDecision, answer: Variant) -> void:
	var creature_type: ChooseCreatureTypeDecision = decision as ChooseCreatureTypeDecision
	if creature_type != null:
		_chosen_creature_type = creature_type.creature_types[answer as int]
		return
	if decision is ChooseCardsInLibraryDecision or decision is ChooseCardsToDiscardDecision \
			or decision is ChooseLookedAtCardsDecision:
		_begin_answer = (answer as Array).duplicate()
		_has_begin_answer = true
		return
	if decision is SurveilDecision:
		_begin_answer = (answer as Array).duplicate(true)  # Two lists, kept whole (ADR 0068).
		_has_begin_answer = true
		return
	if decision is ChooseYesOrNoDecision:
		var asked: ChooseYesOrNoDecision = decision as ChooseYesOrNoDecision
		if asked.cost != null and (answer as int) == ChooseYesOrNoDecision.Choice.YES:
			# ADR 0062: yes is paid first, as a cast's mana is; the effect hears it once paid.
			_payment = ManaPaymentProgress.of_cost(asked.player_id, asked.cost)
			_is_paying_for_yes = true
			return
		if asked.resolution_cost != null and (answer as int) == ChooseYesOrNoDecision.Choice.YES:
			# ADR 0076: yes pays at once, for the ability's source; what "if you do" offers
			# then happens.
			var nothing_chosen: Array[int] = []
			asked.resolution_cost.pay(_state, _state.object(_context.source_object_id), asked.player_id, nothing_chosen)
		_begin_answer = answer as int
		_has_begin_answer = true
		return
	if decision is ChooseXToPayDecision:
		var x: int = ChooseXToPayDecision.x_of(answer as int)
		if x == MmEffectContext.NONE_PAID:
			_begin_answer = answer as int  # Declined: the effect does nothing.
			_has_begin_answer = true
		else:
			_x_being_paid = x
			_payment = ManaPaymentProgress.new(decision.player_id, x)
		return
	if decision is PayManaDecision:
		_payment.apply_answer(_state, decision as PayManaDecision, answer as int)
		return
	var choice: ChooseObjectDecision = decision as ChooseObjectDecision
	assert(choice != null, "A resolution cannot answer %s." % decision.describe())
	_context = _context.with_choice(choice.choice_index, choice.candidates[answer as int])


## The next step of paying the X chosen for the current MayPayXEffect (CR 605.3a), or, once
## it is paid, null with the effect it wraps begun in its place, its context holding the X
## paid (ADR 0061). For a cost said yes to, once it is paid the current effect is given its
## yes (ADR 0062).
func _begin_paid_effect() -> PayManaDecision:
	if not _payment.is_paid():
		var paying: PayManaDecision = _payment.decision(_state)
		assert(paying != null, "What was offered could be paid (ManaPayment.can_afford() is exact).")
		return paying
	_payment = null
	if _is_paying_for_yes:
		_is_paying_for_yes = false
		_begin_answer = ChooseYesOrNoDecision.Choice.YES
		_has_begin_answer = true
		return null
	_context = _context.with_paid_x(_x_being_paid)
	_x_being_paid = MmEffectContext.NONE_PAID
	_effect_in_place = (_effects[_effect_index] as MayPayXEffect).effect
	return null


## The choice [param effect] still needs before it begins, or null. One with nothing to
## choose from is made at once, as nothing (CR 608.2d).
# Later: a choice inside another Selection, such as "its controller" of a chosen creature.
func _next_choice(effect: MmEffect) -> ChooseObjectDecision:
	for selection: MmSelection in effect.selections():
		var chosen: ChosenSelection = selection as ChosenSelection
		if chosen == null or _context.choices.has(chosen.choice_index):
			continue
		var legal: Array[MmReference] = chosen.candidates(_state, _context)
		if legal.is_empty():
			_context = _context.with_choice(chosen.choice_index, null)
			continue
		return ChooseObjectDecision.new(_context.controller_id, _object_id, chosen.choice_index, chosen.filter, legal)
	return null


## The creature type choice a resolving permanent spell needs before it enters, or null:
## asked once its effects are done, as it leaves the stack (CR 614.12, ADR 0052). Its
## characteristics on the stack stand for those it would have on the battlefield.
# Later: every other way onto the battlefield (ReturnToBattlefieldEffect, a flicker) asks
# too, once a card can put a permanent with this ability there that way.
func _creature_type_choice() -> ChooseCreatureTypeDecision:
	if not _resolves or _chosen_creature_type != "":
		return null
	var resolving: MmGameObject = _state.object(_object_id)
	if not resolving.is_card_or_copy():
		return null
	var characteristics: MmCharacteristics = _state.characteristics_of(resolving)
	if not characteristics.is_permanent() or not characteristics.has_ability(AsEntersChooseCreatureTypeAbility):
		return null
	return ChooseCreatureTypeDecision.new(resolving.controller_id, _object_id)


func _leave_stack() -> void:
	var resolving: MmGameObject = _state.object(_object_id)
	if resolving.is_card_or_copy() and _resolves and _state.characteristics_of(resolving).is_permanent():
		# CR 608.3: a permanent spell enters the battlefield; a copy of one, as a token
		# (CR 608.3f). Its controller is its owner
		# until control-changing effects exist (milestone 9), as CR 608.3a needs.
		var entering: ZoneChangeEvent = ZoneChangeEvent.new(resolving, _state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.RESOLVED)
		# ADR 0052: the type chosen as it enters is on it as it arrives.
		entering.chosen_creature_type_on_arrival = _chosen_creature_type
		# CR 303.4a, ADR 0064: an Aura spell enters attached to its target, still legal,
		# since it resolved.
		if _state.characteristics_of(resolving).has_ability(EnchantAbility) and not _context.targets.is_empty() \
				and _context.targets[0] != null and _context.targets[0].is_object():
			entering.attached_to_on_arrival = _context.targets[0].id
		_state.perform(entering)
	elif resolving.is_card() and _resolves and resolving.is_adventure_spell:
		# CR 715.3d: an Adventure that resolves is exiled instead, on an adventure.
		var away: ZoneChangeEvent = ZoneChangeEvent.new(resolving, _state.exile, MmZone.BOTTOM, ZoneChangeEvent.Reason.RESOLVED)
		away.exiled_on_adventure = true
		_state.perform(away)
	elif resolving.is_card_or_copy():
		# CR 608.2n: an instant or sorcery goes to its owner's graveyard; a copy of one
		# then ceases to exist (CR 704.5e).
		var reason: ZoneChangeEvent.Reason = ZoneChangeEvent.Reason.RESOLVED if _resolves else ZoneChangeEvent.Reason.DID_NOT_RESOLVE
		_state.perform(ZoneChangeEvent.new(resolving, _state.graveyard_from_stack(resolving), MmZone.BOTTOM, reason))
	else:
		_state.perform(AbilityLeftStackEvent.new(resolving.id, _resolves))
