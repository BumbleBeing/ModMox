class_name CreateContinuousEffect
extends MmEffect
## "[continuous] until end of turn": creates a continuous effect that lasts for
## [member duration] (CR 611.2). What it affects, and its numbers, are fixed now
## (CR 611.2c, 608.2h), so a creature arriving later is not affected.

## How long it lasts. Saved card files store these as numbers: never change or reuse a
## value, only add new ones. Later: other durations, such as "until your next turn".
enum Duration { UNTIL_END_OF_TURN = 0 }

@export var continuous: MmContinuousEffect
@export var duration: Duration = Duration.UNTIL_END_OF_TURN


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	if step > 0:
		return []
	var ids: Array[int] = []
	for found: MmReference in continuous.affected.select(state, context):
		var game_object: MmGameObject = state.object(found.id) if found.is_object() else null
		if game_object != null and game_object.zone() == state.battlefield:
			ids.append(found.id)
	if ids.is_empty():
		return []
	var source: MmGameObject = state.object_or_last_known(context.source_object_id)
	var source_card: int = MmGameObject.NO_CARD if source == null else source.card_id
	return [ContinuousEffectCreatedEvent.new(continuous, context.controller_id, context.source_object_id, source_card,
		ids, continuous.numbers(state, context), duration)]


func selections() -> Array[MmSelection]:
	return [continuous.affected]
