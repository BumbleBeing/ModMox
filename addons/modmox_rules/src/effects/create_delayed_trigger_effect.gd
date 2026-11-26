class_name CreateDelayedTriggerEffect
extends MmEffect
## "[effects] at the beginning of your next end step" (CR 603.7), as Harried Dronesmith's
## "Sacrifice it at the beginning of your next end step": creates a delayed triggered
## ability (DelayedTrigger) that triggers the next time [member ability]'s trigger is met,
## once only, then is gone (CR 603.7c, engine ADR 0103). "Next" is the next to begin: one
## created in your end step waits for your next turn's. Its controller and source are those
## of the spell or ability that created it, the source as it last existed if it has gone
## (CR 608.2h), and it triggers whatever becomes of its source after. It is bound to what that
## spell or ability remembered, so its "it" (MovedCardsSelection) is the token created just
## before it.
# Later: a delayed trigger with an intervening "if" or targets of its own, and one that
# waits for something other than a step to begin, once a card needs them.

## What triggers later: its trigger, such as "at the beginning of your end step"
## (StepBeganTrigger), and what it does.
@export var ability: TriggeredAbility


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	var source: MmGameObject = state.object_or_last_known(context.source_object_id)
	if source == null:
		return events
	var holding: MmGameObject = state.object_or_last_known(context.own_object_id)
	var index: int = holding.source_ability_index if holding != null and not holding.is_card_or_copy() else -1
	events.append(DelayedTriggerCreatedEvent.new(DelayedTrigger.new(ability, context.controller_id, source,
		state.characteristics_of(source), index, context.moved_ids)))
	return events
