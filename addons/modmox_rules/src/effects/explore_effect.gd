class_name ExploreEffect
extends MmEffect
## "[selection] explores" (CR 701.44a, engine ADR 0090), as a Map's "Target creature you
## control explores": the exploring permanent's controller reveals the top card of their
## library. A land card goes into their hand, revealed. Otherwise a +1/+1 counter goes on the
## permanent, if it is still on the battlefield, and they may put the revealed card into their
## graveyard, which they are asked as the effect begins: an ExploreDecision of that card. With
## no card to reveal it still gets the counter. A permanent that has left the battlefield
## still explores, as it last existed (CR 608.2h), and gets no counter. The reveal, the
## counter and the move are one batch each, in that order.
# Later: several permanents exploring one after another, and "whenever a creature you
# control explores" (CR 701.44b), once a card needs them.

## What explores: its first object. "This creature" finds it as it last existed when it has gone.
@export var selection: MmSelection

## The numbers this effect works out as it begins, in order (CR 608.2h).
enum Number { EXPLORER = 0, TOP_CARD = 1, IS_LAND = 2, IS_GRAVEYARDED = 3, IS_ON_BATTLEFIELD = 4 }
## What each step does, in order; a step with nothing to do is left out.
enum Phase { REVEAL = 0, COUNTER = 1, GRAVEYARD = 2 }


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	var explorer: MmGameObject = _explorer(state, context)
	if explorer == null:
		return null
	var top: MmGameObject = state.player(explorer.controller_id).library.top()
	if top == null or state.characteristics_of(top).has_card_type(MmCardTypes.CardType.LAND):
		return null
	var revealed: Array[int] = [top.id]
	return ExploreDecision.new(explorer.controller_id, stack_object_id, revealed)


## Asked nothing: a land to put into the hand, no card to reveal, or nothing to explore.
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	return _worked_out(state, context, false)


func numbers_with_answer(state: MmGameState, context: MmEffectContext, answer: Variant) -> Array[int]:
	return _worked_out(state, context, not SurveilDecision.graveyarded_in(answer).is_empty())


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	var phases: Array[Phase] = _phases(worked_out)
	if step >= phases.size():
		return events
	var top: MmGameObject = state.object(worked_out[Number.TOP_CARD])
	match phases[step]:
		Phase.REVEAL:
			if worked_out[Number.IS_LAND] == 1:
				var to_hand: ZoneChangeEvent = ZoneChangeEvent.new(top, state.player(top.owner_id).hand, MmZone.BOTTOM,
					ZoneChangeEvent.Reason.EXPLORE)
				to_hand.revealed = true
				events.append(to_hand)
			else:
				events.append(CardRevealedEvent.new(top.id))
		Phase.COUNTER:
			events.append(CountersPutEvent.new(worked_out[Number.EXPLORER], MmCounter.Kind.PLUS_ONE_PLUS_ONE, 1,
				context.controller_id))
		Phase.GRAVEYARD:
			events.append(ZoneChangeEvent.new(top, state.player(top.owner_id).graveyard, MmZone.BOTTOM,
				ZoneChangeEvent.Reason.EXPLORE))
	return events


func selections() -> Array[MmSelection]:
	return [selection]


## The steps [param worked_out] has to do, worked out from the numbers alone, so each step
## keeps its place as the earlier ones are done.
static func _phases(worked_out: Array[int]) -> Array[Phase]:
	var phases: Array[Phase] = []
	if worked_out.is_empty():
		return phases
	var has_card: bool = worked_out[Number.TOP_CARD] != 0
	if has_card:
		phases.append(Phase.REVEAL)
	if worked_out[Number.IS_LAND] == 1:
		return phases
	if worked_out[Number.IS_ON_BATTLEFIELD] == 1:
		phases.append(Phase.COUNTER)
	if has_card and worked_out[Number.IS_GRAVEYARDED] == 1:
		phases.append(Phase.GRAVEYARD)
	return phases


## The explorer, the top card, whether it is a land, whether it is graveyarded and whether
## the explorer is on the battlefield to get the counter; empty when nothing explores.
func _worked_out(state: MmGameState, context: MmEffectContext, is_graveyarded: bool) -> Array[int]:
	var explorer: MmGameObject = _explorer(state, context)
	if explorer == null:
		return []
	var top: MmGameObject = state.player(explorer.controller_id).library.top()
	var is_land: bool = top != null and state.characteristics_of(top).has_card_type(MmCardTypes.CardType.LAND)
	var is_on_battlefield: bool = explorer.zone() == state.battlefield and state.object(explorer.id) != null
	return [explorer.id, 0 if top == null else top.id, 1 if is_land else 0, 1 if is_graveyarded else 0,
		1 if is_on_battlefield else 0]


## The permanent that explores, as it last existed if it has gone, or null.
func _explorer(state: MmGameState, context: MmEffectContext) -> MmGameObject:
	var found: Array[MmReference] = selection.select(state, context)
	if not found.is_empty() and found[0].is_object():
		return state.object_or_last_known(found[0].id)
	if selection is SourceSelection:
		return state.object_or_last_known(context.source_object_id)  # CR 608.2h
	return null
