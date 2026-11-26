class_name MayPayEffect
extends MmEffect
## "You may [cost]. If you do, [effect]." (CR 603.5, 608.2d, ADR 0076), as Guiding Hydra's "you
## may remove a +1/+1 counter from this creature. If you do, put a +1/+1 counter on each other
## creature you control." As it begins its controller is asked a ChooseYesOrNoDecision with
## the cost as its [member ChooseYesOrNoDecision.resolution_cost], only if they could pay it
## now for the ability's source; ResolutionProcedure pays it at once on yes, and then
## [member effect] happens. No, or a cost that cannot be paid, does nothing (CR 118.3).
## With [member mana_cost] instead it is "You may pay {1}. If you do, [effect].", as on
## Myrsmith: asked only if they could pay that mana now, with it as the question's
## [member ChooseYesOrNoDecision.cost], so ResolutionProcedure has yes paid one
## PayManaDecision at a time, as ward's cost is (ADR 0062), and [member effect] happens once
## it is paid.
##
## With [member is_once_each_turn] it ends "Do this only once each turn", as Irreverent
## Gremlin's does (engine ADR 0054's second addendum): once its controller has paid and the
## effect happens, the triggered ability it is part of is Spent on its source for the turn,
## so it triggers no more and one already on the stack asks nothing. No leaves it as it was.
# Later: a cost of mana and something else at once, and "if you don't". Each once a card
# needs it.

## What yes pays, other than mana; null when [member mana_cost] is the cost.
@export var cost: MmCost
## The mana yes pays, for "you may pay {1}"; null when [member cost] is the cost.
@export var mana_cost: MmManaCost = null
## What happens once the cost is paid.
@export var effect: MmEffect
## "Do this only once each turn": a yes spends its triggered ability for the turn.
@export var is_once_each_turn: bool = false


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	if is_once_each_turn and _is_done_this_turn(state, context):
		return null  # Engine ADR 0054's second addendum: done once already.
	if mana_cost != null:
		if not ManaPayment.can_afford(state, context.controller_id, mana_cost):
			return null  # CR 118.3: mana that cannot be paid is not paid.
		return ChooseYesOrNoDecision.new(context.controller_id, stack_object_id, effect, mana_cost)
	if not cost.can_pay(state, state.object(context.source_object_id), context.controller_id):
		return null
	var asked: ChooseYesOrNoDecision = ChooseYesOrNoDecision.new(context.controller_id, stack_object_id, effect)
	asked.resolution_cost = cost
	return asked


## Unpaid, since it could not be: nothing happens.
func numbers(_state: MmGameState, _context: MmEffectContext) -> Array[int]:
	return [0]


## The first number is 1 once paid and 0 on no; then [member effect]'s own numbers follow
## (CR 608.2h).
func numbers_with_answer(state: MmGameState, context: MmEffectContext, answer: Variant) -> Array[int]:
	if answer as int != ChooseYesOrNoDecision.Choice.YES:
		return [0]
	var worked_out: Array[int] = [1]
	worked_out.append_array(effect.numbers(state, context))
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if worked_out.is_empty() or worked_out[0] != 1:
		return []
	var batch: Array[MmEvent] = effect.next_batch(state, context, step, worked_out.slice(1))
	if step == 0 and is_once_each_turn:
		var done: OnceEachTurnDoneEvent = _done_event(state, context)
		if done != null:
			batch.push_front(done)
	return batch


## [member effect]'s Selections, so what it targets is what the ability targets.
func selections() -> Array[MmSelection]:
	return effect.selections()


func adds_mana() -> bool:
	return effect.adds_mana()


## Whether the triggered ability resolving has been done once this turn already, on its
## source.
func _is_done_this_turn(state: MmGameState, context: MmEffectContext) -> bool:
	var resolving: MmGameObject = state.object(context.own_object_id) if context.own_object_id != 0 else null
	var source: MmGameObject = state.object(context.source_object_id)
	if resolving == null or resolving.ability == null or source == null:
		return false
	return source.has_triggered_in(resolving.source_ability_index, state.game_turn)


## What marks the ability resolving done this turn on its source, or null when its source
## has gone, which never triggers again (ADR 0008).
func _done_event(state: MmGameState, context: MmEffectContext) -> OnceEachTurnDoneEvent:
	var resolving: MmGameObject = state.object(context.own_object_id) if context.own_object_id != 0 else null
	if resolving == null or resolving.ability == null or state.object(context.source_object_id) == null:
		return null
	return OnceEachTurnDoneEvent.new(context.source_object_id, resolving.source_ability_index)
