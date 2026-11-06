class_name RegenerateEffect
extends MmEffect
## "Regenerate [selection]" (CR 701.19a): gives each selected permanent a regeneration
## shield for the rest of the turn. A permanent that is not on the battlefield gets none.

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	var source: MmGameObject = state.object_or_last_known(context.source_object_id)
	var source_card: int = MmGameObject.NO_CARD if source == null else source.card_id
	for found: MmReference in selection.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent != null and permanent.zone() == state.battlefield:
			events.append(ReplacementEffectCreatedEvent.new(RegenerationReplacementEffect.new(), context.controller_id,
				context.source_object_id, source_card, [found], 1, CreateContinuousEffect.Duration.UNTIL_END_OF_TURN))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
