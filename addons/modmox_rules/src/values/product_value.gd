class_name ProductValue
extends MmValue
## "[factor] times [value]": what an ability gives "for each" of something when it gives
## more than one, as Goblin Gaveleer's "+2/+0 for each Equipment attached to it" is 2 times
## the number of Equipment attached to it.

@export var factor: int = 1
@export var value: MmValue


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	return factor * value.evaluate(state, context)
