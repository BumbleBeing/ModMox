class_name ResolutionProcedure
extends RefCounted
## CR 608.2: the top of the stack resolves. Targets are rechecked first: if every target is
## now illegal it does not resolve, and otherwise effects simply skip illegal targets. Each
## effect then performs its batches in order, and resolution stops whenever a batch is
## waiting for a replacement choice, carrying on once it is answered (A143). The spell or
## ability leaves the stack only once every effect is done.

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


## Begins resolving the top of the stack.
static func begin(state: MmGameState) -> ResolutionProcedure:
	var procedure: ResolutionProcedure = ResolutionProcedure.new(state)
	var resolving: MmGameObject = state.stack.objects().back()
	procedure._object_id = resolving.id
	var specs: Array[TargetSpec] = []
	if resolving.is_card():
		var spell: SpellAbility = CastProcedure.spell_ability_of(state.characteristics_of(resolving))
		if spell != null:
			specs = spell.targets
			procedure._effects = spell.effects
	elif resolving.ability is TriggeredAbility:
		var triggered: TriggeredAbility = resolving.ability as TriggeredAbility
		specs = triggered.targets
		procedure._effects = triggered.effects
	else:
		var activated: ActivatedAbility = resolving.ability as ActivatedAbility
		specs = activated.targets
		procedure._effects = activated.effects
	var source_id: int = resolving.id if resolving.is_card() else resolving.source_object_id
	var checking: MmEffectContext = MmEffectContext.new(resolving.controller_id, source_id, [],
		resolving.triggering_player_id, resolving.triggering_object_id)
	var targets: Array[MmReference] = []
	var any_legal: bool = specs.is_empty()
	for index: int in specs.size():
		var chosen: MmReference = resolving.targets[index] if index < resolving.targets.size() else null
		var still_legal: bool = specs[index].is_still_legal(state, chosen, checking)
		targets.append(chosen if still_legal else null)
		any_legal = any_legal or still_legal
	var triggered_ability: TriggeredAbility = resolving.ability as TriggeredAbility
	if triggered_ability != null and not triggered_ability.condition_holds(state, checking):
		any_legal = false  # CR 603.4: the intervening "if" no longer holds, so it does nothing.
	procedure._resolves = any_legal
	procedure._context = MmEffectContext.new(resolving.controller_id, source_id, targets,
		resolving.triggering_player_id, resolving.triggering_object_id)
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
	return copy


## Performs the next batches until a replacement choice is needed, which it returns, or
## until the spell or ability has left the stack, when it returns null.
func next_decision() -> MmPendingDecision:
	while not _is_done:
		if _state.is_batch_suspended():
			return _state.replacement_decision()
		if not _resolves or _effect_index >= _effects.size():
			_leave_stack()
			_is_done = true
			return null
		var effect: MmEffect = _effects[_effect_index]
		if _step == 0:
			_numbers = effect.numbers(_state, _context)
		var batch: Array[MmEvent] = effect.next_batch(_state, _context, _step, _numbers)
		if batch.is_empty():
			_effect_index += 1
			_step = 0
			continue
		_step += 1
		_state.perform_resumably(batch)
	return null


func _leave_stack() -> void:
	var resolving: MmGameObject = _state.object(_object_id)
	if resolving.is_card() and _resolves and _state.characteristics_of(resolving).is_permanent():
		# CR 608.3: a permanent spell enters the battlefield. Its controller is its owner
		# until control-changing effects exist (milestone 9), as CR 608.3a needs.
		_state.perform(ZoneChangeEvent.new(resolving, _state.battlefield, MmZone.BOTTOM, ZoneChangeEvent.Reason.RESOLVED))
	elif resolving.is_card():
		# CR 608.2n: an instant or sorcery goes to its owner's graveyard.
		var reason: ZoneChangeEvent.Reason = ZoneChangeEvent.Reason.RESOLVED if _resolves else ZoneChangeEvent.Reason.DID_NOT_RESOLVE
		_state.perform(ZoneChangeEvent.new(resolving, _state.player(resolving.owner_id).graveyard, MmZone.BOTTOM, reason))
	else:
		_state.perform(AbilityLeftStackEvent.new(resolving.id, _resolves))
