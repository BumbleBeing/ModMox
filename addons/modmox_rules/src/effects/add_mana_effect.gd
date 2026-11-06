class_name AddManaEffect
extends MmEffect
## "Add [amount] mana of [type]" to the controller's mana pool (CR 106.3).

@export var mana_type: MmMana.Type = MmMana.Type.COLORLESS
@export var amount: MmValue


func resolve(state: MmGameState, context: MmEffectContext) -> void:
	var count: int = amount.evaluate(state, context)
	if count > 0:
		state.perform(ManaAddedEvent.new(context.controller_id, mana_type, count, context.source_object_id))


func adds_mana() -> bool:
	return true
