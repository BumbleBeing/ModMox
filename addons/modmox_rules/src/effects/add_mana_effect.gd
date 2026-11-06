class_name AddManaEffect
extends MmEffect
## "Add [amount] mana of [type]" to the controller's mana pool (CR 106.3).

@export var mana_type: MmMana.Type = MmMana.Type.COLORLESS
@export var amount: MmValue


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(_state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if step > 0 or worked_out[0] <= 0:
		return []
	return [ManaAddedEvent.new(context.controller_id, mana_type, worked_out[0], context.source_object_id)]


func adds_mana() -> bool:
	return true
