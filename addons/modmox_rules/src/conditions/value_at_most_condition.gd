class_name ValueAtMostCondition
extends MmCondition
## "[value] is [amount] or less", such as Blood Scrivener's "while you have no cards in hand"
## (the number of cards in your hand is 0 or less, engine ADR 0097): true while the Value,
## worked out now, is at most [member amount]. ValueAtLeastCondition is the other way round.

@export var value: MmValue
@export var amount: int = 0


func is_true(state: MmGameState, context: MmEffectContext) -> bool:
	return value != null and value.evaluate(state, context) <= amount
