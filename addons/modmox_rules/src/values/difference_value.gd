class_name DifferenceValue
extends MmValue
## "[minuend] minus [subtrahend]". May be negative; an effect that cannot use a negative
## amount treats it as 0 (CR 107.1b).

@export var minuend: MmValue
@export var subtrahend: MmValue


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	return minuend.evaluate(state, context) - subtrahend.evaluate(state, context)
