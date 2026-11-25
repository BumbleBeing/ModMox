class_name ReflexiveTriggerEffect
extends MmEffect
## "When you do, [ability]" (CR 603.12): a reflexive triggered ability, as Kishla Trawlers's
## "you may exile a creature card from your graveyard. When you do, return target instant or
## sorcery card from your graveyard to your hand." It follows a "you may" whose yes it
## needs, held as a MayPayEffect's effect, and triggers as it happens: [member ability]
## waits with any other pending trigger and is put on the stack the next time a player
## would receive priority (CR 603.3), its mode and targets chosen then, so it is removed if
## none can be (CR 603.3c-d). Its source and controller are those of the ability it is part
## of, the source as it last existed if it has gone (CR 608.2h), and it is that ability's,
## at that ability's place among its source's abilities. Its targets are its own, so the
## ability holding it targets nothing for them.

## What triggers: a triggered ability with no trigger of its own.
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
	var pending: PendingTrigger = PendingTrigger.new(ability, index, source, state.characteristics_of(source),
		context.controller_id, 0)
	pending.controller_id = context.controller_id
	events.append(AbilityTriggeredEvent.new(pending))
	return events
