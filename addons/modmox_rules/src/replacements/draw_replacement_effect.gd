class_name DrawReplacementEffect
extends MmReplacementEffect
## A draw replaced (CR 614.1a, 614.11, engine ADR 0097): the draw of the player who controls
## the effect, while [member condition] holds for them, is replaced by the events of
## [member instead], worked out as it is replaced, with the effect's source as their source.
## A DrawReplacementAbility generates it.

## Null for every draw.
@export var condition: MmCondition = null
@export var instead: Array[MmEffect] = []


func applies_to(state: MmGameState, event: MmEvent, active: ActiveReplacementEffect) -> bool:
	var drawing: DrawCardEvent = event as DrawCardEvent
	if drawing == null or drawing.player_id != active.controller_id:
		return false
	return condition == null or condition.is_true(state, _context(active))


func replace(state: MmGameState, _event: MmEvent, active: ActiveReplacementEffect) -> Array[MmEvent]:
	var context: MmEffectContext = _context(active)
	var events: Array[MmEvent] = []
	for effect: MmEffect in instead:
		var worked_out: Array[int] = effect.numbers(state, context)
		var step: int = 0
		var batch: Array[MmEvent] = effect.next_batch(state, context, step, worked_out)
		while not batch.is_empty():
			events.append_array(batch)
			step += 1
			batch = effect.next_batch(state, context, step, worked_out)
	return events


func describe() -> String:
	return "draw replacement"


func _context(active: ActiveReplacementEffect) -> MmEffectContext:
	return MmEffectContext.new(active.controller_id, active.source_object_id)
