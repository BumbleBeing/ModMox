class_name ValueAtLeastCondition
extends MmCondition
## "[value] is [amount] or more", such as "there are seven or more cards in your graveyard"
## (engine ADR 0080): true while the Value, worked out now, is at least [member amount].

@export var value: MmValue
@export var amount: int = 0


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	return value != null and value.evaluate(state, context) >= amount
